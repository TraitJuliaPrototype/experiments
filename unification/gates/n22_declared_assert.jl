# Gate (open issue 171; traits §7.9, §11; compiler §7.2; facts §2.1): a call of an operation on a value
# the code knows only by its trait asserts the declared result and never converts it. A member whose
# serving method escaped its check (redefined after it) makes the call through the trait raise a
# `TypeError`, G1's "or raises"; a dynamic call of the same operation returns the member's own result.
# The value never depends on inference: no path returns a converted value.
using Traits
include("util.jl")

@trait Measured22
size22(x::Measured22) = error("no method")              # the operation, its declared result `Int` with the flag
ccall(:jl_method_set_declared_result, Cvoid, (Any, Any, Cint), which(size22, (Measured22,)), Int, 1)
for i in 1:4                                           # the four candidates: M22 is past them, so its call goes
    T = Symbol(:C22_, i)                               # through the table and the fallback
    @eval struct $T end
    @eval size22(::$T) = 0
    @eval declare_membership($T, Measured22, @__MODULE__)
end
struct M22 end
size22(::M22) = 1
declare_membership(M22, Measured22, @__MODULE__)
@assert something(findfirst(==(M22), ccall(:jl_candidates_of, Any, (Any,), Measured22)), 0) > Base.Compiler.MAX_OPERATION_SPLITS "M22 past the split's candidates"

through(v::Vector{Measured22}) = size22(v[1])          # a value known by its trait: the split
dynamic(v::Vector{Any}) = size22(v[1])                 # a value typed Any: dispatch
@assert through(Measured22[M22()]) === 1 && dynamic(Any[M22()]) === 1
@assert Base.return_types(through, (Vector{Measured22},)) == Any[Int] "the declared result: $(Base.return_types(through, (Vector{Measured22},)))"

# the serving method redefined after the check, to another integer type
size22(::M22) = UInt(2)
@assert try through(Measured22[M22()]); false catch e; e isa TypeError end "asserted, not converted"
@assert dynamic(Any[M22()]) === UInt(2) "a dynamic call returns the member's result"
# a closure that builds the value where constant propagation sees the member's type: the code returns a
# type its call's type admits (compiled code never returns a value its inferred type excludes)
let f = () -> through(Measured22[M22()])
    r = try f() catch e; e end
    @assert r isa TypeError || (r === UInt(2) && all(T -> UInt <: T, Base.return_types(f, ()))) "the closure: $r, $(Base.return_types(f, ()))"
end
println("n22_declared_assert: OK")
