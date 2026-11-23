# Gate (compiler §4.8, §5.6; E-544, C-166): a method at the member's own type (`g(::S)`) defined before `S` joins `X`
# becomes a match at a call compiled at `X`. The lookup at `X` dropped it because `S` was no member, which rests on the
# pair's absence: the caller records it, and the membership ends the caller. Also through a set member and an
# abstract member. A candidate for `gates/`; fails on `next` 3e9c193025.
#     julia --project=experiments/implementation n51_member_method_at_set.jl
using Traits
@trait X
struct S end
struct T1 end
@implement X T1
g(::X) = :X
g(::S) = :S
Base.@nospecializeinfer q(@nospecialize(x::X)) = g(x)
@assert q(T1()) === :X
@implement X S
@assert q(Base.inferencebarrier(S())) === :S "a call compiled at the set before the membership: $(q(S()))"
# an abstract member: its subtype's own method
abstract type AM end
struct SA <: AM end
f(::X) = :X
f(::SA) = :SA
Base.@nospecializeinfer p(@nospecialize(x::X)) = f(x)
@assert p(T1()) === :X
@implement X AM
@assert p(Base.inferencebarrier(SA())) === :SA "an abstract member's subtype: $(p(SA()))"
# a set member: its member's own method
@trait Y0
struct S0 end
@implement Y0 S0
k(::X) = :X
k(::S0) = :S0
Base.@nospecializeinfer r(@nospecialize(x::X)) = k(x)
@assert r(T1()) === :X
@implement X Y0
@assert r(Base.inferencebarrier(S0())) === :S0 "a set member's member: $(r(S0()))"
println("n51_member_method_at_set: OK")
