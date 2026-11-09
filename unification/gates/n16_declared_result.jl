# Gate for compiler C-36 (§6.8): lowering records `f(…)::RT` as the method's declared result, where `RT`
# is a constant type expression at the definition; the flag that it covers every member stays unset (only
# the library sets it, for a trait's operation). A guarded call whose shadow is a method at a set joins
# that declared result, not `Any` (§5.6); a result naming the method's static parameters stays `Any` there.
# A declared result `Union{}` makes the method raise-only, so it is no shadow.
using Traits
include("util.jl")

latest_ci(f, T) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                  c.def.specTypes === Tuple{typeof(f), T}])
dr(m::Method) = isdefined(m, :declared_result) ? m.declared_result : nothing
dr(f, T) = dr(only(methods(f, T)))

# (1) what is recorded
a1(x::Int)::Float64 = x
a2(x::T) where {T} = x
function a3(x::T)::Vector{T} where {T}
    return [x]
end
a4(x)::Vector{<:Real} = x
a5(x)::Union{Int, Nothing} = x
a6(x)::Tuple{Int, Vararg{Int}} = x
a7(x)::typeof(x) = x                     # names an argument: not a constant
RTV = Int
a8(x)::RTV = x                           # a global that is not constant
const RTC = Vector{Int}
a9(x)::RTC = x
module QM; const T = Vector{Int}; end
a10(x)::Base.Int = x                     # a module's constant binding (`getproperty` at a module)
a11(x)::QM.T = x
a12(x)::Base.Vector{Base.Int} = x
@assert dr(a1, (Int,)) === Float64
@assert dr(a2, (Any,)) === nothing
let r = dr(a3, (Any,)), m = only(methods(a3))
    @assert r isa DataType && r.name === Vector.body.name && r.parameters[1] === m.sig.var "Vector{T} at the method's own T: $r"
end
@assert dr(a4, (Any,)) == Vector{<:Real}
@assert dr(a5, (Any,)) == Union{Int, Nothing}
@assert dr(a6, (Any,)) == Tuple{Int, Vararg{Int}}
@assert dr(a7, (Any,)) === nothing
@assert dr(a8, (Any,)) === nothing
@assert dr(a9, (Any,)) === Vector{Int}
@assert dr(a10, (Any,)) === Int
@assert dr(a11, (Any,)) === Vector{Int}
@assert dr(a12, (Any,)) === Vector{Int}
@assert (only(methods(a1)).declared_covers & 0x01) == 0 "lowering's record does not claim to cover every member"
@assert a1(1) === 1.0 && a3(1) == [1]

# (2) a guarded call joins the shadow's declared result
@trait Z
struct W end
h(x) = 1
h(z::Z)::Float64 = 2.0
callh(w::W) = h(w)
@assert callh(W()) === 1
@assert Base.infer_return_type(callh, (W,)) == Union{Int, Float64} "the join with the declared result: $(Base.infer_return_type(callh, (W,)))"
@implement Z W
@assert callh(W()) === 2.0

# (3) a declared result at the method's static parameters: `Any` at the guarded call
@trait Z2
struct W2 end
hp(x) = [1]
(hp(z::T)::Vector{T}) where {T <: Z2} = [z]
callhp(w::W2) = hp(w)
@assert callhp(W2()) == [1]
@assert Base.infer_return_type(callhp, (W2,)) === Any

# (4) declared `Union{}`: raises only, so no shadow and no guard
@trait Z3
struct W3 end
hn(x) = 1
hn(z::Z3)::Union{} = error("no member is served")
callhn(w::W3) = hn(w)
@assert callhn(W3()) === 1
@assert Base.infer_return_type(callhn, (W3,)) === Int
@assert isempty([e for e in latest_ci(callhn, W3).edges if e isa Core.MembershipCell]) "no guard"

# (5) under facts
module FM
Base.Experimental.@compiler_options facts=true
import ..Z
struct P end
k(x) = 1
k(x::Z)::Float64 = 2.0
callk(p::P) = k(p)
end
@assert FM.callk(FM.P()) === 1
@assert Base.infer_return_type(FM.callk, (FM.P,)) == Union{Int, Float64}
println("n16_declared_result: OK")
