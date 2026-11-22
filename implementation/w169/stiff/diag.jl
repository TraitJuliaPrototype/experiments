# E-537 §3, §5: the profile's dispatch classes read up close, on the head (julia-next, the round's H environment).
#     julia diag.jl
# (a) per call, the minimum of 7 runs of 10^5 calls each: the box's call at one signature and at the second signature
#     of an intersection (the right-hand side boxed at Float64 and at the duals), the wrapper; `linfactor` on a field
#     typed `LinearSolver` and on the concrete solver; `ldiv!` on a value typed `Solvable{Float64}` and on the LU.
# (b) the stacks of the samples of POLLU with callbacks (the port, compiled) whose leaf region reads a declared field
#     (`declared_field_in`) or dispatches at rodas5.jl:204, the first 8 Julia frames, by count.
using TraitWorld, TraitDifferentialEquations, LinearAlgebra, Profile
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
    println("A ", rpad(label, 60), round(best; digits = 2), " ns a call")
end
per_call("the function itself (PartialFn), Float64", pf, du, u)
per_call("the wrapper compiled_for, Float64", wrap, du, u)
per_call("a box at one signature, Float64", box1, du, u)
per_call("a box of All{rhs, duals}, at its first signature (Float64)", box2, du, u)
per_call("a box of All{rhs, duals}, at its second signature (duals)", box2, dud, ud)
per_call("the function itself, duals", pf, dud, ud)

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
    println("A ", rpad(label, 60), round(best; digits = 1), " ns a call")
end
x, b = zeros(20), rand(20)
per("linfactor, the field typed LinearSolver (copy and LU)", fact, Holder(C.DenseLU()), Wk)
per("linfactor, the field typed DenseLU (copy and LU)", fact, HolderC(C.DenseLU()), Wk)
per("linfactor and 8 ldiv!, the field typed LinearSolver", factsolve, Holder(C.DenseLU()), Wk, x, b)
per("linfactor and 8 ldiv!, the field typed DenseLU", factsolve, HolderC(C.DenseLU()), Wk, x, b)
println("A the inferred result of linfactor at the field typed LinearSolver: ",
        Base.return_types(fact, (Holder, Matrix{Float64}))[1])

# (b)
include(joinpath(@__DIR__, "problems.jl"))
const PRB = ODE.ODEProblem(compiled_for(pollu!), pollu_u0(), POLLU_TSPAN, PK)
const CBS = ODE.DiscreteCallback(pollu_cond, pollu_affect!)
const SAVEAT = collect(range(0.0, 60.0; length = 11))
one_solve() = (reset_pulse!(3.0); ODE.solve(PRB, ODE.Rodas5(); abstol = 1e-8, reltol = 1e-6, saveat = SAVEAT, callback = CBS))
one_solve(); one_solve()
Profile.init(n = 10^7, delay = 0.0005)
t0 = time(); Profile.@profile while time() - t0 < 6; one_solve(); end
data = Profile.fetch(include_meta = false)
lk = Dict{UInt64,Vector{Base.StackTraces.StackFrame}}()
fr(ip) = get!(() -> Profile.lookup(ip), lk, UInt64(ip))
function split_samples(data)
    samples = Vector{Vector{Base.StackTraces.StackFrame}}(); cur = Base.StackTraces.StackFrame[]
    for ip in data
        if ip == 0; isempty(cur) || push!(samples, cur); cur = Base.StackTraces.StackFrame[]; else append!(cur, fr(ip)); end
    end
    return samples
end
samples = split_samples(data)
samples = filter(s -> any(f -> String(f.func) == "one_solve", s), samples)
N = length(samples)
for (what, pick) in (("declared_field_in", s -> any(f -> String(f.func) == "declared_field_in", s)),
                     ("rodas5.jl:204, C frames at the leaf", s -> (i = findfirst(f -> !f.from_c, s); i !== nothing && i > 1 &&
                        basename(String(s[i].file)) == "rodas5.jl" && s[i].line == 204)))
    sel = filter(pick, samples)
    println("B $what: ", length(sel), " of ", N, " samples (", round(100length(sel) / N; digits = 1), " %)")
    chains = Dict{String,Int}()
    for s in sel
        c = what == "declared_field_in" ?
            join(["$(f.func) $(basename(String(f.file))):$(f.line)" for f in filter(f -> !f.from_c, s)][1:min(8, end)], " < ") :
            join([String(f.func) for f in s if f.from_c][1:min(6, end)], " < ")
        chains[c] = get(chains, c, 0) + 1
    end
    for (c, k) in first(sort(collect(chains); by = kv -> -kv[2]), 8)
        println("B   ", lpad(k, 5), "  ", c)
    end
end
