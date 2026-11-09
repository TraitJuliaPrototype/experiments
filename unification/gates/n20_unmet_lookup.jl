# Gate (E-331, E-334; compiler §4.8, §4.9, §5.4): dispatch's lookup takes no match met only at an
# intersection that no type of the world is in, where a covering match exists that it is not more
# specific than. So `w1(::X20, ::Char)` against `w1(s::AbstractString, xs...)`, which meet only at
# `All{AbstractString, X20}`, is one match and no ambiguity, and a call at `X20` is static. A match more
# specific than the covering one stays, as does one with no covering match beside it (a pruned arm a
# later member would reach, §5.6). A member in every component makes the intersection met: the match and
# the ambiguity return, in the lookup and in reflection (`Base.isambiguous`) alike. At a set closed after
# load, such an intersection is a final negative with a cell: `isa` folds, a match there is dropped even
# where it would win, and a membership that meets it invalidates what relied on it.
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

# (2) a type of Main and an open set: the match that would win stays; the one that would tie leaves
abstract type Q9 end
k9(::X9, ::Char) = 1
k9(::Q9, ::Any) = 2                                    # ties with k9(::X9, ::Char) at All{Q9, X9}
@assert length(lookup(Tuple{typeof(k9), X9, Char}).matches) == 1 && !lookup(Tuple{typeof(k9), X9, Char}).ambig
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

println("n20_unmet_lookup: OK")
