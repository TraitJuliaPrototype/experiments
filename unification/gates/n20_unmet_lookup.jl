# Gate (E-331, E-334, C-82; compiler §4.8, §4.9, §5.4): a match met only at an intersection that no type
# of the world is in. At a final pair (a set closed after load) dispatch's lookup drops it, whatever its
# specificity and however many matches there are, and reports the pair's final cell, which the caller
# records: a membership that meets the intersection invalidates it. At an open set the match stays:
# compiled code relies on no negative there, so a call that is ambiguous at the intersection dispatches.
# A `Callable` component is met (its members are methods), and a `Vararg` tail is met by its empty tail.
# Reflection (`Base.isambiguous`) reports no ambiguity over an intersection with no value.
using Traits
include("util.jl")
const CC = Base.Compiler
lookup(T) = CC.findall(T, CC.method_table(CC.NativeInterpreter()); limit = -1)
unmet(T) = ccall(:jl_has_unmet_argument, Cint, (Any, UInt), T, Base.get_world_counter()) != 0
invokes(f, T) = [st for st in first(only(code_typed(f, T))).code if Meta.isexpr(st, :invoke)]
dyncalls(f, T) = [st for st in first(only(code_typed(f, T))).code
                  if Meta.isexpr(st, :call) && st.args[1] == GlobalRef(Core, :attributed_call)]
latest(f, T...) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                c.def.specTypes === Tuple{typeof(f), T...}])
finalcells(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal != 0x00]

# a set closed after load, its module loaded, with a member of its own; and an open set
module P20
using Traits
@trait X20
struct M20 end
struct S20 <: AbstractString end                       # joins X20 late, in (4)
w1(x::X20, c::Char) = 1
w1(s::AbstractString, xs...) = "two"                      # ties with w1(::X20, ::Char) at All{AbstractString, X20}
w2(x::X20, a::UInt8) = 1
w2(s::AbstractString, a::UInt8) = 2                    # ranks above w2(::X20, …): AbstractString is closed
end
ccall(:jl_set_closed_after_load, Cvoid, (Any,), P20.X20)
Traits.declare_membership(P20.M20, P20.X20, P20)
ccall(:jl_module_set_loaded, Cvoid, (Any,), P20)
@trait X9

# (1) the intersection with no member is unmet; the lookup is one match, unambiguous; the call static
@assert unmet(Tuple{typeof(P20.w1), Core.All{Tuple{AbstractString, P20.X20}}, Char})
@assert !unmet(Tuple{typeof(P20.w1), P20.X20, Char})
r = lookup(Tuple{typeof(P20.w1), P20.X20, Char})
@assert !r.ambig && length(r.matches) == 1 "w1(::X20, ::Char): $(r.ambig) $(r.matches)"
wc(@nospecialize(x::P20.X20), c::Char) = P20.w1(x, c)
@assert isempty(dyncalls(wc, (P20.X20, Char))) && Base.return_types(wc, (P20.X20, Char)) == Any[Int] "static, one match: $(first(only(code_typed(wc, (P20.X20, Char)))))"
@assert wc(P20.M20(), 'a') == 1
# the incomparable match the lookup dropped: its final cell is on the caller (C-82), so a membership that
# meets the intersection invalidates it (case (4) below)
@assert any(c -> c.member === AbstractString, finalcells(latest(wc, P20.X20, Char))) "the cell on the caller: $(latest(wc, P20.X20, Char).edges)"
# a repeated site carries it too
wc2(@nospecialize(x::P20.X20), c::Char) = (P20.w1(x, c), P20.w1(x, c))
@assert wc2(P20.M20(), 'a') == (1, 1)
@assert any(c -> c.member === AbstractString, finalcells(latest(wc2, P20.X20, Char))) "a repeated site"
# a lone match met only at the final pair: dropped, the call at X20 has no method
l8(s::AbstractString) = 1
@assert isempty(lookup(Tuple{typeof(l8), P20.X20}).matches) "the lone unmet match dropped at the final pair"

# (2) a type of Main and an open set: the match that would win stays; the one that would tie leaves
abstract type Q9 end
k9(::X9, ::Char) = 1
k9(::Q9, ::Any) = 2                                    # ties with k9(::X9, ::Char) at All{Q9, X9}
# at the open set the match stays (C-82): the runtime returns the covering match, ambiguous, and the
# caller dispatches; its result type stays the covering method's
let r = lookup(Tuple{typeof(k9), X9, Char})
    @assert r.ambig "ambiguous at the open set: $(r.ambig) $(r.matches)"
end
kc(@nospecialize(x::X9)) = k9(x, 'a')
let code = first(only(code_typed(kc, (X9,)))).code
    @assert any(st -> Meta.isexpr(st, :call) && st.args[1] == GlobalRef(@__MODULE__, :k9), code) "kc dispatches: $code"
