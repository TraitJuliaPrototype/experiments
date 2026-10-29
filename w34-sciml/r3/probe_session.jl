# E-242: the session's first solves (ttfx/workload_d.jl's solve_two, setting D, shape matched, order A), each timed
# with its compile time, to find what the first solve compiles.
using TraitDifferentialEquations, TraitMakie
const ODE = TraitDifferentialEquations
c() = Base.cumulative_compile_time_ns()[1] / 1e6
Base.cumulative_compile_timing(true)
step(name, f) = (c0 = c(); t = @elapsed f(); println(rpad(name, 40), " wall ", round(1000t; digits = 1), " ms  compile ", round(c() - c0; digits = 1), " ms"))
const RT, AT = 1e-6, 1e-8
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
const TL = collect(range(0.0, 20.0; length = 2001)); const TR = exp10.(range(-5, 5; length = 201))
step("ODEProblem lorenz", () -> ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]))
pa = ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3])
step("solve Tsit5 saveat TL", () -> ODE.solve(pa, ODE.Tsit5(); saveat = TL, reltol = RT, abstol = AT))
step("ODEProblem robertson", () -> ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]))
pb = ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0])
step("solve Rodas5 saveat TR", () -> ODE.solve(pb, ODE.Rodas5(); saveat = TR, reltol = RT, abstol = AT))
step("solve Rodas5 saveat TR again", () -> ODE.solve(pb, ODE.Rodas5(); saveat = TR, reltol = RT, abstol = AT))
# as the session calls them: inside one function
function solve_two()
    a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), ODE.Tsit5(); saveat = TL, reltol = RT, abstol = AT)
    b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), ODE.Rodas5(); saveat = TR, reltol = RT, abstol = AT)
    a, b
end
step("solve_two() (in a function)", solve_two)
