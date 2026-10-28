# E-159, check 2: the methods of the split packages (ODECore, TraitRodas, the umbrella) that rule 3 calls
# pirates by the letter (TraitWorld's `owned_method`), with no `@joint_owners` declared.
#     julia --project=TraitDifferentialEquations experiments/w34-sciml/move3/census.jl [extra package ...]
using TraitDifferentialEquations, TraitWorld
extra = Symbol.(ARGS)
for p in extra; @eval using $p; end
mods = Dict{Module, String}()
for (id, m) in Base.loaded_modules
    id.name in ("ODECore", "TraitRodas", "TraitDifferentialEquations", String.(extra)...) && (mods[m] = id.name)
end
root(m::Module) = (p = parentmodule(m); p === m || p === Main ? m : root(p))
found = Dict{String, Vector{Method}}()
Base.visit(Core.methodtable) do m
    r = root(m.module)
    haskey(mods, r) || return
    TraitWorld.owned_method(m) && return
    push!(get!(found, mods[r], Method[]), m)
end
for p in sort!(collect(values(mods)))
    ms = get(found, p, Method[])
    println("CENSUS ", rpad(p, 28), length(ms), " pirates by the letter")
    for m in ms
        println("CENSUS   ", m.name, "  ", m.sig, "  ", basename(string(m.file)), ":", m.line)
    end
end
