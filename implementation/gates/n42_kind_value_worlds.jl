# Gate (compiler §4.10, §5.3; C-165, E-543): a kind of type object meets a set where the set takes a type value, so
# a match at a kind, or its absence, holds only in the worlds where the set's entries for type values are as they
# are in the world asked. A call `g(S)` compiled at the kind (`q(::Type)`) after `Type{S}`'s membership in `X` is
# taken back must not run in the worlds where the membership held; a lookup at `Type{S}` made in the world before the
# membership must not leave a cache entry at the kind (`Tuple{typeof(g), Type}`) that answers in the worlds where it
# holds. A candidate for `gates/`; fails on `next` 2ddbe12394.
#     julia --project=experiments/implementation n42_kind_value_worlds.jl
using Traits
@trait X42
struct S42 end
struct T42 end
g(::Any) = :Any
g(::X42) = :X
q(x) = g(x)
r(x) = q(x)
const W = UInt[Base.get_world_counter()]
Traits.declare_membership(Type{S42}, X42, @__MODULE__)
push!(W, Base.get_world_counter())
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), Type{S42}, X42, @__MODULE__)
push!(W, Base.get_world_counter())
# compiled in the latest world, at the kind, then run in each world
@assert r(S42) === :Any
got = [Base.invoke_in_world(w, r, S42) for w in W]
@assert got == [:Any, :X, :Any] "a call at the kind across the worlds: $got"
# a lookup at a type value in the world before the membership, then in the world where it holds
function lookup(tt, w)
    ms = Base._methods_by_ftype(tt, -1, w)
    return [m.method.sig.parameters[2] for m in ms]
end
Traits.declare_membership(Type{T42}, X42, @__MODULE__)
w1 = Base.get_world_counter()
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), Type{T42}, X42, @__MODULE__)
tt = Tuple{typeof(g), Type{T42}}
@assert lookup(tt, W[1]) == [Any]
@assert lookup(tt, w1) == [X42] "the lookup at Type{T42} where the membership holds: $(lookup(tt, w1))"
println("n42_kind_value_worlds: OK")
