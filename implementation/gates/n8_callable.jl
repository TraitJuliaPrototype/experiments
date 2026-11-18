# Gate (W-113, rewritten for W-164; compiler §4.3, §7.4 "Memberships"; traits §9; lowering §9): `Core.Callable{A, S}`
# is a set whose members are declared, as any set's. Core's entry makes every `Function` a member of every instance;
# subtyping reads no method, so neither `A` nor `S` takes part in membership, and a method's definition or deletion
# begins or ends none: code compiled on a membership answer stays valid. A callable type that is no `Function` is a
# member only by its declaration. Neither input selects a method: two methods at instances that differ only there
# tie at every function. A question that names the function itself is answered from the entries, in either order.
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
# (traits §9, compiler §7.4). EXPECTED FAILURE on `next` a5bd871cce (found by W-164, no deviation row yet): the
# intersection of two instances at other input values is `Union{}` (the parameters' invariance), though every
# function is in both; dispatch then takes one method without a tie (`apply(abs, 1) === :string`) and reflection
# reports none. The check asserts the defect, so that its fix fails here: then assert the tie (the lines below).
apply(f::C{Tuple{Int}, Int}, x) = :int
apply(f::C{Tuple{String}, <:AbstractString}, x) = :string
tie = Base.isambiguous(which(apply, (C{Tuple{Int}, Int}, Any)), which(apply, (C{Tuple{String}, <:AbstractString}, Any)))
abs_tie = try apply(abs, 1); false catch e; e isa MethodError end
upp_tie = try apply(uppercase, "a"); false catch e; e isa MethodError end
@assert !tie && !abs_tie && !upp_tie && typeintersect(C{Tuple{Int}, Int}, C{Tuple{String}, String}) === Union{} "the defect is fixed: assert the tie (tie && abs_tie && upp_tie) and retire this expected failure"
println("n8_callable: expected failure: two methods at Callable instances that differ only in A or S do not tie (apply(abs, 1) === $(repr(apply(abs, 1))))")
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
