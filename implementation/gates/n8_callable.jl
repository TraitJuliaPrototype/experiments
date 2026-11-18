# Gate (W-113, rewritten for W-164; compiler §4.3, §7.4 "Memberships"; traits §9; lowering §9): `Core.Callable{A, S}`
# is a set whose members are declared, as any set's. Core's entry makes every `Function` a member of every instance;
# subtyping reads no method, so neither `A` nor `S` takes part in membership, and a method's definition or deletion
# begins or ends none: code compiled on a membership answer stays valid. A callable type that is no `Function` is a
# member only by its declaration. Neither input selects a method: two methods at instances that differ only there
# tie at every function: two instances of one set that differ only in inputs meet as `All{X{A}, X{B}}` (W-165,
# compiler §4.9), and for any set with inputs they meet where they may differ in an input, and are disjoint at the
# same input values. A question that names the function itself is answered from the entries, in either order.
# The runtime's part only, with the stub library: the check at the box (the signature where a function is boxed or
# a wrapper enters, the result on return) is the library's, gated by `n8_callable_box.jl` and `w161/d2/gate.jl`.
using Traits
include("util.jl")
const C = Core.Callable
latest(f) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)])

# every function is a member of every instance, whatever its methods
@assert typeof(abs) <: C{Tuple{Int}, Int}
@assert typeof(uppercase) <: C{Tuple{Int}, Int} "no method of uppercase at Int: a member still"
@assert typeof(abs) <: C{Tuple{Int}, String} "S takes no part in membership"
@assert typeof(abs) <: C{Tuple{Int}} && typeof(abs) <: C "Callable with S, or both, left open"
@assert abs isa C{Tuple{Int}, Int} && uppercase isa C{Tuple{Symbol, Symbol}, Nothing}
function nomethods end
@assert nomethods isa C{Tuple{Int}, Int} "a function with no method at all"
@assert (x -> x) isa C{Tuple{Float64}, Float64} "a closure"
@assert Function <: C{Tuple{Int}, Int} "Core's entry: Function, both inputs free"

# not a member: a type that is no function; a callable type that is no Function, until it is declared
struct Doubler20; end
(::Doubler20)(x::Float64) = 2x
struct Halver20; end
(::Halver20)(x::Float64) = x / 2
@assert !(Int <: C{Tuple{Int}, Int}) && !(1 isa C)
@assert !(Doubler20 <: C{Tuple{Float64}, Float64}) && !(Doubler20() isa C) "a call method makes no membership"
declare_membership(Halver20, C, @__MODULE__)            # the bare set: a member of every instance (lowering §9)
@assert Halver20 <: C{Tuple{Float64}, Float64} && Halver20 <: C{Tuple{String}, Symbol} "declared: every instance"
@assert !(Doubler20 <: C) "the other type stays out"

# a method's definition or deletion begins or ends no membership; code compiled on the answer stays valid
probe(f) = f isa C{Tuple{Int}, Int}
newf(x::Float64) = x
@assert probe(newf)
ci = latest(probe)
newf(x::String) = x
newf(x::Int) = x + 1
@assert probe(newf) && ci.max_world == typemax(UInt) "a method at A invalidates no membership answer"
Base.delete_method(which(newf, (Int,)))
@assert probe(newf) && ci.max_world == typemax(UInt) "deleting it neither"
@assert typeof(newf) <: C{Tuple{Int}, Int}

# the older world answers as the newer: no membership began with a method
oldf(x::Float64) = x
w_before = curworld()
oldf(x::Int) = x + 1
@assert Base.invoke_in_world(w_before, probe, oldf) && probe(oldf)

# neither input selects a method: two methods at instances that differ only in A or S tie at every function
# (traits §9, compiler §4.9, §7.4; W-165, C-147): two instances of one set that differ only in inputs meet as
# `All{X{A}, X{B}}`, met here by every function (Core's entry leaves both inputs free)
apply(f::C{Tuple{Int}, Int}, x) = :int
apply(f::C{Tuple{String}, <:AbstractString}, x) = :string
ma = which(apply, (C{Tuple{Int}, Int}, Any)); mb = which(apply, (C{Tuple{String}, <:AbstractString}, Any))
ti = typeintersect(C{Tuple{Int}, Int}, C{Tuple{String}, String})
@assert ti == Core.All{Tuple{C{Tuple{Int}, Int}, C{Tuple{String}, String}}} "the instances meet: $ti"
@assert !Base.morespecific(ma.sig, mb.sig) && !Base.morespecific(mb.sig, ma.sig) "neither more specific"
@assert Base.isambiguous(ma, mb) "reflection reports the tie"
@assert try apply(abs, 1); false catch e; e isa MethodError end "a call with a function is ambiguous"
@assert try apply(uppercase, "a"); false catch e; e isa MethodError end "whatever the function's methods"
@assert try apply(Halver20(), 1); false catch e; e isa MethodError end "a callable type declared at every instance"
@assert try apply(Doubler20(), 1); false catch e; e isa MethodError && !occursin("ambiguous", sprint(showerror, e)) end "no member: no method, no tie"
# compiled code agrees with dispatch: a caller compiled at a function's type
callapply(f) = apply(f, 1)
@assert try callapply(abs); false catch e; e isa MethodError end "compiled code: the tie"
# a method at the intersection resolves the tie, and is more specific than each
apply(f::Core.All{Tuple{C{Tuple{Int}, Int}, C{Tuple{String}, <:AbstractString}}}, x) = :both
mab = which(apply, (Core.All{Tuple{C{Tuple{Int}, Int}, C{Tuple{String}, String}}}, Any))
@assert Base.morespecific(mab.sig, ma.sig) && Base.morespecific(mab.sig, mb.sig) "the joint method ranks above each"
@assert apply(abs, 1) === :both && callapply(abs) === :both && apply(Halver20(), 1) === :both "resolved"
@assert !Base.isambiguous(ma, mb) "resolved by a method more specific than both"
# instances that differ only in an input that a variable leaves open meet too
@assert typeintersect(C{Tuple{T}, T} where T, C{Tuple{Int}, String}) != Union{} "a variable's input may differ"
@assert typeintersect(C{Tuple{T}, T} where T, C{Tuple{Int}, Int}) == C{Tuple{Int}, Int} "unified where it can be"
# a concrete member is in the instance its entry names: a value of one instance's box meets no other
struct OnlyInt20 end
declare_membership(OnlyInt20, C{Tuple{Int}, Int}, @__MODULE__)
@assert typeintersect(OnlyInt20, C{Tuple{String}, String}) === Union{} && typeintersect(OnlyInt20, C{Tuple{Int}, Int}) === OnlyInt20
@assert apply(OnlyInt20(), 1) === :int "a member of one instance only: its method"

