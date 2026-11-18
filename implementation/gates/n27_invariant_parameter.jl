# Gate (W-140; compiler §5.5): a membership does not replay a method that names the set only as an
# invariant parameter (`Vector{X}`): whoever joins `X`, only `Vector{X}` is under it, so no instance and
# no caller is invalidated (E-358's composition: a core's loop over a `Vector{Shape}` and each new
# member). Where the set bounds a variable (`Vector{<:X}`) the membership changes dispatch and reaches
# the caller.
using Traits
include("util.jl")
valid(f) = [c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)]

@trait X
struct A end
struct B end
@implement X A
tot(v::Vector{X}) = length(v)
calltot() = tot(X[A()])
@assert calltot() == 1
held = vcat(valid(tot), valid(calltot))
@assert !isempty(held)
@implement X B
@assert all(c -> c.max_world == typemax(UInt), held) "a new member invalidates nothing at Vector{X}"
@assert calltot() == 1

# the set as a variable's bound: Vector{B2} joins the method's types with the membership
struct B2 end
g(v::Vector{<:X}) = :members
g(v) = :any
callg(v::Vector{B2}) = g(v)
@assert callg(B2[]) === :any
cig = only(valid(callg))
@implement X B2
@assert cig.max_world != typemax(UInt) "the membership reaches the caller at Vector{B2}"
@assert callg(B2[]) === :members
println("n27_invariant_parameter: OK")
