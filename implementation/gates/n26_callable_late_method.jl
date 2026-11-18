# Gate (W-140, rewritten for W-164; compiler §7.4, §6.3; traits §9): a method of a function defined after code that
# passes the function at `Callable{A, S}`. It begins no membership: the function is a member before and after, and
# dispatch selects the method at `Callable` before and after (a method at `Any` beside it is not taken). What it
# changes is the box's test, a fact with its edge to the function's dispatch at `A`: the code compiled while the
# function had no method at `A` refuses it with the `MethodError` of the call that passes it; the method at `A` ends
# that code and the call succeeds; a method at another signature ends nothing. Also where `A` names the method's
# variables (the other arguments fix them), and where the function reaches the call as a value typed `Any`.
# project: TraitWorld
#     julia --project=<TraitWorld tree> n26_callable_late_method.jl
using TraitWorld
include("util.jl")
latest(f) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)])
outcome(f, args...) = try Base.invokelatest(f, args...) catch e; typeof(e) end

module L
using TraitWorld
const C = Callable
apply2(f::C{Tuple{Int}, Int}) = :callable
apply2(f) = :any
nf(x::Float64) = x
callit() = apply2(nf)
keep2(f::C{Tuple{T}, Bool}, xs::Vector{T}) where {T} = :callable
keep2(f, xs) = :any
pred2(x::String) = true
callk2() = keep2(pred2, [1, 2])
struct Box; f; n::Int; end
apply3(f::C{Tuple{Int}, Int}) = :callable
apply3(f) = :any
mf(x::Float64) = x
w(b::Box) = apply3(b.f)                                # the function a value typed Any
callw(n) = w(Box(mf, n))
end
const C = Callable

# no method at A: a member, the method at Callable selected, the box refuses
@assert typeof(L.nf) <: C{Tuple{Int}, Int}
@assert outcome(L.callit) === MethodError "refused at the box, not sent to apply2(::Any)"
ci = latest(L.callit)
@eval L nf(x::String) = x                              # a method at another signature
@assert ci.max_world == typemax(UInt) "a method elsewhere ends nothing"
@assert outcome(L.callit) === MethodError
@eval L nf(x::Int) = x + 1                             # the method at A
@assert ci.max_world != typemax(UInt) "the method at A ends the code that relied on its absence"
@assert outcome(L.callit) === :callable
@assert typeof(L.nf) <: C{Tuple{Int}, Int} "the membership never changed"

# A names the method's variable, fixed by the other argument: the edge is at that A
@assert outcome(L.callk2) === MethodError
ck = latest(L.callk2)
@eval L pred2(x::Float64) = true
@assert ck.max_world == typemax(UInt) "a method at another type than the call's leaves the code valid"
@eval L pred2(x::Int) = x > 1
@assert ck.max_world != typemax(UInt) && outcome(L.callk2) === :callable "the method at the call's type ends it"

# the function reaches the call as a value typed Any: the box's test runs when the call does
@assert outcome(L.callw, 1) === MethodError
@eval L mf(x::Int) = x
@assert outcome(L.callw, 1) === :callable

# a constructor with a bare `Callable` argument (no signature, no box) leaves another type's constructor's caller
# with a record of facts only (the G2 bit, compiler §3.2), so an image keeps it
module L2
using TraitWorld
struct Getter2; f; Getter2(f::Callable) = new(f); end
struct Sol2; t::Vector{Float64}; n::Int; end
mk2(n) = Sol2([1.0], n)
end
L2.mk2(1)
g2(ci) = (getfield(ci, :flags, :monotonic)::UInt8 & 0x10) != 0
@assert g2(latest(L2.mk2)) "a constructor's caller holds no edge to its argument's call methods"
println("n26_callable_late_method: OK")
