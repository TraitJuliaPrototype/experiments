# W-169: the plain twin of the ODE program with callbacks (../../w158/port/apps/ode_cb.jl) on PlainODE: the same
# Lorenz problem, a discrete callback (t > 5: u[1] += 1) and a continuous one (u[1] - 5 crosses 0: u[2] += 0.5).
# PlainODE's problem keeps no callback, so both are given to `solve`. No check is included (the twin has none).
using PlainODE; const ODE = PlainODE
last1(s) = s.u[end][1]
function lorenz!(du, u, p, t)
    s, r, b = p
    du[1] = s * (u[2] - u[1]); du[2] = u[1] * (r - u[3]) - u[2]; du[3] = u[1] * u[2] - b * u[3]
    nothing
end
kick_c(u, t, i) = t > 5.0
kick_a(i) = (i.u[1] += 1.0; nothing)
cross_c(u, t, i) = u[1] - 5.0
cross_a(i) = (i.u[2] += 0.5; nothing)
function (@main)(args::Vector{String})::Cint
    prob = ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 10.0), [10.0, 28.0, 8 / 3])
    a = ODE.solve(prob, ODE.Tsit5(); callback = (ODE.DiscreteCallback(kick_c, kick_a), ODE.ContinuousCallback(cross_c, cross_a)),
                  reltol = 1e-6, abstol = 1e-8)
    println(Core.stdout, "lorenz with callbacks ", round(last1(a); sigdigits = 6))
    return 0
end
