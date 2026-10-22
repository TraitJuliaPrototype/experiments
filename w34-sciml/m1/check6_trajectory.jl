# E-157 check 6 (move 5): a helper bounded by `Trajectory{U, T}` (in a trait module of its own, as a
# plotting package would hold it) is compiled once per key; the solution's type is the same for
# two models. Method: the CodeInstances of every method of the helper's module (common.jl,
# `snapshot`), after each call, with the specializations listed at the end.
include(joinpath(@__DIR__, "common.jl"))
using ChainModels, LorenzModels
header("check 6", "a Trajectory helper compiled once per key; one solution type for two models")

@trait_module module Plotting
using TraitWorld
using TraitDifferentialEquations
using TraitDifferentialEquations.ODECore: times, state, at
"The states at `m` evenly spaced times over the saved span, as a plot draws a trajectory."
function sample(s::Trajectory{U,T}, m::Int) where {U,T}
    ts = times(s)
    t0, t1 = ts[1], ts[end]
    out = U[]
    for k in 0:m-1
        push!(out, at(s, t0 + (t1 - t0) * k / (m - 1)))
    end
    return out
end
"The last saved state."
final(s::Trajectory{U,T}) where {U,T} = state(s, length(times(s)))
end

lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
const U40 = collect(range(0.0, 1.0; length = 40))
sols = [
    ("a function (lorenz!)", solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())),
    ("ChainModel{PathGraph}", solve(ODEProblem(ChainModel(PathGraph(40)), U40, (0.0, 1.0), [1.0, 0.1]), Tsit5())),
    ("ChainModel{RingGraph}, NamedTuple p", solve(ODEProblem(ChainModel(RingGraph(40)), U40, (0.0, 1.0), (k = 1.0, d = 0.1)), Tsit5())),
    ("compiled_for(ChainModel{RingGraph})", solve(ODEProblem(compiled_for(ChainModel(RingGraph(40))), U40, (0.0, 1.0), [1.0, 0.1]), Tsit5())),
    ("a problem type (LorenzProblem), Rodas5", solve(LorenzProblem([1.0, 0.0, 0.0], (0.0, 1.0), 10.0, 28.0, 8 / 3), Rodas5())),
    ("a Float32 state (a new key)", solve(ODEProblem(lorenz!, Float32[1, 0, 0], (0.0, 1.0), Float32[10, 28, 8 / 3]), Tsit5())),
]
println("solution types: ", join(unique(string.(typeof.(last.(sols)))), ", "))
const HELPER = modpred(Plotting)
# typed callers: each knows its solution's type, so the solution is `Compiled` at the bound
use(s) = (Plotting.sample(s, 5), Plotting.final(s))
global prev = snapshot(HELPER)
global total = 0
for (label, s) in sols
    use(s)
    now_ = snapshot(HELPER)
    n = length(newin(prev, now_))
    global total += n
    println(rpad("typed caller, " * label, 64), lpad(n, 3), " new CodeInstance(s) in Plotting")
    global prev = now_
end
for (label, s) in sols[1:2]
    Base.invokelatest(Plotting.sample, s, 5)          # a dynamic call: the solution enters `Dynamic`
    now_ = snapshot(HELPER)
    n = length(newin(prev, now_))
    println(rpad("dynamic call, " * label, 64), lpad(n, 3), " new CodeInstance(s) in Plotting")
    global prev = now_
end
println("\nThe specializations of Plotting's methods at the end:")
for ((mi, o), n) in sort!(collect(prev); by = x -> string(x[1][1].specTypes))
    s = string(mi.specTypes)
    println("  [", ownername(o), "] ", mi.def.name, "  ", length(s) > 300 ? s[1:300] * "…" : s)
end
footer()
