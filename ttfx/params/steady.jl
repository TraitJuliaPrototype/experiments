# E-181 (2): the steady state per solver, longer solves. Lorenz with Tsit5 over (0, 100), Robertson with Rodas5 over
# (0, 1e5), and Lorenz with Tsit5 and a callback that reads `integ.p`; the minimum of 50 solves each, after a warm-up.
#     PKIND=tuple julia --project=env_d params/steady.jl
using TraitDifferentialEquations
const KIND = get(ENV, "PKIND", "vector")
mk(v) = KIND == "vector" ? v : Tuple(v)
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
rober!(du, u, p, t) = (du[1] = -p[1] * u[1] + p[3] * u[2] * u[3]; du[2] = p[1] * u[1] - p[2] * u[2]^2 - p[3] * u[2] * u[3]; du[3] = p[2] * u[2]^2; nothing)
const p1 = mk([10.0, 28.0, 8 / 3]); const p2 = mk([0.04, 3e7, 1e4])
const cb = DiscreteCallback((u, t, i) -> u[1] > 1e6 * i.p[1], i -> nothing)
a() = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 100.0), p1), Tsit5())
b() = solve(ODEProblem(rober!, [1.0, 0.0, 0.0], (0.0, 1e5), p2), Rodas5(); abstol = 1e-8, reltol = 1e-6)
c() = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 100.0), p1), Tsit5(); callback = cb)
for (n, f) in (("tsit5", a), ("rodas5", b), ("tsit5+cb", c))
    f(); f()
    t = minimum(@elapsed(f()) for _ in 1:50)
    s = f()
    println("S kind=", KIND, " ", n, " ", round(t * 1e3; digits = 3), " ms  naccept ", s.naccept, " nf ", s.nf)
end
