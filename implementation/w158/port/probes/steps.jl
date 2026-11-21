# W-158, the port's part: the ODE examples' results and step counts, before and after a change; and two small
# timings of a solve (the second call on, the minimum of 5). One line per example: the return code, accepted and
# rejected steps, right-hand-side calls, the saved points, the parameters saved, and a digest of the printed
# times, states and saved parameters (SHA-1; the printed form, playbook §4).
#     julia --project=../../w156/env_demo probes/steps.jl
using TraitWorld, TraitDifferentialEquations, SHA
const ODE = TraitDifferentialEquations
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
function robertson!(du, u, p, t)
    du[1] = -0.04u[1] + 1e4 * u[2] * u[3]
    du[2] = 0.04u[1] - 1e4 * u[2] * u[3] - 3e7 * u[2]^2
    du[3] = 3e7 * u[2]^2
    nothing
end
ljac!(J, u, p, t) = (J[1, 1] = -p[1]; J[1, 2] = p[1]; J[1, 3] = 0.0; J[2, 1] = p[2] - u[3]; J[2, 2] = -1.0; J[2, 3] = -u[1];
                     J[3, 1] = u[2]; J[3, 2] = u[1]; J[3, 3] = -p[3]; nothing)
const P0 = [10.0, 28.0, 8 / 3]; const U0 = [1.0, 0.0, 0.0]
digest(s) = bytes2hex(sha1(string(s.t, s.u, s.pt, s.pu)))[1:12]
line(name, s) = println(rpad(name, 34), s.retcode, " accept ", s.naccept, " reject ", s.nreject, " nf ", s.nf,
                        " saved ", length(s.t), " psaved ", length(s.pt), " digest ", digest(s), " u_end ", s.u[end])
kick() = DiscreteCallback((u, t, i) -> t > 0.5, i -> (i.u[1] += 1.0; nothing))
cross() = ContinuousCallback((u, t, i) -> u[1] - 5.0, i -> (i.u[2] += 0.5; nothing))
pkick() = DiscreteCallback((u, t, i) -> t > 0.3, i -> (i.p[1] = 11.0; save_discretes!(i); nothing))
lp() = ODEProblem(lorenz!, copy(U0), (0.0, 1.0), copy(P0))
rob() = ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0])
const SAVE = collect(range(0.0, 20.0; length = 2001))
cases = [
    "app lorenz Tsit5" => () -> solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), Tsit5();
                                      saveat = SAVE, reltol = 1e-6, abstol = 1e-8),
    "app robertson Rodas5" => () -> solve(rob(), Rodas5(); saveat = exp10.(range(-5, 5; length = 201)), reltol = 1e-6, abstol = 1e-8),
    "lorenz Rodas5" => () -> solve(lp(), Rodas5()),
    "lorenz Rodas5 chunk 0" => () -> solve(lp(), Rodas5(chunk_size = 0)),
    "lorenz Rodas5 chunk 2" => () -> solve(lp(), Rodas5(chunk_size = 2)),
    "lorenz Rodas5 compiled chunk 0" => () -> solve(ODEProblem(compiled_for(lorenz!), copy(U0), (0.0, 1.0), copy(P0)), Rodas5(chunk_size = 0)),
    "lorenz Rodas5 jac" => () -> solve(ODEProblem(ODEFunction(lorenz!; jac = ljac!), copy(U0), (0.0, 1.0), copy(P0)), Rodas5()),
    "lorenz Tsit5 compiled" => () -> solve(ODEProblem(compiled_for(lorenz!), copy(U0), (0.0, 1.0), copy(P0)), Tsit5()),
    "lorenz Tsit5 Float32" => () -> solve(ODEProblem(lorenz!, Float32[1, 0, 0], (0.0, 1.0), Float32[10, 28, 8 / 3]), Tsit5()),
    "lorenz Tsit5 discrete" => () -> solve(lp(), Tsit5(); callback = kick()),
    "lorenz Tsit5 continuous" => () -> solve(lp(), Tsit5(); callback = cross()),
    "lorenz Tsit5 tuple" => () -> solve(lp(), Tsit5(); callback = (kick(), cross())),
    "lorenz Tsit5 vector" => () -> solve(lp(), Tsit5(); callback = [kick(), cross()]),
    "lorenz Tsit5 problem+given" => () -> solve(ODEProblem(lorenz!, copy(U0), (0.0, 1.0), copy(P0); callback = cross()), Tsit5(); callback = pkick()),
    "lorenz Rodas5 discrete" => () -> solve(lp(), Rodas5(); callback = (kick(), cross())),
    "lorenz remake p" => () -> solve(remake(ODEProblem(lorenz!, copy(U0), (0.0, 1.0), copy(P0); callback = kick()); p = [10.0, 27.0, 8 / 3]), Tsit5()),
    "lorenz init/solve!" => () -> (i = init(lp(), Tsit5(); callback = kick()); step!(i); solve!(i)),
    "lorenz init Rodas5 chunk 0" => () -> (i = init(lp(), Rodas5(chunk_size = 0)); step!(i); solve!(i)),
]
for (name, f) in cases
    line(name, f())
end
g = gradient(p -> sum(solve(ODEProblem(lorenz!, [one(eltype(p)), zero(eltype(p)), zero(eltype(p))], (0.0, 1.0), p), Tsit5()).u[end]), copy(P0))
println(rpad("gradient", 34), g)
println("rhs_function: ", typeof(rhs_function(lp())), " ", rhs_function(lp()).f === lorenz!, " ",
        rhs_function(ODEProblem(ODEFunction(lorenz!; jac = ljac!), copy(U0), (0.0, 1.0), copy(P0))) === nothing)
# two small timings: the app's solves, the second call on, the minimum of 5
for (name, f) in cases[1:2]
    f()
    t = minimum(@elapsed(f()) for _ in 1:5)
    println("time ", rpad(name, 28), round(t * 1e3; digits = 2), " ms")
end
