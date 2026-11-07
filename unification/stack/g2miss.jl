# E-278: the facts CodeInstances a workload makes that do not satisfy G2 (compiler §3.2), each with
# the edges that break it: a dispatch edge at a signature that is not a fact.
# Usage: JULIA_COMPILE_BY_FACTS=1 julia --project=TraitWorld-unified g2miss.jl <workload.jl>
const G2, FACTS = 0x10, 0x20
const C = Base.Compiler
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
for ci in native_cis()
    ci in before && continue
    (ci.flags & FACTS) != 0 && (ci.flags & G2) == 0 || continue
    bad = Any[]
    for (invokesig, item) in C.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            C.is_fact_sig(invokesig) || push!(bad, (:abstract, invokesig))
        elseif item isa Core.MethodInstance && invokesig === nothing
            C.is_fact_sig(item.specTypes) || push!(bad, (:dispatch, item.specTypes))
        end
    end
    println(ci.def.specTypes, "\n    ", bad)
end
