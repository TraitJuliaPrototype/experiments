# Gate (W-146 (4); compiler §5.5, C-88 (c)): a membership replays a method that names the set below a
# position's top with the member in the set's place, where one signature says what the membership
# adds: under a union, in a tuple's component, in an intersection, and under the bound that a type
# declares for its own parameter (`struct Cell{C<:X}`: no `Cell` at the member could be made before).
# It reaches the callers at the new member and keeps every instance and caller at the other members.
# A bound that the signature sets (`Box{<:X}`: `Box{Union{Old, New}}` was made before) and the set in
# several places below a position's top (two parameters) replay at the method's own signature (W-160,
# E-444); a `Vararg` stays on the conservative path. All are correct.
using Traits
const All = Core.All
include("util.jl")
valid(f) = [c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)]
kept(cis) = all(c -> c.max_world == typemax(UInt), cis)

@trait X
@trait Y
struct Old end
struct New end
struct Box{T}; x::T; end
@implement X Old
@implement Y Old
@implement Y New

# a variable's bound inside a parameter
g1(b::Box{<:X}) = :members
g1(b) = :any
c1o(b::Box{Old}) = g1(b); c1n(b::Box{New}) = g1(b); c1u(b::Box{Union{Old, New}}) = g1(b)
# the type itself under such a bound
g2(::Type{<:Box{<:X}}) = :members
g2(::Type) = :any
c2o() = g2(Box{Old}); c2n() = g2(Box{New})
# a union
g3(x::Union{X, Nothing}) = :members
g3(x) = :any
c3o(x::Old) = g3(x); c3n(x::New) = g3(x)
# a Vararg
g4(xs::X...) = :members
g4(xs...) = :any
c4o(x::Old) = g4(x, x); c4n(x::New) = g4(x, x); c4m(x::New, y::Old) = g4(x, y)
# a tuple's component
g5(t::Tuple{X, Int}) = :members
g5(t) = :any
c5o(x::Old) = g5((x, 1)); c5n(x::New) = g5((x, 1))
# an intersection
g6(x::All{X, Y}) = :members
g6(x) = :any
c6o(x::Old) = g6(x); c6n(x::New) = g6(x)
# the set in two places: the member in either
g7(a::Box{<:X}, b::Box{<:X}) = :members
g7(a, b) = :any
c7a(a::Box{New}, b::Box{Old}) = g7(a, b); c7b(a::Box{Old}, b::Box{New}) = g7(a, b)
# a struct whose parameter is bounded by the set: no type of it at the member exists before
struct Cell{C<:X}; c::C; end
size1(v::Cell) = 1
size1(v) = 0
kind(::Type{<:Cell}) = :cell
kind(::Type) = :any
c8o(v::Cell{Old}) = size1(v)
c8a(@nospecialize(v::Cell)) = size1(v)            # a caller at the type without its parameter
c9o() = kind(Cell{Old})
dyn(f, x) = Base.inferencebarrier(f)(Base.inferencebarrier(x))     # a dynamic call

o, n = Old(), New()
@assert c1o(Box(o)) === :members && c1n(Box(n)) === :any && c1u(Box{Union{Old, New}}(o)) === :any
@assert c2o() === :members && c2n() === :any
@assert c3o(o) === :members && c3n(n) === :any
@assert c4o(o) === :members && c4n(n) === :any && c4m(n, o) === :any
@assert c5o(o) === :members && c5n(n) === :any
@assert c6o(o) === :members && c6n(n) === :any
@assert c7a(Box(n), Box(o)) === :any && c7b(Box(o), Box(n)) === :any
@assert c8o(Cell(o)) == 1 && c8a(Cell(o)) == 1 && c9o() === :cell
@assert dyn(g1, Box(n)) === :any && dyn(g3, n) === :any && dyn(g4, n) === :any && dyn(g6, n) === :any
old = reduce(vcat, valid.((c3o, c5o, c6o, c8o, c8a, c9o, size1, kind)))
olds = [c for g in (g3, g5, g6) for c in valid(g) if occursin("Old", string(c.def.specTypes))]
new = reduce(vcat, valid.((c1n, c1u, c2n, c3n, c4n, c5n, c6n, c7a, c7b)))
@assert length(old) >= 8 && !isempty(olds) && length(new) == 9

@implement X New

@assert c1n(Box(n)) === :members && c1u(Box{Union{Old, New}}(o)) === :members "a bound the signature sets, a union of members under it"
@assert c2n() === :members "a type under such a bound"
@assert c3n(n) === :members "a union"
@assert c4n(n) === :members && c4m(n, o) === :members "a Vararg, the member beside another"
@assert c5n(n) === :members "a tuple's component"
@assert c6n(n) === :members "an intersection"
@assert c7a(Box(n), Box(o)) === :members && c7b(Box(o), Box(n)) === :members "the set in two places"
@assert dyn(g1, Box(n)) === :members && dyn(g3, n) === :members && dyn(g4, n) === :members && dyn(g6, n) === :members "dynamic calls"
@assert all(c -> c.max_world != typemax(UInt), new) "the membership reaches the callers at the new member"
@assert kept(old) "callers at the other members are kept: $(count(c -> c.max_world != typemax(UInt), old)) of $(length(old)) ended"
@assert kept(olds) "the methods' instances at the other members are kept"
@assert c1o(Box(o)) === :members && c8o(Cell(o)) == 1 && size1(Cell(n)) == 1 && c8a(Cell(n)) == 1
@assert kind(Cell{New}) === :cell && dyn(kind, Cell{New}) === :cell && dyn(size1, Cell(n)) == 1 "a type's declared bound"
println("n32_nested_set: OK")
