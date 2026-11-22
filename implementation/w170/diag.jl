# W-170 (E-538): the per-call costs of E-537's classes (`w169/stiff/diag.jl` (a), the same loops), before and after
# each candidate, on julia-next with a setting's environment:
#     julia --project=<env> diag.jl
# Per call, the minimum of 7 runs of 10^5 calls (10^4 for the factorization):
#   the box's call at one signature and at either signature of an intersection; the wrapper; the function itself;
#   a declared field read through a box (`Dynamic{IntegratorView}`, ODECore's) at a constant name, at a name not
#   constant, a write; ODECore's `_sync_in!` (the callbacks' adapter, five reads and five writes);
#   `linfactor` on a field typed `LinearSolver` against typed `DenseLU`.
using TraitWorld, TraitDifferentialEquations, LinearAlgebra
const ODE = TraitDifferentialEquations
const C = ODE.ODECore
LinearAlgebra.BLAS.set_num_threads(1)
const FD8 = C.FDual{8}
triv!(du, u, p, t) = (@inbounds du[1] = u[1]; nothing)
const pf = C.PartialFn(triv!, nothing)
const box1 = Dynamic{Callable{C.CoreRHSSig{Float64},Nothing}}(pf)
const box2 = Dynamic{All{Callable{C.CoreRHSSig{Float64},Nothing},Callable{C.CoreDualSig{8},Nothing}}}(pf)
const wrap = compiled_for(pf)
const du, u = zeros(4), ones(4)
const dud, ud = zeros(FD8, 4), ones(FD8, 4)
@noinline callmany(f, a, b, n) = (for _ in 1:n; f(a, b, 1.0); end; nothing)
function per_call(label, f, a, b; n = 10^5)
    callmany(f, a, b, 10)
    best = minimum(1:7) do _
        t = time_ns(); callmany(f, a, b, n); (time_ns() - t) / n
    end
    println("A ", rpad(label, 64), round(best; digits = 2), " ns a call")
end
per_call("the function itself (PartialFn), Float64", pf, du, u)
per_call("the wrapper compiled_for, Float64", wrap, du, u)
per_call("a box at one signature, Float64", box1, du, u)
per_call("a box of All{rhs, duals}, at its first signature (Float64)", box2, du, u)
per_call("a box of All{rhs, duals}, at its second signature (duals)", box2, dud, ud)
per_call("the function itself, duals", pf, dud, ud)

# declared fields through a box: ODECore's ParamIntegrator boxed at IntegratorView, as a callback sees it
const U, P = Vector{Float64}, Vector{Float64}
const PI = C.param_integrator(U, [1.0, 2.0], 0.0, nothing, nothing, false)
const IV = Dynamic{C.IntegratorView{U,Float64,P}}(PI)
const NAMES = Symbol[:p, :u, :t]
@noinline readp(d, n) = (s = 0.0; for _ in 1:n; s += @inbounds d.p[1]; end; s)
@noinline readt(d, n) = (s = 0.0; for _ in 1:n; s += d.t; end; s)
@noinline readat(d, names, n) = (k = 0; for i in 1:n; k += length(getproperty(d, @inbounds names[1 + (i & 1)])::Vector{Float64}); end; k)
@noinline writem(d, n) = (for i in 1:n; d.u_modified = isodd(i); end; nothing)
function per_n(label, f, args...; n = 10^5)
    f(args..., 10)
    best = minimum(1:7) do _
        t = time_ns(); f(args..., n); (time_ns() - t) / n
    end
    println("A ", rpad(label, 64), round(best; digits = 2), " ns a call")
end
per_n("a declared field read through a box, d.p (constant name)", readp, IV)
per_n("a declared field read through a box, d.t (constant name)", readt, IV)
per_n("a declared field read through a box, at a name not constant", readat, IV, NAMES)
per_n("a declared field written through a box, d.u_modified = b", writem, IV)
# the callbacks' adapter `_sync_in!` (five reads through a box of StepView, five writes of the integrator's own
# fields), on a StepView member of this file's (a solver's integrator is reached only inside a solve)
mutable struct SV; u::Vector{Float64}; t::Float64; dt::Float64; u_modified::Bool; terminated::Bool; end
@implement C.StepView{Vector{Float64},Float64} SV begin
    C.step_tstop!(i, τ) = nothing
    C.step_terminate!(i) = nothing
    C.step_interp!(i, out, τ) = nothing
    C.step_dt_reset!(i) = nothing
end
const SVB = Dynamic{C.StepView{Vector{Float64},Float64}}(SV(zeros(2), 0.5, 0.1, false, false))
@noinline syncmany(pi, sv, n) = (for _ in 1:n; C._sync_in!(pi, sv); end; nothing)
per_n("ODECore's _sync_in! (the callbacks' adapter), a box of StepView", syncmany, PI, SVB)

struct Holder; ls::C.LinearSolver; end          # as Rodas5Integrator's field `ls::LinearSolver`
struct HolderC{L}; ls::L; end                   # the field typed by its parameter
const W0 = rand(20, 20) + 20I
const Wk = copy(W0)
@noinline fact(h, W) = (copyto!(W, W0); C.linfactor(h.ls, W))
@noinline factsolve(h, W, x, b) = (copyto!(W, W0); F = C.linfactor(h.ls, W); for _ in 1:8; ldiv!(x, F, b); end; nothing)
function per(label, f, args...; n = 10^4)
    f(args...)
    best = minimum(1:7) do _
        t = time_ns(); for _ in 1:n; f(args...); end; (time_ns() - t) / n
    end
    println("A ", rpad(label, 64), round(best; digits = 1), " ns a call")
end
x, b = zeros(20), rand(20)
per("linfactor, the field typed LinearSolver (copy and LU)", fact, Holder(C.DenseLU()), Wk)
per("linfactor, the field typed DenseLU (copy and LU)", fact, HolderC(C.DenseLU()), Wk)
per("linfactor and 8 ldiv!, the field typed LinearSolver", factsolve, Holder(C.DenseLU()), Wk, x, b)
per("linfactor and 8 ldiv!, the field typed DenseLU", factsolve, HolderC(C.DenseLU()), Wk, x, b)
