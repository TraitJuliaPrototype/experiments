# E-273: the share of the CodeInstances a workload makes that satisfy G2 (compiler §3.2), by policy:
# those present after the workload and not before it.
# Usage: julia --project=TraitWorld-unified g2share.jl <workload.jl>
const G2, FACTS = 0x10, 0x20
function native_cis()
    s = IdSet{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                ci.owner === nothing && push!(s, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return s
end
before = native_cis()
include(abspath(ARGS[1]))
after = native_cis()
counts = Dict{Symbol,Int}(:plain => 0, :plain_g2 => 0, :facts => 0, :facts_g2 => 0)
for ci in after
    ci in before && continue
    k = (ci.flags & FACTS) != 0 ? :facts : :plain
    counts[k] += 1
    (ci.flags & G2) != 0 && (counts[Symbol(k, :_g2)] += 1)
end
println("before the workload: ", length(before), " CodeInstances")
for k in (:plain, :facts)
    n = counts[k]; g = counts[Symbol(k, :_g2)]
    println("$k: $n made by the workload, $g satisfy G2 (", n == 0 ? "—" : string(round(100g / n; digits = 1)), " %)")
end
