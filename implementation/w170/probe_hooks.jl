# W-170 (E-538), candidate 6: who calls, at the ODE port's load, the instances the system image holds inferred only
# (E-536: getindex(::SimpleVector, ::UnitRange{Int}), iterate(::Enumerate{Vector{Symbol}}), indexed_iterate at a
# tuple with TraitWorld.How) and setindex!(::IdDict{Any,Vector{Any}}, ::Any, ::Any): their callers by backedges,
# after `using TraitWorld, TraitDifferentialEquations`.
using TraitWorld, TraitDifferentialEquations
const TW = TraitWorld
sigs = Any[Tuple{typeof(getindex), Core.SimpleVector, UnitRange{Int}},
           Tuple{typeof(iterate), Base.Iterators.Enumerate{Vector{Symbol}}},
           Tuple{typeof(iterate), Base.Iterators.Enumerate{Vector{Symbol}}, Tuple{Int,Int}},
           Tuple{typeof(Base.indexed_iterate), Tuple{DataType, UnionAll, TW.How}, Int},
           Tuple{typeof(Base.indexed_iterate), Tuple{UnionAll, UnionAll, TW.How}, Int},
           Tuple{typeof(Base.indexed_iterate), Tuple{UnionAll, TW.How}, Int, Int},
           Tuple{typeof(setindex!), IdDict{Any,Vector{Any}}, Any, Any}]
for sig in sigs
    ms = Base._methods_by_ftype(sig, -1, Base.get_world_counter())
    m = ms[1].method
    for mi in Base.specializations(m)
        mi.specTypes == sig || continue
        bes = isdefined(mi, :backedges) ? mi.backedges : Any[]
        callers = unique([string(b isa Core.CodeInstance ? b.def.specTypes : b isa Core.MethodInstance ? b.specTypes : typeof(b)) for b in bes])
        println("R ", sig, "\n    callers: ", isempty(callers) ? "none" : join(first(callers, 8), "\n             "))
    end
end
