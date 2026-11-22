# Gate (compiler §4.7, §4.8; E-542): where no membership can change an answer about a set, a negative folds with no
# edge (`jl_could_join` answers 0); everywhere else it folds only with its edge, or not at all. Three shapes in which a
# membership does change the answer: two tuples of different lengths (a Vararg tail), `Type{S}` against `Type{<:X}`,
# a parameter reached through a declared supertype. Code compiled before the membership answers as asked afresh after
# it; a typeassert compiled before it does not run into `unreachable` (the process stops on a build without the rule).
# The mirror: a positive about such a shape folds only through the entry, with its edge (`jl_subtype_via_membership`
# answers 1): compiled while the membership holds, the code ends when it is taken back.
# A candidate for `gates/`; fails on `next` dd42dc8c3f, passes on `w171`.
#     julia --project=experiments/implementation n39_could_join_shapes.jl
using Traits
@trait X
struct S end
abstract type AP{T} end
struct P{T} <: AP{T} end
const V1 = Tuple{Int, S, S}
const V2 = Tuple{Int, Vararg{X}}
const TX = Type{<:X}
const PX = AP{<:X}
qv() = V1 <: V2
qt() = S isa TX
qp() = P{S} <: PX
qa(x) = (x::V2; true)
call(f, a...) = try f(a...) catch e; nameof(typeof(e)) end
@assert (qv(), qt(), qp(), call(qa, (1, S(), S()))) == (false, false, false, :TypeError)
@implement X S
fresh = (Base.inferencebarrier(V1) <: Base.inferencebarrier(V2), Core.isa(Base.inferencebarrier(S), Base.inferencebarrier(TX)),
         Base.inferencebarrier(P{S}) <: Base.inferencebarrier(PX))
@assert fresh == (true, true, true)
@assert (qv(), qt(), qp()) == fresh "compiled before the membership: $((qv(), qt(), qp()))"
@assert call(qa, (1, S(), S())) === true
pv() = V1 <: V2
pp() = P{S} <: PX
@assert (pv(), pp()) == (true, true)
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, X, @__MODULE__)
@assert (pv(), pp()) == (false, false) "positives compiled while the membership held, taken back: $((pv(), pp()))"
println("n39_could_join_shapes: OK")
