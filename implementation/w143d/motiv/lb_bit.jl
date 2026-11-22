# W-143d (E-540): does the bit "a set occurs in this type" (`DataType.has_open_set`, compiler §4.8) see a set
# that occurs only as a type variable's lower bound? Subtyping walks the bound, so a membership decides the
# answer there; a test that reads the bit alone would not see it.
#     julia --project=experiments/implementation lb_bit.jl          (the stub library)
using Traits
@trait LX
struct LM end
U = Union{LX, LM}                          # made before the membership: not simplified to LX
S1 = TypeVar(:S, LX, Any); A = UnionAll(S1, Ref{S1})      # Ref{S} where S >: LX
S2 = TypeVar(:S, U, Any);  B = UnionAll(S2, Ref{S2})      # Ref{S} where S >: Union{LX, LM}
bit(t) = ccall(:jl_has_open_set, Cint, (Any,), t)
println("bit: LX ", bit(LX), " | A ", bit(A), " | B ", bit(B), " | Vector{A} ", bit(Vector{A}), " | Ref{S1} free ", bit(Ref{S1}))
println("before the membership: A == B ", A == B, " | Vector{A} <: Vector{B} ", Vector{A} <: Vector{B},
        " | typeintersect(Vector{A}, Vector{B}) ", typeintersect(Vector{A}, Vector{B}))
@implement LX LM
println("after  the membership: A == B ", A == B, " | Vector{A} <: Vector{B} ", Vector{A} <: Vector{B},
        " | typeintersect(Vector{A}, Vector{B}) ", typeintersect(Vector{A}, Vector{B}))
# compiled code: a negative folded before the membership, about types whose bit is clear
@trait LY
struct LN end
const U2 = Union{LY, LN}
const A2 = let S = TypeVar(:S, LY, Any); UnionAll(S, Ref{S}) end
const B2 = let S = TypeVar(:S, U2, Any); UnionAll(S, Ref{S}) end
q() = Vector{A2} <: Vector{B2}
println("compiled before the membership: q() ", q(), " | folded: ", Base.infer_return_type(q, ()))
@implement LY LN
println("after the membership: q() ", q(), " | asked afresh ", Vector{A2} <: Vector{B2})
