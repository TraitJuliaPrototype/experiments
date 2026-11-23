# Gate (compiler §5.5, §5.3; C-162, E-543): a method that names the member in a type variable's lower bound
# (`h(::Ph{T}) where T >: S`) is selected, once `S` joins `X`, at a call type that names the set (`Ph{X}`). A
# membership invalidates as a method does: declared, taken back, through a path of two, the callers' code
# (`hasmethod`, a call, `applicable`) and the dispatch caches follow, and code compiled in one world does not run
# in a world where the selection differs. A candidate for `gates/`; fails on `next` 2ddbe12394.
#     julia --project=experiments/implementation n43_lower_bound_replay.jl
using Traits
@trait X43
@trait Y43
struct S43 end
struct Ph43{T} end
const B = Ph43{T} where T >: S43
h(::B) = :hB
g(::Any) = :Any
g(::B) = :B
hm() = hasmethod(h, Tuple{Ph43{X43}})
d(x) = g(x)
ap(x) = applicable(h, x)
const v = Ph43{X43}()
dyn(x) = g(Base.inferencebarrier(x))
d2(x) = g(x)                                   # first compiled after the taking back
hm2() = hasmethod(h, Tuple{Ph43{X43}})
@assert hm() === false && d(v) === :Any && ap(v) === false && dyn(v) === :Any
const W = UInt[Base.get_world_counter()]
Traits.declare_membership(S43, X43, @__MODULE__)
push!(W, Base.get_world_counter())
@assert hm() === true "hasmethod compiled before the membership: $(hm())"
@assert d(v) === :B "a call compiled before the membership: $(d(v))"
@assert ap(v) === true "applicable compiled before the membership"
@assert dyn(v) === :B "the dispatch cache: $(dyn(v))"
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S43, X43, @__MODULE__)
push!(W, Base.get_world_counter())
@assert hm() === false && d(v) === :Any && ap(v) === false && dyn(v) === :Any "taken back: $((hm(), d(v), ap(v), dyn(v)))"
# compiled in the latest world, run in each world
@assert d2(v) === :Any && hm2() === false
@assert [Base.invoke_in_world(w, d2, v) for w in W] == [:Any, :B, :Any] "a call across the worlds"
@assert [Base.invoke_in_world(w, hm2) for w in W] == [false, true, false] "hasmethod across the worlds"
# a path of two memberships: S43 in Y43, then Y43 in X43
Traits.declare_membership(S43, Y43, @__MODULE__)
@assert hm() === false && d(v) === :Any
Traits.declare_membership(Y43, X43, @__MODULE__)
@assert hm() === true && d(v) === :B && dyn(v) === :B "through a path: $((hm(), d(v), dyn(v)))"
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S43, Y43, @__MODULE__)
@assert hm() === false && d(v) === :Any && dyn(v) === :Any "the path's first link taken back: $((hm(), d(v), dyn(v)))"
println("n43_lower_bound_replay: OK")
