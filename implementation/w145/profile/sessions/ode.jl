#@ load
using TraitWorld, TraitDifferentialEquations
#@ _definitions
const ODE = TraitDifferentialEquations
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
#@ first solve (Lorenz, Tsit5)
a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), ODE.Tsit5(); saveat = collect(range(0.0, 20.0; length = 2001)), reltol = 1e-6, abstol = 1e-8)
#@ first stiff solve (Robertson, Rodas5)
b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), ODE.Rodas5(); saveat = exp10.(range(-5, 5; length = 201)), reltol = 1e-6, abstol = 1e-8)
#@ a new right-hand side (a closure)
k = 2.0
c = ODE.solve(ODE.ODEProblem((du, u, p, t) -> (du .= -k .* u; nothing), [1.0, 2.0], (0.0, 1.0), nothing), ODE.Tsit5())
#@ the solves again
a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), ODE.Tsit5(); saveat = collect(range(0.0, 20.0; length = 2001)), reltol = 1e-6, abstol = 1e-8)
b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), ODE.Rodas5(); saveat = exp10.(range(-5, 5; length = 201)), reltol = 1e-6, abstol = 1e-8)
