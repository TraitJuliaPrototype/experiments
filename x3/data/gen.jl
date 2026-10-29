# E-228: the workload's solutions (E-168, matched shapes: workload.jl's solve_two and Van der Pol), saved once so that a
# session can time only the plotting. Run in setting S (stock 1.13.2, experiments/ttfx/env_up, depot-S):
#     JULIA_DEPOT_PATH=experiments/ttfx/depot-S: julia +1.13.2 --project=experiments/ttfx/env_up experiments/x3/data/gen.jl
# Format of solutions.bin, per solution (lorenz, robertson, vanderpol): n, m (Int64), t (n Float64), u (n × m Float64, by time).
using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
function lorenz!(du, u, p, t)
    s, r, b = p
    du[1] = s * (u[2] - u[1]); du[2] = u[1] * (r - u[3]) - u[2]; du[3] = u[1] * u[2] - b * u[3]
    nothing
end
function robertson!(du, u, p, t)
    du[1] = -0.04u[1] + 1e4 * u[2] * u[3]
    du[2] = 0.04u[1] - 1e4 * u[2] * u[3] - 3e7 * u[2]^2
    du[3] = 3e7 * u[2]^2
    nothing
end
function vanderpol!(du, u, p, t)
    du[1] = u[2]; du[2] = p[1] * ((1 - u[1]^2) * u[2]) - u[1]
    nothing
end
const RT, AT = 1e-6, 1e-8
TL = collect(range(0.0, 20.0; length = 2001)); TR = exp10.(range(-5, 5; length = 201)); TV = collect(range(0.0, 3000.0; length = 3001))
a = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), Tsit5(); saveat = TL, reltol = RT, abstol = AT)
b = solve(ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), Rodas5P(); saveat = TR, reltol = RT, abstol = AT)
c = solve(ODEProblem(vanderpol!, [2.0, 0.0], (0.0, 3000.0), [1000.0]), Rodas5P(); saveat = TV, reltol = RT, abstol = AT)
open(joinpath(@__DIR__, "solutions.bin"), "w") do io
    for s in (a, b, c)
        n, m = length(s.t), length(s.u[1])
        write(io, Int64(n), Int64(m), Vector{Float64}(s.t))
        for u in s.u; write(io, Vector{Float64}(u)); end
    end
end
println("written: ", [length(s.t) for s in (a, b, c)])
