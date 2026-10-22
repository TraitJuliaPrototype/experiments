# E-158 check 1: event times and states equal to the typed control (PlainODE), bit for bit.
# Stage 1: three discrete callbacks (kick by add_tstop!, a write to p, terminate!) on a damped
# oscillator, every step saved and with saveat. Stage 2: two scalar continuous callbacks (bisection on
# interp!, the same text in both) and a discrete one, on a bouncing ball.
include("common.jl")
import PlainODE
using PlainODE: TypedDiscreteCallback, TypedContinuousCallback
const TDE = TraitDifferentialEquations
include("models.jl")
header("check 1", "event times and states against the typed control (PlainODE), bit for bit")

summ(s) = (s.t, s.u, s.retcode, s.naccept, s.nreject, s.nf)
function run_tde(prob_f, u0, tspan, pmk, dset, eset; compiled = false, kw...)
    log = Any[]; p = pmk()
    f = compiled ? TraitWorld.compiled_for(prob_f) : prob_f
    cbs = Any[]
    eset !== nothing && for (c, a) in eset(log)[1]; push!(cbs, TDE.ContinuousCallback(c, a)); end
    ds = dset === :discrete ? discrete_set(TDE.add_tstop!, TDE.terminate!, log) : eset(log)[2]
    for (c, a) in ds; push!(cbs, TDE.DiscreteCallback(c, a)); end
    s = TDE.solve(TDE.ODEProblem(f, u0, tspan, p), TDE.Tsit5(); callback = cbs, kw...)
    return summ(s), log, p
end
function run_ctl(prob_f, u0, tspan, pmk, dset, eset; typed = true, kw...)
    log = Any[]; p = pmk()
    ds = dset === :discrete ? discrete_set(PlainODE.add_tstop!, PlainODE.terminate!, log) : eset(log)[2]
    es = eset === nothing ? () : eset(log)[1]
    if typed
        s = PlainODE.solve_typed(PlainODE.ODEProblem(prob_f, u0, tspan, p), PlainODE.Tsit5();
                                 callbacks = map(x -> TypedDiscreteCallback(x...), ds), events = map(x -> TypedContinuousCallback(x...), es), kw...)
    else
        cb = Any[[PlainODE.ContinuousCallback(x...) for x in es]..., [PlainODE.DiscreteCallback(x...) for x in ds]...]
        s = PlainODE.solve(PlainODE.ODEProblem(prob_f, u0, tspan, p), PlainODE.Tsit5(); callback = cb, kw...)
    end
    return summ(s), log, p
end
pfields(p) = Tuple(getfield(p, k) for k in fieldnames(typeof(p)))
showlog(log) = string(length(log), " events: ", join([string(n, "@", repr(t)) for (n, t, _) in log[1:min(end, 12)]], " "), length(log) > 12 ? " …" : "")

ok_all = true
function compare(label, runs)
    global ok_all
    (s1, l1, p1) = runs[1][2]
    println("  ", label, ": ", length(s1[1]), " saved points, retcode ", s1[3], ", naccept ", s1[4], ", nreject ", s1[5], ", nf ", s1[6], ", final p ", pfields(p1))
    println("    ", showlog(l1))
    for (name, (s, l, p)) in runs[2:end]
        same = s == s1 && l == l1 && pfields(p) == pfields(p1)
        ok_all &= same
        println("    ", rpad(name, 34), same ? "identical (t, u, retcode, counts, event log with states, final p)" :
                "DIFFERS: t $(s[1] == s1[1]) u $(s[2] == s1[2]) counts $(s[3:6] == s1[3:6]) log $(l == l1) p $(pfields(p) == pfields(p1))")
    end
end

println("Stage 1: discrete callbacks (oscillator, u0 = [1, 0], 0 ≤ t ≤ 10)")
u0o = [1.0, 0.0]; to = (0.0, 10.0)
for (lbl, kw) in (("every step saved", (;)), ("saveat 0:0.25:10", (; saveat = 0:0.25:10)), ("abstol = reltol = 1e-10", (; abstol = 1e-10, reltol = 1e-10)))
    compare(lbl, [("TDE (Dynamic f)", run_tde(osc!, u0o, to, oscp, :discrete, nothing; kw...)),
                  ("TDE (compiled_for f)", run_tde(osc!, u0o, to, oscp, :discrete, nothing; compiled = true, kw...)),
                  ("control: PlainODE typed callbacks", run_ctl(osc!, u0o, to, oscp, :discrete, nothing; kw...)),
                  ("PlainODE Vector{Any} callbacks", run_ctl(osc!, u0o, to, oscp, :discrete, nothing; typed = false, kw...))])
end
# a callback's effect is real: without the callbacks the solution differs
s_none = TDE.solve(TDE.ODEProblem(osc!, u0o, to, oscp()), TDE.Tsit5())
s_cb = run_tde(osc!, u0o, to, oscp, :discrete, nothing)[1]
check("the callbacks change the solution (control against no callbacks)", s_none.u[end] != s_cb[2][end] && s_cb[3] === :Terminated, "")
kicks = [t for (n, t, _) in run_tde(osc!, u0o, to, oscp, :discrete, nothing)[2] if n === :kick]
check("kicks after the first land exactly on the tstops (2.0, 3.0, …)", kicks[2:end] == collect(2.0:1.0:Float64(length(kicks))), string(kicks))

println("\nStage 2: continuous callbacks (bouncing ball, u0 = [1, 0], 0 ≤ t ≤ 4, before the bounces accumulate at t ≈ 4.31)")
u0b = [1.0, 0.0]; tb = (0.0, 4.0)
for (lbl, kw) in (("every step saved", (;)), ("saveat 0:0.05:4", (; saveat = 0:0.05:4)), ("abstol = reltol = 1e-10", (; abstol = 1e-10, reltol = 1e-10)))
    compare(lbl, [("TDE (Dynamic f)", run_tde(ball!, u0b, tb, ballp, :events, event_set; kw...)),
                  ("TDE (compiled_for f)", run_tde(ball!, u0b, tb, ballp, :events, event_set; compiled = true, kw...)),
                  ("control: PlainODE typed callbacks", run_ctl(ball!, u0b, tb, ballp, :events, event_set; kw...)),
                  ("PlainODE Vector{Any} callbacks", run_ctl(ball!, u0b, tb, ballp, :events, event_set; typed = false, kw...))])
end
lg = run_tde(ball!, u0b, tb, ballp, :events, event_set; abstol = 1e-10, reltol = 1e-10)[2]
g1 = [t for (n, t, _) in lg if n === :ground]
check("the first ground contact at sqrt(2/g) (1e-9)", isapprox(g1[1], sqrt(2 / 9.81); atol = 1e-9), string(g1[1], " vs ", sqrt(2 / 9.81)))
check("the ball stays above the ground (every saved height ≥ -1e-9)",
      minimum(x[1] for x in run_tde(ball!, u0b, tb, ballp, :events, event_set; saveat = 0:0.01:4)[1][2]) >= -1e-9, "")
check("every run identical to the control", ok_all, "")
footer()
