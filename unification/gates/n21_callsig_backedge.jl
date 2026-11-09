# Gate (E-336; compiler §3.1): a call that reaches an instance wider than its own signature keeps its
# signature on the backedge. A method typed `io::IO` is compiled once, so plain code that knows its
# stream (`seekstart(::IOBuffer)`) reaches the instance `seekstart(::IO)`; a member's own method defined
# later invalidates the callers whose signature it meets (a caller at `IO`), not the others. The same
# for a `@nospecialize` method, which plain Julia compiles once.
using Traits
include("util.jl")

latest(f, T...) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                c.def.specTypes === Tuple{typeof(f), T...}])
callee_mis(ci) = [e isa Core.CodeInstance ? e.def : e for e in ci.edges if e isa Core.MethodInstance || e isa Core.CodeInstance]

# (1) a method compiled once at a set
struct S336 <: IO end
g336(io::IOBuffer) = seekstart(io)
h336(io::IO) = seekstart(io)
@assert g336(IOBuffer()) isa IOBuffer
@assert h336(IOBuffer()) isa IOBuffer
cg = latest(g336, IOBuffer); ch = latest(h336, IO)
@assert any(mi -> mi.specTypes === Tuple{typeof(seekstart), IO}, callee_mis(cg)) "the plain caller reaches the instance at IO: $(cg.edges)"
Base.seekstart(::S336) = :s336
@assert cg.max_world == typemax(UInt) "a caller whose signature the new method does not meet stays valid"
@assert ch.max_world != typemax(UInt) "a caller at IO is invalidated"
@assert g336(IOBuffer()) isa IOBuffer
@assert h336(S336()) === :s336 "the caller at IO, compiled again, reaches the new method"

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
