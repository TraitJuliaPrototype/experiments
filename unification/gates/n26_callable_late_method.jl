# Gate (W-140; compiler §7.4): a compiled caller passes a function where a method at `Callable{A, S}`
# does not match. It holds an edge to the function's dispatch at `A`: a method of the function defined
# later, which begins the membership, invalidates it. Also where `A` names the method's variables.
using Traits
include("util.jl")
const C = Core.Callable
latest(f) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)])

apply2(f::C{Tuple{Int}, Int}) = :callable
apply2(f) = :any
nf(x::Float64) = x
callit() = apply2(nf)
@assert callit() === :any
ci = latest(callit)
nf(x::String) = x                     # a method at another signature begins no membership: the caller stays
@assert ci.max_world == typemax(UInt) "a method elsewhere invalidates nothing"
nf(x::Int) = x + 1
@assert ci.max_world != typemax(UInt) "the method that begins the membership invalidates the caller"
@assert callit() === :callable

# the signature names a method variable: an edge to every call of the function
keep(f::C{Tuple{T}, Bool}, xs::Vector{T}) where {T} = :callable
keep(f, xs) = :any
pred(x::String) = true
callk() = keep(pred, [1, 2])
@assert callk() === :any
pred(x::Int) = x > 1
@assert callk() === :callable
println("n26_callable_late_method: OK")