# The rule for any set with inputs (compiler §4.6, §4.9): a set `HP{N, R}` with the input `N` and the other
# parameter `R`. At the same input values, instances that differ in `R` are disjoint (a member has one instance
# there); at different input values they meet, where the entries put a type in both
setinputs!(@nospecialize(T), m::UInt8) = ccall(:jl_set_input_params, Cvoid, (Any, UInt8), T, m)
unmet(T) = ccall(:jl_has_unmet_argument, Cint, (Any, UInt), T, Base.get_world_counter()) != 0
@trait HP20{N, R}
setinputs!(HP20, 0x01)
@trait HQ20{N, R}                                          # no inputs
@assert typeintersect(HP20{:a, Int}, HP20{:a, String}) === Union{} "the same input, another R: disjoint"
@assert typeintersect(HQ20{:a, Int}, HQ20{:b, String}) === Union{} "no inputs: disjoint"
@assert typeintersect(HP20{:a, Int}, HP20{:b, String}) == Core.All{Tuple{HP20{:a, Int}, HP20{:b, String}}} "other inputs: they meet"
@assert typeintersect(HP20{N, Int} where N, HP20{:a, String}) != Union{} "an input left open may differ"
struct Both20 end                                          # a member at both names
struct One20 end                                           # at one only
declare_membership(Both20, HP20{:a, Int}, @__MODULE__)
declare_membership(One20, HP20{:a, Int}, @__MODULE__)
g20(::HP20{:a, Int}) = :a
g20(::HP20{:b, String}) = :b
h20(::HP20{:a, Int}) = :int
h20(::HP20{:a, String}) = :string
@assert !Base.isambiguous(which(h20, (HP20{:a, Int},)), which(h20, (HP20{:a, String},))) "disjoint: no tie"
ga = which(g20, (HP20{:a, Int},)); gb = which(g20, (HP20{:b, String},))
AB = Tuple{typeof(g20), Core.All{Tuple{HP20{:a, Int}, HP20{:b, String}}}}
@assert unmet(AB) && !Base.isambiguous(ga, gb) "no type in both yet: unmet, no tie"
cg(x) = g20(x)
@assert cg(Both20()) === :a && cg(One20()) === :a
ci = only([c for c in all_cis(cg) if c.def.specTypes === Tuple{typeof(cg), Both20} && c.max_world == typemax(UInt)])
# the membership that puts Both20 in both: the report warns at it (compiler §5.4), the intersection is met, the
# call is ambiguous, and the code compiled before it is invalidated
report = mktemp() do path, io
    redirect_stderr(io) do
        declare_membership(Both20, HP20{:b, String}, @__MODULE__)
    end
    close(io); read(path, String)
end
@assert occursin(r"g20 at g20\(.*HP20\{:b, String\}\) is ambiguous for .*Both20", report) && occursin("would resolve it", report) "the report at the membership: $report"
@assert !unmet(AB) && Base.isambiguous(ga, gb) "met: the tie"
@assert ci.max_world != typemax(UInt) "the caller compiled before the membership is invalidated"
@assert try g20(Both20()); false catch e; e isa MethodError end && try cg(Both20()); false catch e; e isa MethodError end "ambiguous"
@assert g20(One20()) === :a && cg(One20()) === :a "a member at one name keeps its method"

# never a member: the builtins' types (compiler §4.1, `never_member`)
@assert !(typeof(getfield) <: C{Tuple{Any, Symbol}}) && typeof(getfield) <: Function
# one method at Callable takes every function; a method at the function's type is more specific
one1(f::C{Tuple{Int}, Int}) = :callable
one1(f::typeof(sin)) = :sin
@assert one1(uppercase) === :callable && one1(sin) === :sin && one1(Halver20()) === :callable
@assert try one1(Doubler20()); false catch e; e isa MethodError end "no member: no method"

# a question that names the function itself (E-267's case): read from entries, the same in either order
function p end
p(x::C{Tuple{typeof(p)}}) = :callable
p(x::Function) = :function
function q end
q(y::C{Tuple{typeof(q)}}) = :q
r1 = (typeof(q) <: C{Tuple{typeof(p)}}, typeof(p) <: C{Tuple{typeof(p)}})
r2 = (typeof(p) <: C{Tuple{typeof(p)}}, typeof(q) <: C{Tuple{typeof(p)}})
@assert r1 == reverse(r2) == (true, true) "every function, in either order: $r1, $r2"

println("n8_callable: OK")
