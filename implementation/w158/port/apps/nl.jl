# W-158, the other ports: a small nonlinear solve and a steady state of TraitNonlinearSolve (through TDE), the
# program the probe `../probes/nl_members.jl` checks. Residuals and a Newton solve at Float64 states, a Jacobian by duals.
using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
sq!(r, u, p) = (r[1] = u[1]^2 - p[1]; r[2] = u[2]^2 - p[2]; nothing)
relax!(du, u, p, t) = (du[1] = p[1] - u[1]; du[2] = p[2] - u[2]; nothing)
function (@main)(args::Vector{String})::Cint
    a = ODE.solve(ODE.NonlinearProblem(sq!, [1.0, 1.0], [2.0, 3.0]), ODE.NewtonRaphson())
    b = ODE.solve(ODE.SteadyStateProblem(relax!, [0.0, 0.0], [1.0, 2.0]), ODE.NewtonRaphson())
    println(Core.stdout, "nonlinear ", round(a.u[1]; sigdigits = 6), " steady ", round(b.u[2]; sigdigits = 6))
    return 0
end
