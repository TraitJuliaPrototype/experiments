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

# the call inferred again with a constant (compiler §5.5, §7.4): `w` at a `Box` passes a value typed
# `Any`; its caller knows the function, and infers `w`'s code again at it. The edge is the caller's
struct Box; f; n::Int; end
apply3(f::C{Tuple{Int}, Int}) = :callable
apply3(f) = :any
mf(x::Float64) = x
w(b::Box) = apply3(b.f)
callw(n) = w(Box(mf, n))
@assert callw(1) === :any
@assert only(Base.return_types(callw, (Int,))) === Symbol || Base.infer_return_type(callw, (Int,)) === Symbol
cw = latest(callw)
mf(x::Int) = x
@assert callw(1) === :callable "a caller that inferred the call again with a constant is invalidated"

# where `A` names the method's variables, the call's other arguments fix them: the edge is at that `A`
# (compiler §7.4). A method of the function at another type leaves the caller valid
keep2(f::C{Tuple{T}, Bool}, xs::Vector{T}) where {T} = :callable
keep2(f, xs) = :any
pred2(x::String) = true
callk2() = keep2(pred2, [1, 2])
@assert callk2() === :any
ck = latest(callk2)
pred2(x::Float64) = true
@assert ck.max_world == typemax(UInt) "a method at another type than the call's leaves the caller valid"
pred2(x::Int) = x > 1
@assert ck.max_world != typemax(UInt) && callk2() === :callable "the method at the call's type invalidates it"

# a method the call's other arguments cannot reach takes the call whatever the argument's methods: no
# edge. Another type's constructor with a `Callable` argument leaves this type's constructor's caller
# with a record of facts only (the G2 bit, compiler §3.2), so an image keeps it
struct Getter2; f; Getter2(f::C) = new(f); end
struct Sol2; t::Vector{Float64}; n::Int; end
mk2(n) = Sol2([1.0], n)
mk2(1)
g2(ci) = (getfield(ci, :flags, :monotonic)::UInt8 & 0x10) != 0
@assert g2(latest(mk2)) "a constructor's caller holds no edge to its argument's call methods"
println("n26_callable_late_method: OK")
