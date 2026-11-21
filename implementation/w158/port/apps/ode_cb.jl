# W-158, the port's part: the ODE program (../../../w135/apps/ode.jl) with callbacks the program knows, a tuple of
# a discrete and a continuous callback given to `solve` and one kept by the problem (open issue 184's proposal (a)).
# Built by ../build.sh's script with APP=apps/ode_cb (see the README); the callbacks' own errors are the compiler's
# (C-151, C-154: SciML's records keep their functions at bare `Callable`, open issue 159).
using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
last1(s) = ODE.ODECore.state(s, length(ODE.ODECore.times(s)))[1]
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
    prob = ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 10.0), [10.0, 28.0, 8 / 3];
                          callback = ODE.DiscreteCallback(kick_c, kick_a))
    a = ODE.solve(prob, ODE.Tsit5(); callback = (ODE.ContinuousCallback(cross_c, cross_a),), reltol = 1e-6, abstol = 1e-8)
    println(Core.stdout, "lorenz with callbacks ", round(last1(a); sigdigits = 6))
    return 0
end
include(joinpath(@__DIR__, "..", "..", "..", "w135", "apps", "verify.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "w135", "apps", "jllhole.jl"))
