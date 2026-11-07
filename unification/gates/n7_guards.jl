# Gate (W-112; compiler §5.5, §5.6; facts §10): a membership invalidates no code. A compiled call that
# a later membership could change carries a guard on a membership cell: while the cell is closed the
# call runs the method it selected, once a membership opens it the call dispatches when it runs. A task
# in an older world keeps the old answer. A method at a set defined after its callers invalidates them,
# and they compile again with the guard. A call matched through the type's own supertypes needs none.
using Traits
include("util.jl")

latest(f, T) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                               c.def.specTypes === Tuple{typeof(f), T}])
cells(ci) = [e for e in ci.edges if e isa Core.MembershipCell]

@trait X
abstract type Closed end
struct S end                       # will join X
struct T <: Closed end             # will join X too, but its own supertype's method wins
struct U end                       # joins X before any code is compiled

f(x) = :any
f(x::X) = :set
f(x::Closed) = :closed
@implement X U

callf(s::S) = f(s)
callt(t::T) = f(t)
callu(u::U) = f(u)

# (1) a guarded call: the method selected, a cell in the record
@assert callf(S()) === :any
ci = latest(callf, S)
cs = cells(ci)
@assert length(cs) == 1 && cs[1].member === S && cs[1].min_world == typemax(UInt) "one closed cell: $cs"
w_before = curworld()

# (2) the membership opens the cell, invalidates nothing, and the call dispatches
e = @implement X S
@assert cs[1].min_world == e.min_world "the cell opened at the entry's world"
@assert ci.max_world == typemax(UInt) "the caller is not invalidated"
@assert callf(S()) === :set
@assert latest(callf, S) === ci "the same code runs"
@assert Base.invoke_in_world(w_before, callf, S()) === :any "an older world keeps the old answer"

# (3) matched through the type's own supertypes: no guard, the closed method stays more specific
@assert callt(T()) === :closed
@assert isempty(cells(latest(callt, T)))
@implement X T
@assert callt(T()) === :closed

# (4) a member already: dispatch at the set, no guard
@assert callu(U()) === :set && isempty(cells(latest(callu, U)))

# (5) a method at a set defined after its callers: they compile again, with the guard
@trait Y
struct V end
g(x) = :any
callg(v::V) = g(v)
@assert callg(V()) === :any
cig = latest(callg, V)
@assert isempty(cells(cig))
g(y::Y) = :set
@assert cig.max_world != typemax(UInt) "the method at the set invalidated the unguarded caller"
@assert callg(V()) === :any
cig2 = latest(callg, V)
@assert length(cells(cig2)) == 1
@implement Y V
@assert callg(V()) === :set && latest(callg, V) === cig2

# (6) the guarded call's result: the selected method's or the shadowing one's
@trait Z
struct W end
h(x) = 1
h(z::Z) = 2.0
callh(w::W) = h(w)
@assert callh(W()) === 1
@assert Base.infer_return_type(callh, (W,)) == Union{Int, Float64} || Base.infer_return_type(callh, (W,)) === Any
@implement Z W
@assert callh(W()) === 2.0

# (7) under the facts mode too
module FM
Base.Experimental.@compiler_options facts=true
import ..X
struct P end
k(x) = :any
k(x::X) = :set
callk(p::P) = k(p)
end
@assert FM.callk(FM.P()) === :any
cik = latest(FM.callk, FM.P)
@implement X FM.P
@assert FM.callk(FM.P()) === :set && cik.max_world == typemax(UInt)

println("n7_guards: OK")
