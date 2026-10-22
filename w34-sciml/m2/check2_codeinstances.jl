# E-158 check 2: a new callback compiles nothing in the driver; one integrator type for two callback
# sets. Method as E-157 check 4 (common.jl, `snapshot`): the CodeInstances of every method of ODECore
# (the solvers, the integrators, the callbacks' records) and TraitDifferentialEquations (the front
# end), before and after a step; every module for context; SnoopCompileCore's `@snoop_inference` as a
# second view. Control: PlainODE's typed callbacks (a tuple of typed records) must compile a new driver.
using SnoopCompileCore
include("common.jl")
import PlainODE
using PlainODE: TypedDiscreteCallback, TypedContinuousCallback
const TDE = TraitDifferentialEquations
include("models.jl")
header("check 2", "no new CodeInstance of the driver for a new callback; one integrator type for two callback sets")

const SOLVER = modpred(ODECore, TraitDifferentialEquations)
const CONTROL = modpred(PlainODE)
const ALL = m -> true
function inferred_bymodule(tinf)
    d = Dict{String,Int}(); names = String[]
    walk(n) = for c in n.children
        mi = c.ci.def
        mi isa Core.MethodInstance || (mi = mi.def)
        m = mi.def
        k = m isa Method ? string(m.module) : string(m)
        d[k] = get(d, k, 0) + 1
        k in ("TraitDifferentialEquations.ODECore", "TraitDifferentialEquations") && push!(names, string(m.name, " ", mi.specTypes))
        walk(c)
    end
    walk(tinf)
    return sort!(collect(d); by = first), names
end
function step(label, thunk; pred = SOLVER, what = "ODECore + TraitDifferentialEquations (the driver, the integrators, the callbacks' records, the front end)")
    s0 = snapshot(pred); a0 = snapshot(ALL)
    tinf = @snoop_inference Base.invokelatest(thunk)      # a barrier: the step is not inferred with `step`
    s1 = snapshot(pred); a1 = snapshot(ALL)
    println("--- ", label)
    ks = newin(s0, s1)
    ops = [k for k in ks if k[1].def.name in (:condition, :affect!, :event_condition, :event_affect!)]
    fe = [k for k in ks if k[1].def.module === TraitDifferentialEquations]
    drv = [k for k in ks if !(k in ops) && !(k in fe)]
    report_new(what, ks)
    pred === SOLVER && println("    of them: the driver and init (ODECore) ", length(drv), "; the callbacks' operations at a callback type (its own entries) ",
                               length(ops), "; the front end (the ordinary module) ", length(fe))
    DRIVER[] = length(drv)
    tw = [k for k in newin(a0, a1) if k[1].def.module === TraitWorld]
    report_new("TraitWorld", tw; show = 12)
    println("  every module: ", sum(n for (_, n) in bymodule(newin(a0, a1)); init = 0), " new CodeInstance(s), by module of the method: ",
            join(["$k $n" for (k, n) in bymodule(newin(a0, a1))], ", "))
    inf, nm = inferred_bymodule(tinf)
    println("  @snoop_inference, methods inferred, by module: ", isempty(inf) ? "none" : join(["$k $n" for (k, n) in inf], ", "))
    isempty(nm) || println("     of them in the solver's modules: ", join(first.(nm, 200), "\n       "))
    println()
    return length(newin(s0, s1))
end
const DRIVER = Ref(0)

const U0 = [1.0, 0.0]
oscprob() = TDE.ODEProblem(osc!, U0, (0.0, 10.0), oscp())
ballprob() = TDE.ODEProblem(ball!, [1.0, 0.0], (0.0, 4.0), ballp())
tdecbs(set) = Any[TDE.DiscreteCallback(c, a) for (c, a) in set]

"A callback type of the user's: a kick when `u[1]` passes below `lim` (a plain module's type)."
module UserCB
using TraitWorld, TraitDifferentialEquations
import ..OscParams
struct BelowKick
    lim::Float64
end
const OscView = Dynamic{IntegratorView{Vector{Float64}, Float64, OscParams}}
TraitDifferentialEquations.condition(cb::BelowKick, u::Vector{Float64}, t::Float64, integ::OscView) = u[1] < cb.lim
TraitDifferentialEquations.affect!(cb::BelowKick, integ::OscView) = (integ.u[2] += integ.p.k * 0.01; nothing)
end

step("warm-up: the oscillator with three discrete callbacks (models.jl), with saveat; the ball with two continuous and one discrete; one callback alone of each kind",
     () -> (log = Any[]; TDE.solve(oscprob(), TDE.Tsit5(); callback = tdecbs(discrete_set(TDE.add_tstop!, TDE.terminate!, log)));
            TDE.solve(oscprob(), TDE.Tsit5(); callback = tdecbs(discrete_set(TDE.add_tstop!, TDE.terminate!, log)), saveat = 0:0.5:10);
            (es, ds) = event_set(log);
            TDE.solve(ballprob(), TDE.Tsit5(); callback = Any[[TDE.ContinuousCallback(c, a) for (c, a) in es]..., tdecbs(ds)...]);
            # the front end's call shapes: one callback, not a vector (the keyword call is compiled per shape and problem type)
            TDE.solve(ballprob(), TDE.Tsit5(); callback = TDE.DiscreteCallback(ds[1]...));
            TDE.solve(oscprob(), TDE.Tsit5(); callback = TDE.DiscreteCallback((u, t, i) -> false, i -> nothing));
            TDE.solve(ballprob(), TDE.Tsit5(); callback = TDE.ContinuousCallback(es[1]...))))
