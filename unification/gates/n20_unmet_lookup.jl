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

println("n20_unmet_lookup: OK")
