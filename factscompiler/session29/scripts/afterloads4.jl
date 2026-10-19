using Profile
LOADS = get(ENV, "LOADS", "0") == "1"
LOADS && @eval Main using CSV, DataFrames, CairoMakie
@eval using TraitDifferentialEquations, TraitWorld
const U0 = [1.0, 0.0, 0.0]
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
solve(ODEProblem(lorenz!, U0, (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
@eval struct Lorenz; s::Float64; r::Float64; b::Float64; end
@eval TraitDifferentialEquations.rhs!(m::Lorenz, du::Vector{Float64}, u::Vector{Float64}, t::Float64) =
    (du[1] = m.s * (u[2] - u[1]); du[2] = u[1] * (m.r - u[3]) - u[2]; du[3] = u[1] * u[2] - m.b * u[3]; nothing)
@eval @implement ODEModel{Float64} Lorenz
Profile.init(n = 10^7, delay = 0.0005)
@time @profile solve(Lorenz(10.0, 28.0, 8 / 3), U0, (0.0, 1.0), Tsit5())
Profile.print(IOContext(stdout, :displaysize => (2000, 220)); format = :flat, sortedby = :count, C = false, mincount = 25)
