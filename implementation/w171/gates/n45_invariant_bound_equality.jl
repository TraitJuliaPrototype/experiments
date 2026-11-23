# Gate (compiler §4.5, §4.9, §4.4; C-163, E-543): inside an invariant parameter two types are equal where they are
# equal by their declared structure, in every world or in none. Two parameters whose variables' lower bounds differ
# only by a membership (`Ph{T} where T >: X` and `Ph{T} where T >: Union{X, S}`) are two types inside the parameter
# whether or not `S` is a member of `X`: `<:`, `==`, the intersection and `isa` agree, before the membership and
# after it. At the top, and for a variable bound outside the parameter (`Vector{<:X}`), a membership still counts.
# A candidate for `gates/`; fails on `next` 2ddbe12394 (`<:` turns true, `isa` stays false).
#     julia --project=experiments/implementation n45_invariant_bound_equality.jl
using Traits
@trait X45
struct S45 end
struct Ph45{T} end
const UXS = Union{X45, S45}
const A = Ph45{T} where T >: X45
const B = Ph45{T} where T >: UXS
const PA = Ph45{A}
const PB = Ph45{B}
check(tag) = begin
    @assert !(PA <: PB) "$tag: Ph{A} <: Ph{B}"
    @assert !(PB <: PA) "$tag: Ph{B} <: Ph{A}"
    @assert PA != PB "$tag: =="
    @assert typeintersect(PA, PB) === Union{} "$tag: the intersection"
    @assert !(Ph45{A}() isa PB) "$tag: isa"
end
check("before")
@assert !(A == B) && Vector{S45} <: Vector{<:UXS} && !(Vector{S45} <: Vector{<:X45})
Traits.declare_membership(S45, X45, @__MODULE__)
check("after the membership")
@assert A == B "at the top a membership counts"
@assert Vector{S45} <: Vector{<:X45} "a variable bound outside the parameter: a subtype question"
@assert Vector{Ph45{X45}} <: (Vector{Ph45{T}} where T >: S45) "an outer variable's lower bound inside the parameter: a subtype question"
println("n45_invariant_bound_equality: OK")
