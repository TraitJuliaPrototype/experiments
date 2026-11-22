# W-167 (open issue 254), the static twin of `lib_ended.jl`: which of the library's own instances are outside the
# deep class (compiler §3.2), and for each the culprits that keep it out: the instances reached through its edges,
# outside the class, with a fault of their own (an edge at a signature that is no fact, a callee named by its
# MethodInstance alone), as W-157's census finds them (`w157/census_lib.jl`: `faults`, `succ`, `kindof`). Any load
# can end such an instance by ending a culprit; an instance in the class is ended only by a stakeholder (G2).
#     julia --project=<env with TraitWorld> lib_static.jl [<Pkg> ...]
# With packages, they are loaded first (the instances the library has in that session). The flags are read by
# `flags.jl` (open issue 257).
# Each instance outside the class is put on the first path that reaches it through edges:
#   hook    from a hook the runtime or Base calls (HOOKS: at a definition, at a module's end, at an image's load, at
#           a package's load): the path a load and a definition run. Must be empty.
#   macro   from a macro of the library (a definition's expansion). Must be empty.
#   site    from the code a run-time site by intent reaches (a function passed to `_runtime_site`: a message, the
#           logger): off those paths by construction (allowed).
#   other   the rest (the library's tools a user calls). Must be empty.
# EXCEPTIONS: by function (a closure by the function it is written in), with the reason; they are not counted.
# `OUTSIDE <n>` counts the instances on the paths hook, macro and other that are not exceptions; `STATIC OK` when
# it is 0 (STRICT=1 exits 1 on a FAIL).
include(joinpath(@__DIR__, "flags.jl"))
using .W167Flags: g2, facts, natives, fromimage
include(joinpath(@__DIR__, "..", "w157", "census_lib.jl"))   # faults, succ, kindof (its own `bit` is not used)
const HOOKS = (:__init__, :_member_hook, :_definition_hook, :_expand_definition, :_module_end_hook, :_image_methods_hook,
               :_fully_typed_hook, :_deletion_hook, :_strict_at_load!, :_report_at_load!, :_report_endings!)
const EXCEPTIONS = Dict{String,String}(
    "_trait" => "the expansion of `@trait`: it builds syntax from the user's expressions (values of any type), where " *
                "the macro expands (a package's build, the prompt), never at a load or at a method's definition",
    "_equation_value_method" => "a part of `@trait`'s expansion (`_trait`), as above",
)
for p in ARGS
    @eval using $(Symbol(p))
end
@eval using TraitWorld
islibm(m::Module) = nameof(Base.moduleroot(m)) === :TraitWorld
islibci(ci::Core.CodeInstance) = (mi = Base.Compiler.get_ci_mi(ci); mi.def isa Method && islibm(mi.def.module))
short(@nospecialize(x), n = 160) = (s = x isa Core.CodeInstance ? string(Base.Compiler.get_ci_mi(x)) : string(x); first(replace(s, "MethodInstance for " => ""), n))
lib = Core.CodeInstance[]
Base.visit(Core.methodtable) do m
    islibm(m.module) || return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && append!(lib, natives(mi))
    end
end
println("# W-167 lib_static | julia ", Base.GIT_VERSION_INFO.commit_short, " | TraitWorld ", pathof(TraitWorld),
        isempty(ARGS) ? "" : " | loaded first: " * join(ARGS, ", "), " | load ", round(Sys.loadavg()[1]; digits = 1))
println("# ", W167Flags.CHECKED)
println("INSTANCES ", length(lib), " | facts ", count(facts, lib), " | deep ", count(g2, lib), " | from the image ",
        count(fromimage, lib), " | without its machine code ", count(!fromimage, lib))
# the culprits of each instance outside the class: the cone through instances without the bit
fcache = IdDict{Core.CodeInstance,Vector{Fault}}()
ownfaults(ci) = get!(() -> faults(ci), fcache, ci)
function cone(x::Core.CodeInstance)
    seen = IdSet{Core.CodeInstance}(); st = Core.CodeInstance[x]; out = Core.CodeInstance[]
    while !isempty(st)
        y = pop!(st); y in seen && continue; push!(seen, y)
        isempty(ownfaults(y)) || push!(out, y)
        for z in succ(y); g2(z) || z in seen || push!(st, z); end
    end
    out
end
# the library's own calls into code outside the class: its direct callees without the bit, not the library's
entries(ci) = unique([c for c in succ(ci) if !g2(c) && !islibci(c)])
outside = sort([ci for ci in lib if !g2(ci)]; by = short)
# a function's name as the exceptions name it: a closure by the function it is written in, a keyword body by its function
function key(ci)
    n = string((Base.Compiler.get_ci_mi(ci).def::Method).name)
    c = match(r"^#([^#]+)##", n); c === nothing || return string(c.captures[1], " (closure)")
    k = match(r"^#([^#]+)#\d+$", n); k === nothing || return string(k.captures[1])
    return n
end
fname_(ci) = (Base.Compiler.get_ci_mi(ci).def::Method).name
function reach(roots)
    seen = IdSet{Core.CodeInstance}(); st = Core.CodeInstance[roots...]
    while !isempty(st)
        y = pop!(st); y in seen && continue; push!(seen, y)
        for z in succ(y); z in seen || push!(st, z); end
    end
    seen
