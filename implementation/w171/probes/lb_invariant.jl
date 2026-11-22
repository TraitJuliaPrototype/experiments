# W-171 (E-542): inside an invariant parameter two types are equal by their declared structure in every world (compiler
# §4.5); `isa(x, T)` and `typeof(x) <: T` agree (§4.4). Two UnionAll types whose variables' lower bounds differ only by a
# membership, as the parameter of a phantom struct.
#     julia --project=experiments/implementation lb_invariant.jl
using Traits
@trait X
struct S end
struct Ph{T} end
const A = Ph{Ph{T} where T>:X}
const B = Ph{Ph{T} where T>:Union{X, S}}
x = A()
show2(tag) = println(rpad(tag, 22), "typeof(x) <: B ", ccall(:jl_subtype, Cint, (Any, Any), A, B) != 0,
                     "   x isa B ", ccall(:jl_isa, Cint, (Any, Any), x, B) != 0,
                     "   (Ph{T} where T>:X) == (Ph{T} where T>:Union{X,S}) ", ccall(:jl_types_equal, Cint, (Any, Any), A.parameters[1], B.parameters[1]) != 0)
show2("before")
@implement X S
show2("after the membership")
