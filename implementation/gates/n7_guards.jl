# Gate (W-140; compiler §5.5, §5.6; facts §10): a membership invalidates as a method does. A compiled
# call that a membership changes holds no guard and no cell: the membership replays the set's methods at
# the member and invalidates the callers whose selection changes, and they compile again. A task in an
# older world keeps the old answer. A method at a set defined after its callers invalidates none of them
# at a type that is no member; the membership does, when it comes. A call matched through the type's
# own supertypes is not invalidated.
using Traits
include("util.jl")

latest(f, T) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                               c.def.specTypes === Tuple{typeof(f), T}])
cells(ci) = absences(ci)
dyncalls(f, T) = [st for st in first(only(code_typed(f, T))).code if Meta.isexpr(st, :call) && !(st.args[1] isa GlobalRef && st.args[1].mod === Core)]

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

# (1) the call selects its method: no guard, no cell
@assert callf(S()) === :any
ci = latest(callf, S)
@assert isempty(cells(ci)) "no cell: $(cells(ci))"
@assert isempty(dyncalls(callf, (S,))) "a static call: $(first(only(code_typed(callf, (S,)))))"
w_before = curworld()

# (2) the membership invalidates the caller whose selection it changes
e = @implement X S
@assert ci.max_world == e.min_world - 1 "the caller is invalidated at the entry"
@assert callf(S()) === :set
@assert latest(callf, S) !== ci "new code runs"
@assert Base.invoke_in_world(w_before, callf, S()) === :any "an older world keeps the old answer"

# (3) matched through the type's own supertypes: the closed method stays more specific, the caller valid
@assert callt(T()) === :closed
cit = latest(callt, T)
@implement X T
@assert callt(T()) === :closed && cit.max_world == typemax(UInt) "the membership changes nothing here"

# (4) a member already: dispatch at the set
@assert callu(U()) === :set && isempty(cells(latest(callu, U)))

# (5) a method at a set defined after its callers invalidates none at a type that is no member; the
# membership does
@trait Y
struct V end
g(x) = :any
callg(v::V) = g(v)
@assert callg(V()) === :any
cig = latest(callg, V)
g(y::Y) = :set
@assert cig.max_world == typemax(UInt) "the method at the set invalidates no caller at a non-member"
@assert callg(V()) === :any
@implement Y V
@assert cig.max_world != typemax(UInt) "the membership invalidates it"
@assert callg(V()) === :set

# (6) the call's result is the selected method's (W-140: no join with the shadowing method's)
@trait Z
struct W end
h(x) = 1
h(z::Z) = 2.0
callh(w::W) = h(w)
@assert callh(W()) === 1
@assert Base.infer_return_type(callh, (W,)) == Int
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
@assert FM.callk(FM.P()) === :set && cik.max_world != typemax(UInt)

println("n7_guards: OK")