end
f9(::Any) = 0
f9(::X9) = 1                                           # at All{Q9, X9} more specific than f9(::Any)
@assert length(lookup(Tuple{typeof(f9), Q9}).matches) == 2 "a match that would win stays"
g9(::X9) = 1                                           # no covering match at Q9: a pruned arm
callg(x::Q9) = g9(x)
@assert length(lookup(Tuple{typeof(g9), Q9}).matches) == 1 "a match with no covering one stays"
@assert Base.return_types(callg, (Q9,)) != Any[Union{}] "the arm is not pruned"

# (3) a member in both components: met; the match and the ambiguity return
struct S9 <: Q9 end
mk = which(k9, (X9, Char)); mq = which(k9, (Q9, Char))
@assert !Base.isambiguous(mk, mq) "no value at All{Q9, X9} yet"
Traits.declare_membership(S9, X9, Main)
@assert !unmet(Tuple{typeof(k9), Core.All{Tuple{X9, Q9}}, Char}) "S9 is in both"
# the caller compiled before the membership answers as dispatch does
@assert (try kc(S9()); :none catch e; typeof(e) end) === (try k9(S9(), 'a'); :none catch e; typeof(e) end) "the compiled caller agrees with dispatch"
r = lookup(Tuple{typeof(k9), X9, Char})
@assert r.ambig && length(r.matches) >= 1 "the ambiguity returns: $(r.ambig) $(r.matches)"
@assert Base.isambiguous(mk, mq) "reflection reports it once a value exists"

# (4) E-334, open issue 169: at a set closed after load, an intersection no type is in is a final negative
# with a cell (`AbstractString`, `X20`): `isa` folds to false, a match there is dropped even where it would
# win (`w2(::AbstractString, …)` ranks above `w2(::X20, …)`), no instance is compiled there; a membership
# that meets the intersection opens the cell and invalidates what relied on it
isstr(@nospecialize(x::P20.X20)) = x isa AbstractString
@assert isstr(P20.M20()) === false
let ci = latest(isstr, P20.X20)
    folded = isdefined(ci, :rettype_const) && (ci.rettype_const === false ||
             (ci.rettype_const isa Core.InterConditional && ci.rettype_const.thentype === Union{}))
    @assert folded "isa folds: $(first(only(code_typed(isstr, (P20.X20,)))))"
    @assert any(c -> c.member === AbstractString, finalcells(ci)) "the cell (AbstractString, X20) recorded: $(ci.edges)"
end
cw(@nospecialize(x::P20.X20)) = P20.w2(x, 0x01)
@assert cw(P20.M20()) == 1
let ir = first(only(code_typed(cw, (P20.X20,))))
    @assert !any(st -> Meta.isexpr(st, :call) && any(a -> a isa Type && occursin("All{", string(a)), st.args), ir.code) "no branch at All{AbstractString, X20}: $ir"
end
function validcode(mi)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci isa Core.CodeInstance
        ci.max_world == typemax(UInt) && return true
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return false
end
@assert !any(mi -> unmet(mi.specTypes) && validcode(mi), Base.specializations(which(P20.w2, (AbstractString, UInt8)))) "no valid code at the unmet intersection"
ci = latest(isstr, P20.X20)
Traits.declare_membership(P20.S20, P20.X20, P20)
@assert ci.max_world != typemax(UInt) "the membership meets the intersection: the fold is invalidated"
@assert !unmet(Tuple{typeof(P20.w2), Core.All{Tuple{AbstractString, P20.X20}}, UInt8})

# (5) a `Callable` component is met: its members are the types whose methods match it (C-82)
struct MyS20 <: AbstractString end
(s::MyS20)(x) = 1
f20(::AbstractString, xs...) = :str
f20(::Core.Callable, ::Int) = :callable
@assert !unmet(Tuple{typeof(f20), Core.All{Tuple{AbstractString, Core.Callable}}, Int}) "All{AbstractString, Callable} is met"
@assert lookup(Tuple{typeof(f20), Core.Callable, Int}).ambig "the lookup at (Callable, Int) is ambiguous"
g20(x::Core.Callable) = f20(x, 1)
@assert (try g20(MyS20()); :none catch e; typeof(e) end) === (try f20(MyS20(), 1); :none catch e; typeof(e) end) === MethodError "compiled code and dispatch agree"
@assert Base.isambiguous(which(f20, (AbstractString, Int)), which(f20, (Core.Callable, Int))) "reflection reports the Callable pair"

# (6) a `Vararg` tail is met by its empty tail
w7(::Int, ::X9...) = 1
w7(::Integer, ::AbstractString...) = 2
cw7() = w7(1)
@assert (try cw7(); :none catch e; typeof(e) end) === (try w7(1); :none catch e; typeof(e) end) "the vararg tail: compiled code and dispatch agree"
@assert !unmet(Tuple{typeof(w7), Int, Vararg{Core.All{Tuple{AbstractString, X9}}}}) "an unbounded Vararg is met"

println("n20_unmet_lookup: OK")
