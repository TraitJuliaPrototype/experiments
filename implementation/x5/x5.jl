# E-266 (X5 of the work plan §8; the user, 2026-11-06: "Adopt, keys as optional is approved. Run the X now"):
# how much of the facts copies of Base that images keep today would an image keep as plain code that
# satisfies G2 (mitigation M1)?
#
# Right after `using <package>`: every CodeInstance of the facts owner, valid now, whose method is Core's or
# Base's (the standard libraries and the packages counted apart). Under the draft (one CodeInstance per
# MethodInstance and policy) facts code calls the plain CodeInstance of such a method instead. For each
# MethodInstance:
#   - present: a valid plain CodeInstance exists already (the system image, a loaded image): nothing to keep;
#   - missing: none. Each missing one is compiled plainly here (`Compiler.typeinf_ext_toplevel` with the plain
#     owner, then `jl_compile_codeinst`), callees first by the facts copies' edges, and timed. Then its plain
#     record is read: G2 as plain code (draft compiler §3.2) where every dispatch edge is at a fact signature
#     (`Compiler.is_fact_sig`), counted two ways:
#       own:  its own dispatch edges only (an upper bound: an inlined callee's record not read);
#       deep: and every callee's plain record, transitively (a lower bound: every callee treated as inlined).
#     Facts code among the callees satisfies G2 by construction.
# M1 keeps the G2 ones in the image; the rest would be compiled at their first use in a session.
#
#     julia --startup-file=no x5.jl <label> <package>
# Writes <label>.tsv (one row per missing MethodInstance) and <label>.txt to $X5_OUT (default ./out).
const CC = Base.Compiler
label, pkg = ARGS[1], ARGS[2]
outdir = get(ENV, "X5_OUT", joinpath(@__DIR__, "out"))
mkpath(outdir)

t_load = @elapsed Core.eval(Main, Expr(:using, Expr(:., Symbol(pkg))))
const W = Base.get_world_counter()
const TOP = typemax(UInt)

function origin(m::Method)
    r = Base.moduleroot(parentmodule(m))
    r === Core && return "Core"
    r === Base && return "Base"
    isdir(joinpath(Sys.STDLIB, string(nameof(r)))) && return "stdlib"
    nameof(r) === :Compiler && return "Compiler"
    return "package"
end

valid_ci(mi::Core.MethodInstance, @nospecialize(owner)) = begin
    isdefined(mi, :cache) || return nothing
    ci = mi.cache
    while true
        ci.owner === owner && ci.max_world == TOP && ci.min_world <= W && return ci
        isdefined(ci, :next) || return nothing
        ci = ci.next
    end
end

# ---- the census ----
facts_mis = Dict{String,Vector{Core.MethodInstance}}()
nfacts = Dict{String,Int}()
Base.visit(Core.methodtable) do m
    o = origin(m)
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        valid_ci(mi, :facts) === nothing && continue
        nfacts[o] = get(nfacts, o, 0) + 1
        push!(get!(facts_mis, o, Core.MethodInstance[]), mi)
    end
end
julia_mis = vcat(get(facts_mis, "Core", Core.MethodInstance[]), get(facts_mis, "Base", Core.MethodInstance[]))
present = [mi for mi in julia_mis if valid_ci(mi, nothing) !== nothing]
missing_ = [mi for mi in julia_mis if valid_ci(mi, nothing) === nothing]
std_missing = count(mi -> valid_ci(mi, nothing) === nothing, get(facts_mis, "stdlib", Core.MethodInstance[]))

# callees first, by the facts copies' edges
edge_mis(ci) = begin
    out = Core.MethodInstance[]
    for e in ci.edges
        e isa Core.CodeInstance && (e = e.def)
        e isa Core.MethodInstance && push!(out, e)
    end
    out
end
inset = Base.IdSet{Core.MethodInstance}(missing_)
order = Core.MethodInstance[]; mark = Base.IdSet{Core.MethodInstance}()
function visit_mi(mi)
    mi in mark && return
    push!(mark, mi)
    fc = valid_ci(mi, :facts)
    if fc !== nothing
        for k in edge_mis(fc)
            k in inset && visit_mi(k)
        end
    end
    push!(order, mi)
end
foreach(visit_mi, missing_)

