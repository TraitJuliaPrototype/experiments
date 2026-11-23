# W-171, second part (E-543; compiler C-166): a method at the member's own type (`g(::S)`), defined before the
# membership, and a call compiled once at the set (`q(::X)`, which found `g(::X)` alone there): once `S` joins `X`,
# the call at `X` meets `g(::S)`, more specific, and its selection for an `S` changes. The membership's walk replays
# the methods at the set, not the member's own methods, and the lookup at `X` recorded no absence for the pair
# (`S`, `X`), so the caller keeps its static call to `g(::X)`.
#     julia --project=experiments/implementation member_method_at_set.jl
using Traits
@trait X
struct S end
struct T1 end
@implement X T1
g(::X) = :X
g(::S) = :S
Base.@nospecializeinfer q(@nospecialize(x::X)) = g(x)
println("before: q(T1()) ", q(T1()))
@implement X S
println("after:  q(S()) ", q(Base.inferencebarrier(S())), " (expected :S), g(S()) ", g(Base.inferencebarrier(S())))
