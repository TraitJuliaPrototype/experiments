# Gate for compiler C-73 (§5.6): a caller compiled with a pruned arm (no method at a concrete type) is
# reached by a later method at a set its type could join: invalidated at the method's insertion, it
# compiles again with its guard, and after the membership the call gives Julia's answer. A method
# that can only raise (declared result `Union{}`) is no shadow: the call raises as the pruned arm did.
# (Its insertion invalidating nothing needs the declared result before the insertion, as in an image.)
using Traits
include("util.jl")

struct P end
struct RV
    v::Union{Vector{Int}, P}
end
g(v::Vector{Int}) = 1.0
h(r::RV) = g(r.v) + 1                 # the `P` arm has no method of `g`: pruned to a MethodError
@assert h(RV([1])) == 2.0
@assert (try h(RV(P())); false catch e; e isa MethodError end) "no method at P yet"
cis_before = [c for c in all_cis(h) if c.max_world == typemax(UInt)]
@assert !isempty(cis_before)

@trait Q
g(q::Q) = 7.5                         # a method at a set the caller's `P` could join
@assert all(c -> c.max_world != typemax(UInt), cis_before) "the caller that pruned the arm is invalidated (C-73)"
@assert (try h(RV(P())); false catch e; e isa MethodError end) "still no method at P: P is no member"

@implement Q P
@assert h(RV(P())) == 8.5 "after the membership the call gives Julia's answer"
@assert h(RV([1])) == 2.0

# a method that can only raise is no shadow
struct P2 end
struct RV2
    v::Union{Vector{Int}, P2}
end
k(v::Vector{Int}) = 1
hk(r::RV2) = k(r.v) + 1
@assert hk(RV2([1])) == 2
cis2 = [c for c in all_cis(hk) if c.max_world == typemax(UInt)]
@trait Q2
k(q::Q2) = throw(MethodError(k, (q,)))
ccall(:jl_method_set_declared_result, Cvoid, (Any, Any, Cint), only(methods(k, (Q2,))), Union{}, 1)
@implement Q2 P2
@assert (try hk(RV2(P2())); false catch e; e isa MethodError end) "a raise-only method raises as the pruned arm did"
println("n11_late_shadow: OK")
