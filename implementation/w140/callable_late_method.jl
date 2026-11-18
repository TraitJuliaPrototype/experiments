# W-140: a compiled caller that passes a function where a method at `Callable` could apply. The function
# gains the method that makes it a member after the caller is compiled. Does the caller follow?
using Traits
const C = Core.Callable
apply2(f::C{Tuple{Int}, Int}) = :callable
apply2(f) = :any
nf(x::Float64) = x
callit() = apply2(nf)
@assert callit() === :any
nf(x::Int) = x + 1
r = callit()
println("after the method, callit() = ", r, r === :callable ? "  (Julia's answer)" : "  (STALE)")
r === :callable || exit(1)
