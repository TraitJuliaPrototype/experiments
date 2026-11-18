# Gate (open issue 171, rewritten for W-164; traits §4.1, §7.9; compiler §4.1, §6.8, §7.1, §7.2; facts §2.1): an
# operation is an entry of its set's contract, `svec(f, sig, rt, default)`, written once on the set's TypeName
# (`jl_set_contract_operations`); no method at the set serves it. A call of the operation on a value the code knows
# only by its trait is inferred as the entry's declared result, and the result is asserted, never converted: a
# member whose serving method escaped its check (redefined after it) makes the call through the trait raise a
# `TypeError`, G1's "or raises"; a dynamic call of the same operation returns the member's own result. The value
# never depends on inference: no path returns a converted value. A method's declared result is not an operation's:
# a method at the set with a declared result, and no entry, gives the call at the set no declared result.
# The stub library declares no contract: the gate writes the entry as the library's `@trait` does (lowering §2).
using Traits
include("util.jl")

# (1) a method at the set with a declared result, and no entry: no operation, so no declared result at the set
@trait Sized22
count22(x::Sized22) = error("no method")
ccall(:jl_method_set_declared_result, Cvoid, (Any, Any, Cint), which(count22, (Sized22,)), Int, 1)
for i in 1:5
    T = Symbol(:K22_, i)
    @eval struct $T end
    @eval count22(::$T) = $(isodd(i) ? 0 : "s")       # members' methods of other result types
    @eval declare_membership($T, Sized22, @__MODULE__)
end
throughk(v::Vector{Sized22}) = count22(v[1])
@assert Base.return_types(throughk, (Vector{Sized22},)) != Any[Int] "a method's declared result is no operation's: $(Base.return_types(throughk, (Vector{Sized22},)))"
@assert throughk(Sized22[K22_2()]) == "s" "no assertion where no entry declares a result"

# (2) the operation: an entry, its declared result `Int`, no default
@trait Measured22
function size22 end
ccall(:jl_set_contract_operations, Cvoid, (Any, Any), Measured22,
      Core.svec(Core.svec(size22, Tuple{typeof(size22), Measured22}, Int, nothing)))
@assert isempty(methods(size22, (Measured22,))) "no method at the set"
for i in 1:4                                           # the four candidates: M22 is past them, so its call goes
    T = Symbol(:C22_, i)                               # through the table
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
@assert through(Measured22[C22_2()]) === 0 "a branch of the split: the member's own method"
@assert Base.return_types(through, (Vector{Measured22},)) == Any[Int] "the entry's declared result: $(Base.return_types(through, (Vector{Measured22},)))"

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