n1 = step("a new discrete callback (two new closures)",
          () -> TDE.solve(oscprob(), TDE.Tsit5(); callback = TDE.DiscreteCallback((u, t, i) -> u[2] > 1.5, i -> (i.u[2] *= 0.5; nothing))))
n2 = step("two new discrete callbacks and the old ones",
          () -> TDE.solve(oscprob(), TDE.Tsit5(); callback = Any[TDE.DiscreteCallback((u, t, i) -> t > 2.0 && i.p.k < 5.0, i -> (i.p.k = 5.0; nothing)),
                                                             TDE.DiscreteCallback((u, t, i) -> u[1] > 2.0, i -> TDE.terminate!(i)),
                                                             tdecbs(discrete_set(TDE.add_tstop!, TDE.terminate!, Any[]))...]))
n3 = step("a new continuous callback",
          () -> TDE.solve(ballprob(), TDE.Tsit5(); callback = TDE.ContinuousCallback((u, t, i) -> u[1] - 0.5, i -> nothing)))
Core.eval(UserCB, :(@implement Callback{Vector{Float64}, Float64, OscParams} BelowKick))
n4 = step("the first callback type (UserCB.BelowKick, declared before the step)",
          () -> TDE.solve(oscprob(), TDE.Tsit5(); callback = UserCB.BelowKick(-0.5)))
d4 = DRIVER[]
Core.eval(UserCB, :(struct AboveDamp; lim::Float64; end))
Core.eval(UserCB, :(TraitDifferentialEquations.condition(cb::AboveDamp, u::Vector{Float64}, t::Float64, integ::OscView) = u[1] > cb.lim))
Core.eval(UserCB, :(TraitDifferentialEquations.affect!(cb::AboveDamp, integ::OscView) = (integ.u[2] *= 0.9; nothing)))
Core.eval(UserCB, :(@implement Callback{Vector{Float64}, Float64, OscParams} AboveDamp))
n5 = step("a second callback type (UserCB.AboveDamp)",
          () -> TDE.solve(oscprob(), TDE.Tsit5(); callback = (UserCB.AboveDamp(0.8), UserCB.BelowKick(-0.5))))
d5 = DRIVER[]

# one integrator type for two callback sets: Tsit5's `init`
pr = oscprob()
iA = ODECore.tsit5_init(pr, pr.u0, pr.tspan, pr.p, tdecbs(discrete_set(TDE.add_tstop!, TDE.terminate!, Any[])))
iB = ODECore.tsit5_init(pr, pr.u0, pr.tspan, pr.p, Any[TDE.DiscreteCallback((u, t, i) -> false, i -> nothing), UserCB.BelowKick(0.0),
                                                        TDE.ContinuousCallback((u, t, i) -> u[1], i -> nothing)])
println("integrator types: set A (three closures' callbacks) ", typeof(iA), "; set B (a closure, a callback type, a continuous one) ", typeof(iB))
println("  the callbacks' vector: ", typeof(iA.callbacks), "; its items: ", unique(typeof.(iA.callbacks)), " / ", unique(typeof.(iB.callbacks)))

# control: PlainODE's typed callbacks compile a driver per set (the method sees driver code)
pp() = PlainODE.ODEProblem(osc!, U0, (0.0, 10.0), oscp())
PlainODE.solve_typed(pp(), PlainODE.Tsit5(); callbacks = (TypedDiscreteCallback((u, t, i) -> false, i -> nothing),))
ctl_new() = PlainODE.solve_typed(pp(), PlainODE.Tsit5(); callbacks = (TypedDiscreteCallback((u, t, i) -> u[2] > 1.5, i -> (i.u[2] *= 0.5; nothing)),))
nc = step("control: PlainODE typed, a new discrete callback (expected: a new driver)", ctl_new;
          pred = CONTROL, what = "PlainODE (the control's driver)")
check("a new discrete callback: no new CodeInstance in ODECore + TDE", n1 == 0, string(n1))
check("two new discrete callbacks with the old ones: none", n2 == 0, string(n2))
check("a new continuous callback: none", n3 == 0, string(n3))
println("  (the first callback type: init's branch for values of callback types, compiled once per key: $d4 driver CodeInstance(s))")
check("a second callback type: none in the driver (the type's own operation entries only)", d5 == 0, "total $n5, driver $d5")
check("one integrator type for two callback sets", typeof(iA) === typeof(iB), string(typeof(iA)))
check("the control's typed driver is seen by the count", nc > 0, string(nc))
println("RESULT check2 new driver CodeInstances: discrete $n1, two discrete $n2, continuous $n3, first callback type $n4 (driver $d4), second $n5 (driver $d5); control (PlainODE typed) $nc")
footer()
