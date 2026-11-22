# Gate (compiler §5.5, §5.6; E-542): a membership taken back ends the code that rests on it. `applicable` and
# `hasmethod` folded through the membership name the method's instance at the member, which has no code of its own;
# taken back, the membership ends them as a method's deletion ends a call's callers.
# A candidate for `gates/`; fails on `next` dd42dc8c3f, passes on `w171`.
#     julia --project=experiments/implementation n40_removal_instance_callers.jl
using Traits
@trait X
struct S end
h(::X) = :h
qa(x) = applicable(h, x)
qh() = hasmethod(h, Tuple{S})
@implement X S
@assert qa(S()) && qh()
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, X, @__MODULE__)
@assert !applicable(Base.inferencebarrier(h), Base.inferencebarrier(S()))
@assert qa(S()) === false "applicable compiled through the membership: $(qa(S()))"
@assert qh() === false "hasmethod compiled through the membership: $(qh())"
println("n40_removal_instance_callers: OK")
