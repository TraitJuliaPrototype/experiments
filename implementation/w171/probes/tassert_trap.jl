# W-171 (E-542): a typeassert at a set that fails, compiled for a concrete non-member
#     julia --project=experiments/implementation tassert_trap.jl
using Traits
@trait X
struct S end
const B = X
q(x) = (x::B; true)
r(x) = q(x)
println(Base.infer_return_type(r, (S,)))
println(try r(S()) catch e; e end)
mi = only(Base.specializations(only(methods(r))))
ci = mi.cache
println("worlds ", Int(ci.min_world), ":", ci.max_world, " edges ", ci.edges)
@implement X S
println("after the membership: fresh ", Core.typeassert(Base.inferencebarrier(S()), Base.inferencebarrier(B)) isa S)
println(r(S()))     # traps: the code compiled before the membership ends in `unreachable` after a typeassert that now passes
