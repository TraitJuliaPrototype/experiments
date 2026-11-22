# W-167 (open issue 254): which of the library's own instances a load ends, the plain callee of the library each
# rests on, and the chain down to the definition that ended it. Built on W-159's probe (`w159/probes/lib_ended.jl`),
# with the log's depths read, image validation read too, and a count that does not rest on the log.
#     julia --project=<env> lib_ended.jl <Pkg> [<Pkg> ...]           the library first, then the packages
#     LATE=1 julia --project=<env> lib_ended.jl <Pkg> [<Pkg> ...]    the packages first, then the library (E-515's
#                                                                     late load): its image code rejected at load
# Output: `ENDED <n>` (the library's instances valid before the load and not after it, counted from the caches;
# with LATE=1 the library's image instances rejected or ended at its load), then per definition that ended any:
# its tree of ended instances pruned to the branches that reach the library (indent = depth, `LIB` marks the
# library's), then `LIB <instance> | via <plain callee> | hook <the library's outermost caller ended with it>`.
include(joinpath(@__DIR__, "flags.jl"))
using .W167Flags: g2, facts, natives, fromimage
const late = get(ENV, "LATE", "0") == "1"
const pkgs = Symbol.(ARGS)
islib(m::Module) = (r = Base.moduleroot(m); nameof(r) === :TraitWorld)
miof(x::Core.MethodInstance) = x
miof(x::Core.CodeInstance) = Base.Compiler.get_ci_mi(x)
miof(@nospecialize x) = nothing
function islib(@nospecialize x)
    mi = miof(x); mi === nothing && return false
    mi.def isa Method && islib(mi.def.module)
end
short(@nospecialize(x), n = 170) = (s = x isa Core.CodeInstance ? "CI " * string(miof(x)) : string(x); s = replace(s, "MethodInstance for " => ""); first(s, n))
function libcis()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        islib(m.module) || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && append!(out, natives(mi))
        end
    end
    out
end
whatis(m::Method) = string(m.module, ".", m.name, " at ", m.file, ":", m.line, " ", m.sig)
whatis(@nospecialize x) = short(x, 300)

println("# W-167 lib_ended | julia ", Base.GIT_VERSION_INFO.commit_short, " | project ", Base.active_project(),
        " | load ", join(round.(Sys.loadavg(); digits = 1), " "), late ? " | LATE: the packages first" : "")
println("# ", W167Flags.CHECKED)
before = Core.CodeInstance[]
if !late
    @eval using TraitWorld
    append!(before, libcis())
    println("# TraitWorld ", pathof(TraitWorld), " | its instances before the load ", length(before), ", facts ",
            count(facts, before), ", deep ", count(g2, before), ", from its image ", count(fromimage, before))
end
clog = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
Base.Compiler.ReinferUtils.debug_method_invalidation(true)
t = @elapsed for p in pkgs
    @eval using $p
end
late && (@eval using TraitWorld)
jlog = Base.Compiler.ReinferUtils._jl_debug_method_invalidation[]
Base.Compiler.ReinferUtils.debug_method_invalidation(false)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
println("# loaded ", join(pkgs, ", "), late ? " then TraitWorld" : "", " in ", round(1000t; digits = 1), " ms (logging on) | ",
        "log entries: runtime ", length(clog), ", image validation ", length(jlog))
late && println("# TraitWorld ", pathof(TraitWorld))

# the runtime's log: (instance, depth) pairs, closed by (instance or method, tag); a bare type is a method
# table's backedge. A run is closed by a tag whose object is a Method (or not an instance): its cause.
struct Ent; x::Any; d::Int; end
segs = Tuple{Any,String,Vector{Ent}}[]
let cur = Ent[], i = 1
    while i <= length(clog)
        x = clog[i]; nx = i < length(clog) ? clog[i + 1] : nothing
        if nx isa Int32
            push!(cur, Ent(x, Int(nx))); i += 2
        elseif nx isa String
            if !(x isa Core.MethodInstance)
                push!(segs, (x, nx, cur)); cur = Ent[]
            end
            i += 2
        else
            i += 1
        end
    end
    isempty(cur) || push!(segs, (nothing, "unclosed", cur))
end
ended = IdDict{Any,Vector{String}}()   # library MethodInstance => lines
hooks = IdDict{Any,Any}()
function report(cause, tag, es::Vector{Ent})
    keep = falses(length(es))
    # keep each library entry and its chain (the nearest preceding entry at each smaller depth)
    for k in eachindex(es)
        islib(es[k].x) || continue
        keep[k] = true; d = es[k].d
        for j in k-1:-1:1
            es[j].d < d && (keep[j] = true; d = es[j].d)
        end
    end
    any(keep) || return
    println("\nCAUSE ", tag, " ", whatis(cause))
    d0 = minimum(e.d for e in es)
    for k in eachindex(es)
        keep[k] || continue
        println("  ", "  "^(es[k].d - d0), islib(es[k].x) ? "LIB " : "", short(es[k].x))
    end
    for k in eachindex(es)
        islib(es[k].x) || continue
        # via: the nearest non-library entry below it in its chain; hook: the outermost library caller in its subtree
        via = nothing; d = es[k].d
        for j in k-1:-1:1
            if es[j].d < d
                d = es[j].d
                islib(es[j].x) || (via = es[j].x; break)
            end
        end
        islib(es[k].x) && via === nothing && (via = "(itself the callee whose dispatch changed)")
        hook = es[k].x; dk = es[k].d
        for j in k+1:length(es)
            es[j].d <= dk && break
            islib(es[j].x) && (hook = es[j].x)
        end
        mi = miof(es[k].x)
        push!(get!(ended, mi, String[]), string("via ", short(via, 140), " | hook ", short(hook, 90), " | cause ", cause isa Method ? string(cause.module, ".", cause.name, " ", cause.sig) : short(cause, 120)))
    end
end
for (cause, tag, es) in segs; report(cause, tag, es); end

# the Compiler's log of image validation: (child, "verify_methods", cause), (edge, "insert_backedges_callee",
# ci, matches), (def, "method_globalref", ci, nothing)
vrows = String[]
let i = 1
    while i <= length(jlog)
        x = jlog[i]
        if i < length(jlog) && jlog[i + 1] isa String
            tag = jlog[i + 1]
            if tag == "verify_methods"
                c = jlog[i + 2]
                islib(x) && push!(vrows, string("VERIFY ", short(x, 140), " | cause ", short(c, 160)))
                i += 3
            elseif tag in ("insert_backedges_callee", "method_globalref")
                ci = jlog[i + 2]
                islib(ci) && push!(vrows, string(tag == "method_globalref" ? "GLOBALREF " : "CALLEE ", short(ci, 140), " | edge ", short(x, 160)))
                i += 4
            else
                i += 2
            end
        else
            i += 1
        end
    end
end
if !isempty(vrows)
    println("\n## the library's image code rejected at load (image validation): ", length(vrows))
    foreach(println, vrows)
end

nend = if late
    length(unique(vrows))
else
    count(ci -> ci.max_world != typemax(UInt), before)
end
println("\n## the library's instances ended: ", length(ended), " in the runtime's log (unique instances)")
for (mi, ls) in sort(collect(ended); by = p -> string(p[1]))
    println("LIB ", short(mi, 120))
    for l in unique(ls); println("    ", l); end
end
println("ENDED ", late ? "(image code rejected at load, entries) " : "(valid before, not after) ", nend,
        late ? "" : string(" | of them facts ", count(ci -> ci.max_world != typemax(UInt) && facts(ci), before),
                           ", deep before ", count(ci -> ci.max_world != typemax(UInt) && g2(ci), before)))
