# Gate (E-331; compiler §4.9, §5.4): dispatch's lookup takes no match met only at an intersection that
# no type of the world is in, where a covering match exists that it is not more specific than. So
# `write(::IO, ::Char)` against `write(filename::AbstractString, …)`, which meet only at
# `All{AbstractString, IO}`, is one match and no ambiguity, and a call at `IO` is static. A match more
# specific than the covering one stays, as does one with no covering match beside it (a pruned arm a
# later member would reach, §5.6). A member in every component makes the intersection met: the match and
# the ambiguity return, in the lookup and in reflection (`Base.isambiguous`) alike.
using Traits
include("util.jl")
const CC = Base.Compiler
lookup(T) = CC.findall(T, CC.method_table(CC.NativeInterpreter()); limit = -1)
unmet(T) = ccall(:jl_has_unmet_argument, Cint, (Any, UInt), T, Base.get_world_counter()) != 0
invokes(f, T) = [st for st in first(only(code_typed(f, T))).code if Meta.isexpr(st, :invoke)]
dyncalls(f, T) = [st for st in first(only(code_typed(f, T))).code
                  if Meta.isexpr(st, :call) && st.args[1] == GlobalRef(Core, :attributed_call)]

# (1) Base: the intersection with no member is unmet; the lookup is one match, unambiguous; the call static
@assert unmet(Tuple{typeof(write), Core.All{Tuple{AbstractString, IO}}, Char})
@assert !unmet(Tuple{typeof(write), IO, Char}) && !unmet(Tuple{typeof(write), Union{Core.All{Tuple{AbstractString, IO}}, IOBuffer}, Char})
r = lookup(Tuple{typeof(write), IO, Char})
@assert !r.ambig && length(r.matches) == 1 "write(::IO, ::Char): $(r.ambig) $(r.matches)"
@assert !lookup(Tuple{typeof(write), IO, String}).ambig
wc(io::IO, c::Char) = write(io, c)
@assert isempty(dyncalls(wc, (IO, Char))) && length(invokes(wc, (IO, Char))) == 1 "static: $(first(only(code_typed(wc, (IO, Char)))))"
pr(b::IOBuffer) = print(b, "ab")
@assert isempty(dyncalls(pr, (IOBuffer,))) "print inlined into a caller that knows the stream: $(first(only(code_typed(pr, (IOBuffer,)))))"

# (2) a type of Main: the match that would win stays; the one that would tie leaves
abstract type Q9 end
k9(::IO, ::Char) = 1
k9(::Q9, ::Any) = 2                                    # ties with k9(::IO, ::Char) at All{Q9, IO}
@assert length(lookup(Tuple{typeof(k9), IO, Char}).matches) == 1 && !lookup(Tuple{typeof(k9), IO, Char}).ambig
f9(::Any) = 0
f9(::IO) = 1                                           # at All{Q9, IO} more specific than f9(::Any)
@assert length(lookup(Tuple{typeof(f9), Q9}).matches) == 2 "a match that would win stays"
g9(::IO) = 1                                           # no covering match at Q9: a pruned arm
callg(x::Q9) = g9(x)
@assert length(lookup(Tuple{typeof(g9), Q9}).matches) == 1 "a match with no covering one stays"
@assert Base.return_types(callg, (Q9,)) != Any[Union{}] "the arm is not pruned"

# (3) a member in both components: met; the match and the ambiguity return
struct S9 <: Q9 end
mk = which(k9, (IO, Char)); mq = which(k9, (Q9, Char))
@assert !Base.isambiguous(mk, mq) "no value at All{Q9, IO} yet"
Traits.declare_membership(S9, IO, Main)
@assert !unmet(Tuple{typeof(k9), Core.All{Tuple{IO, Q9}}, Char}) "S9 is in both"
r = lookup(Tuple{typeof(k9), IO, Char})
@assert r.ambig && length(r.matches) >= 1 "the ambiguity returns: $(r.ambig) $(r.matches)"
@assert Base.isambiguous(mk, mq) "reflection reports it once a value exists"

# (4) E-334, open issue 169: at a set closed after load (`IO`), an intersection no type is in is a final
# negative with a cell (`AbstractString`, `IO`): `isa` folds to false, a match there is dropped even where
# it would win (`write(::AbstractString, …)` ranks above `write(::IO, …)`), no instance is compiled
# there; a membership that meets the intersection opens the cell and invalidates what relied on it
latest(f, T...) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                c.def.specTypes === Tuple{typeof(f), T...}])
finalcells(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal != 0x00]
isstr(io::IO) = io isa AbstractString
@assert isstr(IOBuffer()) === false
let ci = latest(isstr, IO)
    folded = isdefined(ci, :rettype_const) && (ci.rettype_const === false ||
             (ci.rettype_const isa Core.InterConditional && ci.rettype_const.thentype === Union{}))
    @assert folded "isa folds: $(first(only(code_typed(isstr, (IO,)))))"
    @assert any(c -> c.member === AbstractString, finalcells(ci)) "the cell (AbstractString, IO) recorded: $(ci.edges)"
end
w2(io::IO, a::UInt8, b::UInt8) = write(io, a, b)
@assert w2(IOBuffer(), 0x01, 0x02) == 2
let ir = first(only(code_typed(w2, (IO, UInt8, UInt8))))
    @assert !any(st -> Meta.isexpr(st, :call) && any(a -> a isa Type && occursin("All{", string(a)), st.args), ir.code) "no branch at All{AbstractString, IO}: $ir"
end
# an instance compiled there while Base was built stays as an object, its code invalidated once Base
# counts as loaded
function validcode(mi)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci isa Core.CodeInstance
        ci.max_world == typemax(UInt) && return true
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return false
end
@assert !any(mi -> unmet(mi.specTypes) && validcode(mi), Base.specializations(which(write, (AbstractString, UInt8, UInt8)))) "no valid code at the unmet intersection"
module P20
struct S20 <: AbstractString end
end
ccall(:jl_module_set_loaded, Cvoid, (Any,), P20)
ci = latest(isstr, IO)
Traits.declare_membership(P20.S20, IO, P20)
@assert ci.max_world != typemax(UInt) "the membership meets the intersection: the fold is invalidated"
@assert !unmet(Tuple{typeof(write), Core.All{Tuple{AbstractString, IO}}, UInt8})

println("n20_unmet_lookup: OK")
