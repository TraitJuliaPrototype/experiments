using TraitDifferentialEquations
const ODE = TraitDifferentialEquations
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
rob!(du, u, p, t) = (du[1] = -0.04u[1] + 1e4 * u[2] * u[3]; du[2] = 0.04u[1] - 1e4 * u[2] * u[3] - 3e7 * u[2]^2; du[3] = 3e7 * u[2]^2; nothing)
c() = Base.cumulative_compile_time_ns()[1] / 1e6
Base.cumulative_compile_timing(true)
step(name, f) = (c0 = c(); t = @elapsed f(); println(rpad(name, 22), " wall ", round(1000t; digits = 1), " ms  compile ", round(c() - c0; digits = 1), " ms"))
step("ODEProblem lorenz", () -> ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]))
p = ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3])
step("solve Tsit5", () -> ODE.solve(p, ODE.Tsit5(); saveat = 0:0.1:20, reltol = 1e-6, abstol = 1e-8))
step("solve Tsit5 again", () -> ODE.solve(p, ODE.Tsit5(); saveat = 0:0.1:20, reltol = 1e-6, abstol = 1e-8))
step("ODEProblem rob", () -> ODE.ODEProblem(rob!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]))
q = ODE.ODEProblem(rob!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0])
step("solve Rodas5", () -> ODE.solve(q, ODE.Rodas5(); saveat = [1.0, 1e5], reltol = 1e-6, abstol = 1e-8))
step("solve Rodas5 again", () -> ODE.solve(q, ODE.Rodas5(); saveat = [1.0, 1e5], reltol = 1e-6, abstol = 1e-8))
