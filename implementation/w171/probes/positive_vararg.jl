# W-171 (E-542): a positive through an entry at a Vararg tail, and through a declared supertype's parameter: folded
# after the membership, the membership taken back
#     julia --project=experiments/implementation positive_vararg.jl
using Traits
@trait X
struct S end
abstract type AP{T} end
struct P2{T} <: AP{T} end
const V1 = Tuple{Int, S, S}; const V2 = Tuple{Int, Vararg{X}}
const T1 = Tuple{S}; const T2 = Tuple{X}
qv() = V1 <: V2
qp() = P2{S} <: AP{<:X}
qt() = T1 <: T2
edges(f) = (mi = only(Base.specializations(only(methods(f)))); c = mi.cache; (Int(c.min_world), c.edges))
@implement X S
println("member: ", (qv(), qp(), qt()))
println("  qv ", edges(qv)); println("  qp ", edges(qp)); println("  qt ", edges(qt))
println("entries_for: ", ccall(:jl_membership_entries_for, Any, (Any, Any, UInt), V1, V2, Base.get_world_counter()),
        " ", ccall(:jl_membership_entries_for, Any, (Any, Any, UInt), P2{S}, AP{<:X}, Base.get_world_counter()))
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, X, @__MODULE__)
println("taken back: ", (qv(), qp(), qt()), " fresh ", (ccall(:jl_subtype, Cint, (Any, Any), V1, V2), ccall(:jl_subtype, Cint, (Any, Any), P2{S}, AP{<:X})))
