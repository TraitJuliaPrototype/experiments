# E4: with the skip predicate off (JULIA_TW_FILTER=0), which chains invalidate trait-world code and
# TraitWorld's machinery when CSV, DataFrames and CairoMakie load after TraitDifferentialEquations?
using TraitDifferentialEquations
const TDE = TraitDifferentialEquations
const TW = TDE.TraitWorld
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
using CSV, DataFrames, CairoMakie
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
modof(x) = x isa Core.MethodInstance && x.def isa Method ? x.def.module : nothing
cls(m) = m === nothing ? :other : (m === TDE.ODECore ? :ODECore : m === TDE ? :TDE : Base.moduleroot(m) === TW ? :TraitWorld : Base.moduleroot(m) === Base ? :Base : :other)
reasons = ("jl_method_table_insert", "jl_method_table_disable", "insert_backedges_callee", "verify_methods", "invalidate_mt_cache", "insert_backedges")
chains = Any[]; cur = Any[]
for (k, x) in enumerate(log)
    if x isa String && x in reasons
        push!(chains, (copy(cur), log[k-1], x)); empty!(cur)
    elseif !(x isa Int) && !(x isa String)
        push!(cur, x)
    end
end
println(length(chains), " chains")
roots = Dict{Any,Int}()
for (items, trig, why) in chains
    mis = [y for y in items if y isa Core.MethodInstance]
    isempty(mis) && continue
    hit = unique(cls.(modof.(mis)))
    (:ODECore in hit || :TDE in hit || :TraitWorld in hit) || continue
    root = mis[1]
    tm = trig isa Method ? trig : nothing
    key = (string(cls(modof(root)), " ", first(string(root.specTypes), 110)), isconcretetype(root.specTypes),
           tm === nothing ? first(string(trig), 60) : string(tm.module, ".", tm.name), why, Tuple(sort(filter(h -> h in (:ODECore, :TDE, :TraitWorld), hit))))
    roots[key] = get(roots, key, 0) + 1
end
for (k, v) in sort(collect(roots); by = x -> -x[2])[1:min(end, 40)]
    root, conc, trig, why, hit = k
    println(lpad(v, 3), "  root: ", root, "  concrete=", conc, "\n      trigger: ", trig, " [", why, "]  reaches: ", hit)
end
