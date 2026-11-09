# Gate (E-336; compiler §3.1): a call that reaches an instance wider than its own signature keeps its
# signature on the backedge. A method at a set whose default is `Dynamic` is compiled once, so plain code
# that knows its member's type reaches the instance at the set; a member's own method defined later
# invalidates the callers whose signature it meets (a caller at the set), not the others. The same for a
# `@nospecialize` method, which plain Julia compiles once.
using Traits
include("util.jl")

latest(f, T...) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                c.def.specTypes === Tuple{typeof(f), T...}])
callee_mis(ci) = [e isa Core.CodeInstance ? e.def : e for e in ci.edges if e isa Core.MethodInstance || e isa Core.CodeInstance]

# (1) a method compiled once at a set (its default `Dynamic`; members from another module)
module P21
using Traits
@trait X21
skip(x::X21) = :generic
end
ccall(:jl_set_default_attribute, Cvoid, (Any, Cint), P21.X21, 2)
struct A21 end
struct B21 end
Traits.declare_membership(A21, P21.X21, Main)
Traits.declare_membership(B21, P21.X21, Main)
g21(a::A21) = P21.skip(a)
h21(x::P21.X21) = P21.skip(x)
@assert g21(A21()) === :generic && h21(B21()) === :generic
cg = latest(g21, A21); ch = latest(h21, P21.X21)
@assert any(mi -> mi.specTypes === Tuple{typeof(P21.skip), P21.X21}, callee_mis(cg)) "the plain caller reaches the instance at the set: $(cg.edges)"
P21.skip(::B21) = :b21
@assert cg.max_world == typemax(UInt) "a caller whose signature the new method does not meet stays valid"
@assert ch.max_world != typemax(UInt) "a caller at the set is invalidated"
@assert g21(A21()) === :generic
@assert h21(B21()) === :b21 "the caller at the set, compiled again, reaches the new method"

# (2) a `@nospecialize` method
k336(@nospecialize(x)) = x isa Int ? 1 : 2
c336(x::Int) = k336(x)
d336(@nospecialize(x)) = k336(x)
@assert c336(1) == 1 && d336(1) == 1
cc = latest(c336, Int); cd = latest(d336, Any)
k336(x::String) = 3
@assert cc.max_world == typemax(UInt) "a caller at Int stays valid when a method for String is defined"
@assert cd.max_world != typemax(UInt) "a caller at Any is invalidated"
@assert d336("s") == 3

# (3) a method that meets the call's signature invalidates the caller
c3(x::Integer) = k336(x)
@assert c3(Int8(1)) == 2
c3ci = latest(c3, Int8)
k336(x::Int8) = 4
@assert c3ci.max_world != typemax(UInt) "a method meeting the call's signature invalidates the caller"
@assert c3(Int8(1)) == 4

println("n21_callsig_backedge: OK")