end
hookroots = [ci for ci in lib if fname_(ci) in HOOKS]
macroroots = [ci for ci in lib if startswith(string(fname_(ci)), "@")]
# the functions passed to `_runtime_site`: its specializations' first argument
sitetypes = IdSet{Any}()
for m in (isdefined(TraitWorld, :_runtime_site) ? methods(TraitWorld._runtime_site) : Method[]), mi in Base.specializations(m)
    mi isa Core.MethodInstance || continue
    b = Base.unwrap_unionall(mi.specTypes); length(b.parameters) >= 2 && push!(sitetypes, b.parameters[2])
end
siteroots = [ci for ci in lib if (b = Base.unwrap_unionall(Base.Compiler.get_ci_mi(ci).specTypes); !isempty(b.parameters) && b.parameters[1] in sitetypes)]
onhook, onmacro, onsite = reach(hookroots), reach(macroroots), reach(siteroots)
path(ci) = ci in onhook ? :hook : ci in onmacro ? :macro : ci in onsite ? :site : :other
excused = [ci for ci in outside if haskey(EXCEPTIONS, key(ci))]
rest = [ci for ci in outside if !haskey(EXCEPTIONS, key(ci)) && path(ci) !== :site]
println("HOOKS ", length(hookroots), " instances, deep ", count(g2, hookroots), " | MACROS ", length(macroroots), ", deep ",
        count(g2, macroroots), " | functions passed to _runtime_site ", length(sitetypes))
for ci in sort(hookroots; by = short); println("    ", g2(ci) ? "deep    " : "OUTSIDE ", short(ci, 150)); end
println("BY PATH (outside the class): hook ", count(ci -> path(ci) === :hook, outside), " | macro ", count(ci -> path(ci) === :macro, outside),
        " | site ", count(ci -> path(ci) === :site, outside), " | other ", count(ci -> path(ci) === :other, outside))
cones = IdDict(ci => cone(ci) for ci in outside)
fmt(f::Fault) = string(f.kind, " ", first(string(f.sig), 150))
const QUIET = get(ENV, "QUIET", "0") == "1"      # the summary and the instances counted only
QUIET || println("\n## outside the class: ", length(outside), " (", length(excused), " named exceptions), each with its culprits")
for ci in (QUIET ? Core.CodeInstance[] : outside)
    ex = get(EXCEPTIONS, key(ci), nothing)
    println(ex === nothing ? "OUT " : "EXCEPTION ", "[", path(ci), "] ", short(ci), fromimage(ci) ? "" : " [no machine code from the image]",
            ex === nothing ? "" : " | " * key(ci) * ": " * ex)
    for f in ownfaults(ci); println("    FAULT ", fmt(f)); end
    for c in entries(ci); println("    ENTRY ", short(c, 170)); end
    for c in cones[ci]
        println("    ", islibci(c) ? "own " : "", short(c, 140), " [", kindof(c, ownfaults(c)), "]: ",
                join(unique(fmt.(ownfaults(c)))[1:min(end, 3)], "; "))
    end
end
if !QUIET
# by culprit: how many of the library's instances hold it in their cone, and for how many it is the only one
byc = IdDict{Core.CodeInstance,Vector{Core.CodeInstance}}()
for ci in outside, c in cones[ci]; push!(get!(byc, c, Core.CodeInstance[]), ci); end
println("\n## the culprits: in the cones of, alone in, the culprit (outside the library unless `own`)")
for (c, v) in sort(collect(byc); by = p -> -length(p[2]))
    println(lpad(length(v), 4), lpad(count(ci -> length(cones[ci]) == 1, v), 4), "  ", islibci(c) ? "own " : "", short(c, 170))
end
bye = IdDict{Core.CodeInstance,Vector{Core.CodeInstance}}()
for ci in outside, c in entries(ci); push!(get!(bye, c, Core.CodeInstance[]), ci); end
println("\n## the library's calls into code outside the class (ENTRY): callee, the library's instances that call it")
for (c, v) in sort(collect(bye); by = p -> -length(p[2]))
    println(lpad(length(v), 4), "  ", short(c, 170), "  <- ", join(unique(short.(v, 60))[1:min(end, 4)], ", "), length(v) > 4 ? ", ..." : "")
end
nf = [ci for ci in outside if !isempty(ownfaults(ci))]
println("\n## the library's instances with a fault of their own (FAULT): ", length(nf))
for ci in nf; println("    ", short(ci, 120), ": ", join(unique(fmt.(ownfaults(ci)))[1:min(end, 3)], "; ")); end
println("\n## no machine code from the image (inlined into callers, a constant, or compiled in this session): ", count(!fromimage, lib))
for ci in sort([ci for ci in lib if !fromimage(ci)]; by = short); println("    ", short(ci, 150), g2(ci) ? "" : "  (outside)"); end
end # QUIET
println("\nOUTSIDE ", length(rest), " (hook ", count(ci -> path(ci) === :hook, rest), ", macro ", count(ci -> path(ci) === :macro, rest),
        ", other ", count(ci -> path(ci) === :other, rest), ") | behind a run-time site by intent ", count(ci -> path(ci) === :site, outside),
        " | named exceptions ", length(excused), " | of ", length(lib))
foreach(ci -> println("    [", path(ci), "] ", key(ci), ": ", short(ci, 140)), rest)
ok = isempty(rest)
println(ok ? "STATIC OK" : "STATIC FAIL")
get(ENV, "STRICT", "0") == "1" && !ok && exit(1)
nothing
