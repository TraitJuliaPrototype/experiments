# E-181: the parameters' type as a key. A fresh session solves Lorenz (Tsit5) and Robertson (Rodas5) with the
# parameters of kind PKIND (vector, tuple, namedtuple, struct: a struct defined here, in Main), and reports the
# first solve's time and compile time, then the steady state (the minimum of 30 more).
#     PKIND=tuple julia --project=env_d params/params.jl
t0 = time()
using TraitDifferentialEquations
const KIND = get(ENV, "PKIND", "vector")
struct LorenzP; σ::Float64; ρ::Float64; β::Float64; end
struct RobP; k1::Float64; k2::Float64; k3::Float64; end
Base.getindex(p::LorenzP, i::Int) = i == 1 ? p.σ : i == 2 ? p.ρ : p.β
Base.getindex(p::RobP, i::Int) = i == 1 ? p.k1 : i == 2 ? p.k2 : p.k3
mk(v, S) = KIND == "vector" ? v : KIND == "tuple" ? Tuple(v) : KIND == "namedtuple" ? (a = v[1], b = v[2], c = v[3]) : S(v...)
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
rober!(du, u, p, t) = (du[1] = -p[1] * u[1] + p[3] * u[2] * u[3]; du[2] = p[1] * u[1] - p[2] * u[2]^2 - p[3] * u[2] * u[3]; du[3] = p[2] * u[2]^2; nothing)
Base.cumulative_compile_timing(true)
ct() = Base.cumulative_compile_time_ns()[1] / 1e9
tl = time() - t0
function run()
    p1 = mk([10.0, 28.0, 8 / 3], LorenzP); p2 = mk([0.04, 3e7, 1e4], RobP)
    s1 = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 10.0), p1), Tsit5(); saveat = 0.0:0.1:10.0)
    s2 = solve(ODEProblem(rober!, [1.0, 0.0, 0.0], (0.0, 1e5), p2), Rodas5(); abstol = 1e-8, reltol = 1e-6)
    return s1.u[end][1], s2.u[end][2]
end
c = ct(); t = @elapsed r1 = run(); c1 = ct() - c
c = ct(); t2 = minimum(@elapsed(run()) for _ in 1:30); c2 = ct() - c
println("R kind=", KIND, " load=", round(tl; digits = 3), " first=", round(t; digits = 3), " (c ", round(c1; digits = 3), ") again=",
        round(t2 * 1000; digits = 2), " ms (min of 30; c ", round(c2; digits = 3), ") result=", r1)
