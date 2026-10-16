order = ARGS[1]
order == "before" && @eval Base.abs2(x::Float64) = 1.0001 * x * x       # a pirate of Base, defined before the image loads
using TraitDifferentialEquations
order == "after" && @eval Base.abs2(x::Float64) = 1.0001 * x * x
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
sol = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
println(rpad(order, 7), " steps ", length(sol.t), "  u(end) ", repr(sol.u[end][1]), "  abs2(3.0) = ", abs2(3.0))