# ---- compile the missing ones plainly, timed ----
Base.cumulative_compile_timing(true)
secs = IdDict{Core.MethodInstance,Float64}(); fails = 0
c0 = Base.cumulative_compile_time_ns()
t_all = @elapsed for mi in order
    t0 = time_ns()
    try
        ci = CC.typeinf_ext_toplevel(mi, Base.get_world_counter(), CC.SOURCE_MODE_ABI, CC.TRIM_NO, nothing)
        ci isa Core.CodeInstance && ccall(:jl_compile_codeinst, Cint, (Any,), ci)
    catch
        global fails += 1
    end
    secs[mi] = (time_ns() - t0) / 1e9
end
c1 = Base.cumulative_compile_time_ns()

# ---- G2 as plain code ----
"Its own dispatch edges all at fact signatures (`invoke` and binding edges allowed); and the callees named."
function own_g2(ci::Core.CodeInstance)
    e = ci.edges; i = 1; ok = true; callees = Any[]
    while i <= length(e)
        x = e[i]
        if x isa Int
            n = abs(x)
            (x > 0 && CC.is_fact_sig(e[i+1])) || (ok = false)
            for j in 1:n; push!(callees, e[i+1+j]); end
            i += 2 + n
        elseif x isa Type
            nxt = i < length(e) ? e[i+1] : nothing
            nxt === Core.methodtable && (ok = false)       # a lookup that does not cover: not G2
            nxt isa Union{Core.CodeInstance,Core.MethodInstance} && push!(callees, nxt)
            i += 2
        elseif x isa Core.CodeInstance || x isa Core.MethodInstance
            mi = x isa Core.CodeInstance ? x.def : x
            mi isa Core.MethodInstance && !CC.is_fact_sig(mi.specTypes) && (ok = false)
            push!(callees, x)
            i += 1
        else
            i += 1
        end
    end
    return ok, callees
end
const DEEP = IdDict{Any,Bool}()
function deep_g2(ci::Core.CodeInstance)
    ci.owner === :facts && return true
    haskey(DEEP, ci) && return DEEP[ci]
    DEEP[ci] = true                                     # a cycle: assumed, settled by the other members
    ok, callees = own_g2(ci)
    if ok
        for k in callees
            kc = k isa Core.CodeInstance ? k : (k isa Core.MethodInstance ? valid_ci(k, nothing) : nothing)
            kc isa Core.CodeInstance || continue        # a Method target, or no plain code: not read
            deep_g2(kc) || (ok = false; break)
        end
    end
    DEEP[ci] = ok
    return ok
end

rows = Any[]
agg = Dict{Symbol,Tuple{Int,Float64}}()
add!(k, s) = (agg[k] = (get(agg, k, (0, 0.0))[1] + 1, get(agg, k, (0, 0.0))[2] + s))
for mi in order
    ci = valid_ci(mi, nothing)
    s = get(secs, mi, 0.0)
    if ci === nothing
        push!(rows, (mi, s, "none", "none")); add!(:nocode, s); continue
    end
    o, _ = own_g2(ci); d = deep_g2(ci)
    push!(rows, (mi, s, o ? "G2" : "not", d ? "G2" : "not"))
    add!(o ? :own_g2 : :own_not, s); add!(d ? :deep_g2 : :deep_not, s)
end
open(joinpath(outdir, "$(label).tsv"), "w") do io
    println(io, "seconds\town\tdeep\tmodule\tspecTypes")
    for (mi, s, o, d) in sort(rows; by = r -> -r[2])
        println(io, join((round(s; digits = 5), o, d, parentmodule(mi.def), mi.specTypes), '\t'))
    end
end
f(k) = (n = get(agg, k, (0, 0.0)); "$(n[1]) ($(round(n[2]; digits = 3)) s)")
summary = """
E-266 $(label): using $(pkg) on $(Base.GIT_VERSION_INFO.commit_short), load $(round(t_load; digits = 2)) s, machine load $(read("/proc/loadavg", String)[1:4])
  facts CodeInstances valid after the load, by method origin: $(join(["$k $(v)" for (k, v) in sort!(collect(nfacts))], ", "))
  Core's and Base's: $(length(julia_mis)); a plain CodeInstance present $(length(present)); missing $(length(missing_)) (standard libraries' missing: $(std_missing), not compiled)
  the missing compiled plainly: $(round(t_all; digits = 3)) s wall, compile counter $(round((c1[1] - c0[1]) / 1e9; digits = 3)) s, failures $(fails)
  G2 as plain code, own edges:  $(f(:own_g2)) G2, $(f(:own_not)) not
  G2 as plain code, deep:       $(f(:deep_g2)) G2, $(f(:deep_not)) not
  no plain code after compiling: $(f(:nocode))
"""
print(summary)
write(joinpath(outdir, "$(label).txt"), summary)
