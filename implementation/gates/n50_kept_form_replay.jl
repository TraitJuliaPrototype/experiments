# project: TraitWorld
# Gate (compiler §5.5; E-544, C-167): a membership of `S` in `X` also puts the member's kept forms under `X` (the
# library's pattern `Compiled{Z} where Z <: X`): the walk replays a method at `X` at such a pattern, so code that folded
# `hasmethod(h, Tuple{Compiled{S}})` to `false` and a call at a wrapper compiled before the membership see the method.
# Taken back, the answers go back. A candidate for `gates/`; fails on `next` 3e9c193025.
#     julia --project=TraitWorld n50_kept_form_replay.jl
using TraitWorld
@trait X50
struct S50 end
h(::X50) = :set
h(::Any) = :any
hm() = hasmethod(h, Tuple{Core.Compiled{S50}}) && which(h, Tuple{Core.Compiled{S50}}).sig == Tuple{typeof(h), X50}
call(c::Core.Compiled{S50}) = h(c)
c = Core.Compiled{S50}(S50())
@assert call(c) === :any
hm()
TraitWorld.@implement X50 S50
@assert hasmethod(h, Tuple{Core.Compiled{S50}}) "hasmethod at the kept form compiled before the membership"
@assert call(c) === :set "a call at the kept form compiled before the membership: $(call(c))"
TraitWorld.delete_membership(X50, S50)
@assert call(c) === :any "taken back: $(call(c))"
println("n50_kept_form_replay: OK")
