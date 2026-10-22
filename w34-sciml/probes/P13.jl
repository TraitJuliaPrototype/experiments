# P13: form A's per-call cost: an operation with abstract buffers on a Dynamic value
# (`rhs!(f::ODERHS, du::AbstractVector, u::AbstractVector, p, t)::Nothing` under
# @default_with_dynamic_self, the model kept at a bounded struct parameter), at Float64 and at
# ForwardDiff's duals, for a concrete model declared by the one-line form and for a family member.
# Nanoseconds and bytes per call, a hand loop after warm-up (best of 5), and the plain call as the
# baseline. A quick regression check, not a measurement.
# Reference: traits §6.8 (an operation on a Dynamic value: the fastest path for the first four
# implementations declared, else one lookup and an indirect call), lowering §4.6 and L-37 (a family
# member's conformance through the registry at each call), evidence §2 (2.5–18.5 ns).
include("common.jl")
using ForwardDiff
header("P13", "form A: rhs!(f::ODERHS, du::AbstractVector, u::AbstractVector, p, t)::Nothing on a Dynamic value; concrete model and family member; Float64 and duals")

edef = caught(() -> toplevel(quote
    @trait_module module FormA
    using TraitWorld
    @trait ODERHS begin
        @default_with_dynamic_self
        rhs!(f::ODERHS, du::AbstractVector, u::AbstractVector, p, t)::Nothing
    end
    struct Prob{F <: ODERHS}
        f::F
    end
    "The solver's inner call, `n` times: an operation on the kept Dynamic value."
    function loop!(prob::Prob, du::AbstractVector, u::AbstractVector, p, t, n::Int)
        for _ in 1:n
            rhs!(prob.f, du, u, p, t)
        end
        return nothing
    end
    end
end))
println("trait module: ", errtext(edef))
edecl = caught(() -> toplevel(quote
    module Models
    using TraitWorld
    using ..FormA
    @inline function lorenz!(du, u, p, s)
        du[1] = s * p[1] * (u[2] - u[1])
        du[2] = u[1] * (p[2] - u[3]) - u[2]
        du[3] = u[1] * u[2] - p[3] * u[3]
        return nothing
    end
    struct Lorenz; s::Float64; end                       # a concrete model: the one-line form, declared first
    FormA.rhs!(m::Lorenz, du::AbstractVector, u::AbstractVector, p, t) = lorenz!(du, u, p, m.s)
    @implement FormA.ODERHS Lorenz
    struct ChainModel{G}; g::G; end                      # a family member (G: a graph's type)
    FormA.rhs!(m::ChainModel, du::AbstractVector, u::AbstractVector, p, t) = lorenz!(du, u, p, Float64(length(m.g)))
    @implement FormA.ODERHS ChainModel{G} where {G}
    end
end))
println("models (Lorenz declared first, then the family ChainModel{G}): ", errtext(edecl))

const P = [10.0, 28.0, 8 / 3]
const D3 = ForwardDiff.Dual{Nothing, Float64, 3}
mkdual(x) = [D3(x[i], ForwardDiff.Partials(ntuple(k -> k == i ? 1.0 : 0.0, 3))) for i in 1:3]
m1 = Models.Lorenz(1.0)
m2 = Models.ChainModel([1])
prob1 = FormA.Prob(m1)
prob2 = FormA.Prob(m2)
println("Prob(Lorenz) is ", typeof(prob1), "; Prob(ChainModel{Vector{Int}}) is ", typeof(prob2))
u64 = [1.0, 0.5, 0.2]; du64 = zeros(3)
ud = mkdual(u64); dud = zeros(D3, 3)

plainloop!(m, du, u, p, t, n) = (for _ in 1:n; FormA.rhs!(m, du, u, p, t); end; nothing)
const N = 1_000_000
results = Dict{String,Any}()
for (lbl, f) in [
        ("plain call, Lorenz, Float64", n -> plainloop!(m1, du64, u64, P, 0.0, n)),
        ("form A, Lorenz (concrete), Float64", n -> FormA.loop!(prob1, du64, u64, P, 0.0, n)),
        ("form A, ChainModel (family member), Float64", n -> FormA.loop!(prob2, du64, u64, P, 0.0, n)),
        ("plain call, Lorenz, duals", n -> plainloop!(m1, dud, ud, P, 0.0, n)),
        ("form A, Lorenz (concrete), duals", n -> FormA.loop!(prob1, dud, ud, P, 0.0, n)),
        ("form A, ChainModel (family member), duals", n -> FormA.loop!(prob2, dud, ud, P, 0.0, n)),
    ]
    r = try percall(f, N) catch e; (ns = NaN, bytes = NaN, err = inner_err(e)) end
    results[lbl] = r
    @printf("  %-46s %8.2f ns/call %8.1f bytes/call%s\n", lbl, r.ns, r.bytes, haskey(r, :err) ? "  " * errtext(r.err; lines = 2) : "")
end
println("check of the results: du64 = ", du64, " (Float64), dud[1] = ", dud[1])
println()

check("the trait module and the models are accepted", edef === nothing && edecl === nothing, "$(errtext(edef)); $(errtext(edecl))")
check("both models give Prob{Dynamic{ODERHS}}", prob1 isa FormA.Prob{Dynamic{FormA.ODERHS}} && prob2 isa FormA.Prob{Dynamic{FormA.ODERHS}}, "$(typeof(prob1)), $(typeof(prob2))")
for k in ("form A, Lorenz (concrete), Float64", "form A, Lorenz (concrete), duals")
    check("$k: no allocation per call (under 0.5 bytes per call: the harness's one dynamic call into the loop is spread over N)", results[k].bytes < 0.5, @sprintf("%.6f bytes/call", results[k].bytes))
end
for k in ("form A, ChainModel (family member), Float64", "form A, ChainModel (family member), duals")
    r = results[k]
    # reported against the prediction; the reference's L-37 states the per-call registry path
    println("  [info] $k: ", @sprintf("%.2f ns, %.1f bytes per call", r.ns, r.bytes), " (prediction and L-37: allocates)")
end
finish("P13";
    predicted = "the concrete model: no allocation; the family member: allocates (open issue 49)",
    reference = "traits §6.8: one lookup and an indirect call, no allocation stated; lowering L-37: a family member's conformance through the registry at each typed call (304 bytes); evidence §2: 2.5–18.5 ns",
    prediction = "see the numbers above")
