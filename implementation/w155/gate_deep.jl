# W-155, D-5's gate (compiler §3.2; E-417): the G2 bit marks the deep class. A CodeInstance carries it
# where every dispatch edge of its record is at a fact signature and every callee among its edges is a
# CodeInstance that carries it; an instance whose edges are bindings only carries it; an inference cycle
# is decided as one.
#     julia --startup-file=no gate_deep.jl
function native_ci(f, T)
    mi = Base.method_instance(f, T)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        ci.owner === nothing && return ci
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return nothing
end
bit(ci) = (ci.flags & 0x10) != 0
ok = Ref(true)
check(c, what) = (c || (ok[] = false); println(c ? "  ok   " : "  FAIL ", what))

module P                        # plain code
leaf(x::Int) = x + 1
deep(x::Int) = leaf(x) * 2                       # every call at a fact signature, its callee deep
const box = Ref{Any}(1)
shallow(x::Int) = x + (box[]::Int)               # reads a binding; a call at a fact
@noinline spec(v::Vector{Any}) = leaf(v[1])      # a call at Any: not a fact
above(x::Int) = spec(Any[x])                     # every own call at a fact, but its callee is not deep
even(n::Int) = n == 0 ? true : odd(n - 1)        # a cycle, every member at facts
odd(n::Int) = n == 0 ? false : even(n - 1)
evenb(n::Int, v::Vector{Any}) = n == 0 ? leaf(v[1]) : oddb(n - 1, v)    # a cycle with a call at Any (one method:
oddb(n::Int, v::Vector{Any}) = n == 0 ? 0 : evenb(n - 1, v)               # plain inference commits to it)
end
module F                        # compiled by facts
Base.Experimental.@compiler_options facts=true
import ..P
rt(v::Vector{Any}) = P.leaf(v[1])               # a run-time site: no edge, the bit holds
up(x::Int) = P.above(x)                          # rests on a plain callee outside the class
name() = getproperty(P, :leaf)                   # a constant-propagated result over a binding
end
@assert P.deep(1) == 4 && P.shallow(1) == 2 && P.spec(Any[1]) == 2 && P.above(1) == 2
@assert P.even(4) && !P.odd(4) && P.evenb(2, Any[1]) == 2
@assert F.rt(Any[1]) == 2 && F.up(1) == 2
println("the bit as the deep class (compiler §3.2):")
check(bit(native_ci(P.leaf, (Int,))), "a leaf at facts carries it")
check(bit(native_ci(P.deep, (Int,))), "a caller of a deep callee carries it")
check(bit(native_ci(P.shallow, (Int,))), "a binding edge needs nothing more")
check(!bit(native_ci(P.spec, (Vector{Any},))), "a call at Any: no bit")
check(!bit(native_ci(P.above, (Int,))), "a caller of a callee outside the class: no bit (one level deep it had one)")
check(bit(native_ci(P.even, (Int,))) && bit(native_ci(P.odd, (Int,))), "a cycle at facts: every member")
check(!bit(native_ci(P.evenb, (Int, Vector{Any}))) && !bit(native_ci(P.oddb, (Int, Vector{Any}))), "a cycle with a member at Any: no member")
check(bit(native_ci(F.rt, (Vector{Any},))), "facts code with a run-time site carries it")
check(!bit(native_ci(F.up, (Int,))), "facts code over a plain callee outside the class: no bit")
# an instance whose edges are bindings only (open issue 187): the edge instance of a constant-propagated
# `getproperty(::Module, ::Symbol)` that `F.name` holds
F.name()
ci = native_ci(F.name, ())
bonly = [e for e in ci.edges if e isa Core.CodeInstance && !isempty(e.edges) && all(x -> x isa Core.Binding, e.edges)]
noedge = [e for e in ci.edges if e isa Core.CodeInstance && isempty(e.edges)]
println("  (", length(bonly), " callee instances with binding edges only, ", length(noedge), " with none)")
check(all(bit, bonly) && all(bit, noedge), "an instance whose edges are bindings only, or none, carries it")
println(ok[] ? "gate_deep: OK" : "gate_deep: FAILED")
exit(ok[] ? 0 : 1)
