# E-444 (W-160 (c); compiler §5.5, C-88 (c)): a membership replays a method that names the set in a
# bound the signature sets (`Box{<:X}`, the kept forms `Union{Dynamic{<:X}, Wrap{<:X}}`), or in several
# places below a position's top, at the method's own signature. The callers at the new member are
# reached (a `Box{Union{Old, New}}` too); the method's own instances at the other members and their
# callers are kept, and the walk logs no `jl_method_table_disable` for the method.
# Run: <julia> --startup-file=no --project=experiments/unification experiments/unification/w160/check/kept_own.jl
using Traits
include(joinpath(@__DIR__, "..", "..", "gates", "util.jl"))
valid(f) = [c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)]
kept(cis) = all(c -> c.max_world == typemax(UInt), cis)

@trait X
struct Old end
struct New end
struct Box{T}; x::T; end
struct Wrap{T}; x::T; end
@implement X Old

# a bound the signature sets
g1(b::Box{<:X}) = :members
g1(b) = :any
c1o(b::Box{Old}) = g1(b); c1n(b::Box{New}) = g1(b); c1u(b::Box{Union{Old, New}}) = g1(b)
# the kept forms, as the library makes them (the box is Core's)
const Kept = Union{Core.Dynamic{<:X}, Wrap{<:X}}
k(x::Kept) = :kept
k(x) = :any
cko(d::Core.Dynamic{X}) = k(d); ckw(w::Wrap{Old}) = k(w); ckn(w::Wrap{New}) = k(w)
# the set in two places
g7(a::Box{<:X}, b::Box{<:X}) = :members
g7(a, b) = :any
c7o(a::Box{Old}, b::Box{Old}) = g7(a, b); c7a(a::Box{New}, b::Box{Old}) = g7(a, b)
dyn(f, x) = Base.inferencebarrier(f)(Base.inferencebarrier(x))

o, n = Old(), New()
d = Core.Dynamic{X}(o)
@assert c1o(Box(o)) === :members && c1n(Box(n)) === :any && c1u(Box{Union{Old, New}}(o)) === :any
@assert cko(d) === :kept && ckw(Wrap(o)) === :kept && ckn(Wrap(n)) === :any
@assert c7o(Box(o), Box(o)) === :members && c7a(Box(n), Box(o)) === :any
@assert dyn(k, d) === :kept && dyn(g1, Box(o)) === :members
own = [c for g in (g1, k, g7) for c in valid(g) if c.def.def.sig != Tuple{typeof(g), Any} &&
                                                   c.def.def.sig != Tuple{typeof(g), Any, Any}]
old = reduce(vcat, valid.((c1o, cko, ckw, c7o)))
new = reduce(vcat, valid.((c1n, c1u, ckn, c7a)))
@assert length(own) >= 4 "the methods' own instances: $(length(own))"
@assert length(old) == 4 && length(new) == 4

log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
@implement X New
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)

@assert c1n(Box(n)) === :members && c1u(Box{Union{Old, New}}(o)) === :members "a bound the signature sets, a union of members under it"
@assert ckn(Wrap(n)) === :kept && dyn(k, Wrap(n)) === :kept "the kept forms at the new member"
@assert c7a(Box(n), Box(o)) === :members "the set in two places"
@assert all(c -> c.max_world != typemax(UInt), new) "the membership reaches the callers at the new member"
@assert kept(own) "the methods' own instances are kept: $(count(c -> c.max_world != typemax(UInt), own)) of $(length(own)) ended"
@assert kept(old) "the callers at the other members are kept: $(count(c -> c.max_world != typemax(UInt), old)) of $(length(old)) ended"
disabled = [log[i-1] for i in 2:length(log) if log[i] == "jl_method_table_disable"]
@assert isempty(disabled) "the walk took the conservative path: $disabled"
@assert c1o(Box(o)) === :members && cko(d) === :kept && c7o(Box(o), Box(o)) === :members
println("kept_own: OK (own instances kept: $(length(own)); callers kept: $(length(old)); reached: $(length(new)))")
