# E-219 slice 2: the methods MakieCompat defines, by rule 3 (TraitWorld's `owned_method`), with the umbrella's
# `@joint_owners MakieCompat`; and the methods it defines on the umbrella's names.
# Slice 4 (E-226): the same for the statistics group, MakieCompatStats, the umbrella's second joint owner.
#     julia --project=experiments/x3/env experiments/x3/census.jl
using MakieCompat, MakieCompatStats, TraitMakie, TraitWorld
root(m::Module) = (p = parentmodule(m); p === m || p === Main ? m : root(p))
for M in (MakieCompat, MakieCompatStats)
    pir = Method[]; onumbrella = 0
    Base.visit(Core.methodtable) do m
        root(m.module) === M || return
        f = Base.unwrap_unionall(m.sig).parameters[1]
        fm = f isa DataType ? parentmodule(f) : nothing
        (fm !== nothing && root(fm) === TraitMakie) && (onumbrella += 1)
        TraitWorld.owned_method(m) || push!(pir, m)
    end
    println("CENSUS $M's methods on the umbrella's functions: ", onumbrella, "; pirates by the letter: ", length(pir))
    foreach(m -> println("CENSUS   ", m.name, "  ", m.sig), pir)
end
println("CENSUS the umbrella's joint owners: ", TraitWorld._joint_names(TraitMakie))
