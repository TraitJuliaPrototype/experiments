# project: TraitWorld
# Gate (compiler §5.5, §7.4; E-543): `@implement Callable T` declares `T` a member of every `Callable{A, S}`, an
# entry at instances of its own variables. Its walk reaches a method at `Callable{Tuple{Int}, Int}`, which that
# entry meets: the call compiled before the membership, and the dispatch cache, select the method at `Callable`
# once `T` joins, and the method at `Any` once it is taken back. Found by the set-folds report's library mode. A
# candidate for `gates/`; fails on `next` 2ddbe12394.
#     julia --project=TraitWorld n47_callable_every_instance.jl
using TraitWorld
struct S47 end
(s::S47)(x::Int) = x
const B = Core.Callable{Tuple{Int}, Int}
g(::Any) = :Any
g(::B) = :B
q(x) = g(x)
dyn(x) = g(Base.inferencebarrier(x))
@assert q(S47()) === :Any && dyn(S47()) === :Any && !(S47() isa B)
TraitWorld.@implement Core.Callable S47
@assert S47() isa B
@assert q(S47()) === :B "a call compiled before the membership: $(q(S47()))"
@assert dyn(S47()) === :B "the dispatch cache: $(dyn(S47()))"
TraitWorld.delete_membership(Core.Callable, S47)
@assert q(S47()) === :Any && dyn(S47()) === :Any "taken back: $((q(S47()), dyn(S47())))"
println("n47_callable_every_instance: OK")
