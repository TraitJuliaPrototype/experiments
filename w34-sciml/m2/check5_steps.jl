# E-158 check 5: what a Tsit5 step with two discrete callbacks costs and allocates, against the
# typed control (PlainODE, callbacks in a tuple) and PlainODE's untyped callbacks (Vector{Any}).
# The oscillator (2 states, p a Vector), 0 ≤ t ≤ 1000, dtmax 0.1: 10,000 accepted steps. The two
# callbacks never fire: one reads u, one reads integ.p through the view. Best of five solves, ns per
# accepted step; allocations per step from @allocated over one solve. A quick regression check, not
# a measurement. Then one call of each callback operation in a loop, to attribute the cost.
# usage: check5_steps.jl [hot]   hot: the library's hot members declared on their own first (L-37's workaround)
include("common.jl")
import PlainODE
using PlainODE: TypedDiscreteCallback
const TDE = TraitDifferentialEquations
const HOT = "hot" in ARGS
header("check 5", "a Tsit5 step with two callbacks, against the typed control" * (HOT ? " (hot members declared on their own)" : ""))

if HOT
    # L-37's workaround: the members the loop uses declared on their own, before their first use
    for ex in (:(@implement Callback{Vector{Float64}, Float64, Vector{Float64}} FunctionCallback{Vector{Float64}, Float64, Vector{Float64}}),
               :(@implement IntegratorView Tsit5Integrator{Float64, Vector{Float64}}))
        r = try Core.eval(ODECore, ex); "declared" catch e; "refused: " * first(split(sprint(showerror, e), '\n')) end
        println("  in ODECore: ", ex, ": ", r)
    end
end

osc2!(du, u, p, t) = (du[1] = u[2]; du[2] = -p[1] * u[1] - p[2] * u[2]; nothing)
const U0 = [1.0, 0.0]; const PV = [4.0, 0.0]; const TS = (0.0, 1000.0)
c1 = (u, t, i) -> u[1] > 1e6
c2 = (u, t, i) -> i.p[1] < 0.0
a0 = i -> nothing
tde(cbs) = TDE.solve(TDE.ODEProblem(osc2!, U0, TS, PV), TDE.Tsit5(); callback = cbs, dtmax = 0.1)
ctl(cbs) = PlainODE.solve_typed(PlainODE.ODEProblem(osc2!, U0, TS, PV), PlainODE.Tsit5(); callbacks = cbs, dtmax = 0.1)
unt(cbs) = PlainODE.solve(PlainODE.ODEProblem(osc2!, U0, TS, PV), PlainODE.Tsit5(); callback = cbs, dtmax = 0.1)
cases = [
    ("TDE, no callbacks", () -> tde(Any[])),
    ("TDE, two callbacks (Dynamic closures)", () -> tde(Any[TDE.DiscreteCallback(c1, a0), TDE.DiscreteCallback(c2, a0)])),
    ("TDE, two callbacks (compiled_for closures)", () -> tde(Any[TDE.DiscreteCallback(compiled_for(c1), compiled_for(a0)),
                                                                TDE.DiscreteCallback(compiled_for(c2), compiled_for(a0))])),
    ("control: PlainODE typed, no callbacks", () -> ctl(())),
    ("control: PlainODE typed, two callbacks", () -> ctl((TypedDiscreteCallback(c1, a0), TypedDiscreteCallback(c2, a0)))),
    ("PlainODE Vector{Any}, two callbacks", () -> unt(Any[PlainODE.DiscreteCallback(c1, a0), PlainODE.DiscreteCallback(c2, a0)])),
]
res = Dict{String,Tuple{Float64,Float64,Int}}()
for (lbl, f) in cases
    s = f(); f()                                   # compile, warm
    n = s.naccept
    best = minimum(@elapsed(f()) for _ in 1:5)
    al = @allocated f()
    res[lbl] = (best / n * 1e9, al / n, n)
    @printf("  %-46s %6d steps  %8.1f ns/step  %8.1f bytes/step\n", lbl, n, best / n * 1e9, al / n)
end
d(a, b) = (res[a][1] - res[b][1], res[a][2] - res[b][2])
dt, at = d("TDE, two callbacks (Dynamic closures)", "TDE, no callbacks")
dtc, atc = d("TDE, two callbacks (compiled_for closures)", "TDE, no callbacks")
dc, ac = d("control: PlainODE typed, two callbacks", "control: PlainODE typed, no callbacks")
du, au = d("PlainODE Vector{Any}, two callbacks", "control: PlainODE typed, no callbacks")
@printf("  two callbacks add per step: TDE (Dynamic) %.1f ns, %.1f bytes; TDE (compiled_for) %.1f ns, %.1f bytes; control (typed) %.1f ns, %.1f bytes; PlainODE Vector{Any} %.1f ns, %.1f bytes\n",
        dt, at, dtc, atc, dc, ac, du, au)

# one callback operation, called as the driver calls it: on the kept callback, with the kept view
println("\nOne call in a loop (10^6 calls, best of five, typed caller):")
pr = TDE.ODEProblem(osc2!, U0, TS, PV)
integ = ODECore.tsit5_init(pr, pr.u0, pr.tspan, pr.p, Any[TDE.DiscreteCallback(c1, a0), TDE.DiscreteCallback(c2, a0)])
const IV = Dynamic{IntegratorView{Vector{Float64}, Float64, Vector{Float64}}}
iv = IV(integ)
function loop_cond(cb, u, t, iv, n)
    k = 0
    for _ in 1:n
        k += ODECore.condition(cb, u, t, iv)
    end
    return k
end
function loop_field(iv, n)
    s = 0.0
    for _ in 1:n
        s += iv.p[1]
    end
    return s
end
function loop_closure(f, u, t, iv, n)
    k = 0
    for _ in 1:n
        k += f(u, t, iv)
    end
    return k
end
function timeit(lbl, f)
    f(); best = minimum(@elapsed(f()) for _ in 1:5); al = @allocated f()
    @printf("  %-70s %7.2f ns  %6.1f bytes per call\n", lbl, best / 1e6 * 1e9, al / 1e6)
end
cb2 = integ.callbacks[2]
timeit("condition(kept FunctionCallback, u, t, view) (c2 reads integ.p)", () -> loop_cond(cb2, integ.u, integ.t, iv, 10^6))
timeit("the kept Callable alone: cb.cond(u, t, view) (as FunctionCallback's method calls it)", () -> loop_closure(getfield(TraitWorld.Base.inferencebarrier(cb2), :t).cond, integ.u, integ.t, iv, 10^6))
timeit("integ.p[1] on the view (a declared field of a Dynamic family member)", () -> loop_field(iv, 10^6))
timeit("the closure c2 called directly with the view", () -> loop_closure(c2, integ.u, integ.t, iv, 10^6))
println("RESULT check5", HOT ? " hot" : "", @sprintf(" per step: TDE no cb %.1f ns %.1f B; TDE two cb %.1f ns %.1f B; control no cb %.1f ns; control two cb %.1f ns %.1f B; PlainODE Vector{Any} two cb %.1f ns %.1f B",
        res["TDE, no callbacks"][1], res["TDE, no callbacks"][2], res["TDE, two callbacks (Dynamic closures)"][1], res["TDE, two callbacks (Dynamic closures)"][2], res["control: PlainODE typed, no callbacks"][1],
        res["control: PlainODE typed, two callbacks"][1], res["control: PlainODE typed, two callbacks"][2], res["PlainODE Vector{Any}, two callbacks"][1], res["PlainODE Vector{Any}, two callbacks"][2]))
footer()
