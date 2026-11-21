# W-158, the nonlinear front end (open issue 246): what a session compiles for a nonlinear solve with a new residual
# function. One process: TDE loaded; phase A solves a NonlinearProblem (sq1!) with NewtonRaphson, TrustRegion and the
# default polyalgorithm (`solve(prob)`), and a SteadyStateProblem (ss1!) with NewtonRaphson; phase B the same with new
# functions (sq2!, ss2!); phase C the same with a third pair (sq3!, ss3!) through a function of Main that calls `solve`
# (a caller that infers the front end). Per phase: the compile time (Base.cumulative_compile_time_ns), and the method
# instances that hold code and did not before the phase, by the method's root module (a whole-method-table diff).
# The results, printed as digests, must be equal before and after a change of the front end.
#     julia --project=../../w156/env_demo q_nl_session.jl         (LIST=1: phase B's and C's new instances, each; LIST=2: every phase's)
using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
sq1!(r, u, p) = (r[1] = u[1]^2 - p[1]; r[2] = u[2]^2 - p[2]; nothing)
sq2!(r, u, p) = (r[1] = u[1]^3 - p[1]; r[2] = u[2] - u[1] - p[2]; nothing)
sq3!(r, u, p) = (r[1] = exp(u[1]) - p[1]; r[2] = u[2]^2 - p[2]; nothing)
ss1!(du, u, p, t) = (du[1] = p[1] - u[1]; du[2] = p[2] - u[2]; nothing)
ss2!(du, u, p, t) = (du[1] = p[1] - u[1]^3; du[2] = u[1] - u[2]; nothing)
ss3!(du, u, p, t) = (du[1] = p[1] - 2u[1]; du[2] = p[2] * u[1] - u[2]; nothing)

function instances()
    s = Set{Core.MethodInstance}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi === nothing && continue
            isdefined(mi, :cache) && push!(s, mi)
        end
    end
    return s
end
digest(sol) = string(sol.retcode, " ", sol.stats.nsteps, " ", sol.stats.nf, " ", sol.stats.njacs, " ",
                     join(round.(sol.u; sigdigits = 12), ","), " ", round(maximum(abs, sol.resid); sigdigits = 3))
function phase(f, g)
    out = String[]
    pa = ODE.NonlinearProblem(f, [1.0, 1.0], [2.0, 3.0])
    push!(out, digest(ODE.solve(pa, ODE.NewtonRaphson())))
    push!(out, digest(ODE.solve(pa, ODE.TrustRegion())))
    push!(out, digest(ODE.solve(pa)))
    push!(out, digest(ODE.solve(ODE.SteadyStateProblem(g, [0.0, 0.0], [1.0, 2.0]), ODE.NewtonRaphson())))
    return out
end
# a caller of Main that infers the front end: its result's type known or not
caller(f, g) = phase(f, g)

const PKGS = (:TraitNonlinearSolve, :TraitDifferentialEquations, :ODECore, :TraitWorld, :Main)
function run_phase(name, thunk)
    before = instances()
    c0 = Base.cumulative_compile_time_ns()
    Base.cumulative_compile_timing(true)
    t = @elapsed out = Base.invokelatest(thunk)
    Base.cumulative_compile_timing(false)
    c1 = Base.cumulative_compile_time_ns()
    new = setdiff(instances(), before)
    by = Dict{Symbol,Int}()
    for mi in new
        p = nameof(Base.moduleroot(mi.def isa Method ? mi.def.module : mi.def))
        k = p in PKGS ? p : (p in (:Core, :Base) ? :Base : :other)
        by[k] = get(by, k, 0) + 1
    end
    println("phase $name: $(round(t * 1e3; digits = 1)) ms, compiling $(round((c1[1] - c0[1]) / 1e6; digits = 1)) ms; ",
            "new instances $(length(new)): ", join(("$k $(get(by, k, 0))" for k in (PKGS..., :Base, :other)), ", "))
    for o in out
        println("  result ", o)
    end
    if (get(ENV, "LIST", "0") == "1" && name != "A") || get(ENV, "LIST", "0") == "2"
        for l in sort!([string(mi.specTypes) for mi in new])
            println("    new ", first(l, 300))
        end
    end
end
run_phase("A", () -> phase(sq1!, ss1!))
run_phase("B", () -> phase(sq2!, ss2!))
run_phase("C", () -> caller(sq3!, ss3!))
