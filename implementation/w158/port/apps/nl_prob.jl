# W-158, the other ports: only the nonlinear problems' construction (no solve), to read their check apart from the solver's front end.
using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
sq!(r, u, p) = (r[1] = u[1]^2 - p[1]; r[2] = u[2]^2 - p[2]; nothing)
relax!(du, u, p, t) = (du[1] = p[1] - u[1]; du[2] = p[2] - u[2]; nothing)
function (@main)(args::Vector{String})::Cint
    a = ODE.NonlinearProblem(sq!, [1.0, 1.0], [2.0, 3.0])
    b = ODE.SteadyStateProblem(relax!, [0.0, 0.0], [1.0, 2.0])
    println(Core.stdout, "problems ", length(a.u0), " ", length(b.u0))
    return 0
end
