# Gate (compiler §5.5, C-88 (c); E-544): the walks over a signature stop at depth 8 (a union's nesting counts none).
# A method with the set nine tuples deep is replayed at its own signature by every membership, and so is a method
# whose lower bound holds the member below its top (`T >: Tuple{S}`): code compiled before the membership sees the
# method after it. A candidate for `gates/`; fails on `next` 3e9c193025.
#     julia --project=experiments/implementation n53_walk_past_depth.jl
using Traits
@trait X
struct S end
struct Ph{T} end
nest(T, n) = n == 0 ? T : Tuple{nest(T, n - 1)}
nestv(x, n) = n == 0 ? x : (nestv(x, n - 1),)
const DX = nest(X, 9)
const DS = nest(S, 9)
g(::Any) = :any
g(::DX) = :deep
h(::Any) = :any
h(::Ph{T}) where T >: Tuple{S} = :lb
cg(x::DS) = g(x)
ch(x::Ph{Tuple{X}}) = h(x)
v = nestv(S(), 9)
@assert cg(v) === :any && ch(Ph{Tuple{X}}()) === :any
@implement X S
@assert cg(v) === :deep "the set nine tuples deep: $(cg(v))"
@assert ch(Ph{Tuple{X}}()) === :lb "a member below a lower bound's top: $(ch(Ph{Tuple{X}}()))"
println("n53_walk_past_depth: OK")
