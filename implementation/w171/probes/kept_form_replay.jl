# W-171, second part (E-543; compiler C-167): a membership adds to a set more types than its member: each kept
# form at it (`Compiled{S}`, by the library's pattern `Compiled{Z} where Z <: X`). The walk replays a method at the
# set at the member only (`h(::S)`), so `hasmethod(h, Tuple{Compiled{S}})`, folded `false` with a missing-method
# edge before the membership, stays `false`.
#     julia --project=TraitWorld kept_form_replay.jl
using TraitWorld
@trait X
struct S end
h(::X) = 1
hm() = hasmethod(h, Tuple{Core.Compiled{S}})
println("before: ", hm())
TraitWorld.@implement X S
println("after:  ", hm(), " (fresh ", hasmethod(h, Base.inferencebarrier(Tuple{Core.Compiled{S}})), ")")
