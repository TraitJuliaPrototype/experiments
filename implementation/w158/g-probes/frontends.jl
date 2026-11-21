# Open issue 250: what a session infers for the ODE and the nonlinear front ends at concrete types, and the
# statement that loses the type. Run: $JN --project=$ENVG $W158/g-probes/frontends.jl   (RUN=1: solve first)
using TraitWorld, TraitDifferentialEquations, InteractiveUtils
const ODE = TraitDifferentialEquations
const TNS = ODE.TraitNonlinearSolve
const OC = ODE.ODECore
println("TraitWorld at ", pathof(TraitWorld))
sq!(r, u, p) = (r[1] = u[1]^2 - p[1]; r[2] = u[2]^2 - p[2]; nothing)
relax!(du, u, p, t) = (du[1] = p[1] - u[1]; du[2] = p[2] - u[2]; nothing)
function lorenz!(du, u, p, t)
    s, r, b = p
    du[1] = s * (u[2] - u[1]); du[2] = u[1] * (r - u[3]) - u[2]; du[3] = u[1] * u[2] - b * u[3]
    nothing
end
nlp = ODE.NonlinearProblem(sq!, [1.0, 1.0], [2.0, 3.0])
ssp = ODE.SteadyStateProblem(relax!, [0.0, 0.0], [1.0, 2.0])
odp = ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3])
nr = ODE.NewtonRaphson(); ts = ODE.Tsit5(); ro = ODE.Rodas5()
opts = TNS.NLOptions(1e-8, 1e-8, 100)
sopts = ODE._options(; reltol = 1e-6, abstol = 1e-8)
if get(ENV, "RUN", "0") == "1"
    ODE.solve(nlp, nr); ODE.solve(ssp, nr); ODE.solve(odp, ts; reltol = 1e-6, abstol = 1e-8)
    println("ran the three solves")
end
cases = Any[
    ("TNS.solve_nonlinear", TNS.solve_nonlinear, (typeof(nlp), typeof(nr), typeof(opts))),
    ("TNS.solve_nonlinear steady", TNS.solve_nonlinear, (typeof(ssp), typeof(nr), typeof(opts))),
    ("TNS.solve", TNS.solve, (typeof(nlp), typeof(nr))),
    ("ODE.solve nl", ODE.solve, (typeof(nlp), typeof(nr))),
    ("TNS.nl_core", TNS.nl_core, (typeof(nlp),)),
    ("OC.solve_ode", OC.solve_ode, (typeof(odp), typeof(ts), Nothing, typeof(sopts))),
    ("OC.solve_ode Rodas5", OC.solve_ode, (typeof(odp), typeof(ro), Nothing, typeof(sopts))),
    ("OC.core_problem", OC.core_problem, (typeof(odp),)),
    ("ODE.solve ode", ODE.solve, (typeof(odp), typeof(ts))),
]
println("\nnonlinear problem type: ", typeof(nlp), "\nODE problem type: ", typeof(odp))
for (name, f, tt) in cases
    rt = Base.infer_return_type(f, tt)
    println("\n== ", name, " at ", tt, "\n   infer_return_type: ", rt)
    if get(ENV, "DUMP", "0") == "1" || rt === Any
        ct = Base.code_typed(f, tt; optimize = false)
        for (src, r) in ct
            for (i, st) in enumerate(src.code)
                t = src.ssavaluetypes[i]
                (get(ENV, "DUMP", "0") == "1" || t === Any || occursin("return", string(st))) && println("     %", i, " = ", st, " :: ", t)
            end
        end
    end
end
