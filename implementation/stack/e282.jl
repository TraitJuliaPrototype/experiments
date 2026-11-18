# E-282: plain code's cost of BaseTraits' methods at sets. Usage:
#   julia --project=<TraitWorld worktree> e282.jl <julia tree> <test name>
using TraitWorld, Test
m = Module(:E282); Core.eval(m, :(using Test, Random; include(x) = Base.include(@__MODULE__, x)))
t = @elapsed Base.include(m, joinpath(ARGS[1], "test", ARGS[2] * ".jl"))
println(ARGS[2], ": ", round(t, digits = 1), " s; BaseTraits loaded: ", isdefined(TraitWorld, :BaseTraits))
