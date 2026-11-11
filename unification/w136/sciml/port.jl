# E-363: the three cases on the port (TraitDifferentialEquations) and on its plain twin (PlainODE).
#     julia port.jl trait|plain
const FORM = ARGS[1]
@static if FORM == "plain"
    using PlainODE; const ODE = PlainODE
else
    using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
end
include(joinpath(@__DIR__, "report.jl"))
function lorenz!(du, u, p, t)
    du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]
    nothing
end
const U0 = [1.0, 0.0, 0.0]
report(FORM, "1-noparams", () -> ODE.solve(ODE.ODEProblem(lorenz!, U0, (0.0, 1.0)), ODE.Tsit5()))
const cache = zeros(3)
function cached!(du, u, p, t)
    cache .= u                       # a Float64 buffer: it cannot hold dual numbers
    lorenz!(du, cache, p, t)
end
loss(p) = sum(ODE.solve(ODE.ODEProblem(cached!, eltype(p).(U0), (0.0, 1.0), p), ODE.Tsit5()).u[end])
report(FORM, "2-dualcache-gradient", () -> ODE.gradient(loss, [10.0, 28.0, 8 / 3]))
report(FORM, "3-dualcache-rodas5", () -> ODE.solve(ODE.ODEProblem(cached!, U0, (0.0, 1.0), [10.0, 28.0, 8 / 3]), ODE.Rodas5()))
