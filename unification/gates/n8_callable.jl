# Gate (W-113; compiler §7.4; traits §9): `Core.Callable{A, S}`. A function is a member where one of its
# methods covers a call at `A`, whatever `S` is; its own methods decide it, read in the query's world.
# Dispatch picks by signature; a method defined later begins a membership and deleting it ends one; a
# call through a value known as `Callable{A, S}` has the result `S`, asserted on return; a question
# that reaches itself answers the same in either order.
using Traits
include("util.jl")
const C = Core.Callable

# membership by methods
@assert typeof(abs) <: C{Tuple{Int}, Int}
@assert typeof(uppercase) <: C{Tuple{String}, String}
@assert !(typeof(uppercase) <: C{Tuple{Int}, Int}) "no method at Int"
@assert typeof(abs) <: C{Tuple{Int}, String} "S takes no part in membership"
@assert typeof(abs) <: C{Tuple{Int}} && typeof(abs) <: C "Callable with S, or both, left open"
@assert abs isa C{Tuple{Int}, Int}

# dispatch picks by the arguments' signature
apply(f::C{Tuple{Int}, Int}, x) = :int
apply(f::C{Tuple{String}, <:AbstractString}, x) = :string
@assert apply(abs, 1) === :int
@assert apply(uppercase, "a") === :string
floatonly(x::Float64) = x                                   # a method at neither Int nor String
@assert try apply(floatonly, "x"); false catch e; e isa MethodError end
@assert apply(sin, "x") === :int "sin is callable at Int (sin(::Real)), whatever its result"

# argument types that follow other arguments
retain(f::C{Tuple{T}, Bool}, xs::Vector{T}) where {T} = filter(f, xs)
@assert retain(iseven, [1, 2, 3, 4]) == [2, 4]

# a method defined later begins a membership, deleting it ends one; compiled code follows
probe(f) = f isa C{Tuple{Int}, Int}
newf(x::Float64) = x
@assert !probe(newf)
newf(x::Int) = x + 1
@assert probe(newf) "the definition began the membership"
@assert apply(newf, 1) === :int
Base.delete_method(which(newf, (Int,)))
@assert !probe(newf) "deleting the method ended it"
@assert try apply(newf, 1); false catch e; e isa MethodError end

# the call through a value known as Callable{A, S}: S, asserted on return
call1(f::C{Tuple{Int}, Int}) = f(1)
@assert call1(abs) == 1
@assert Base.infer_return_type(call1, (C{Tuple{Int}, Int},)) === Int
strresult(x::Int) = "s"
@assert try call1(strresult); false catch e; e isa TypeError end

# a question that reaches itself (E-267's case): the least fixed point, the same in either order
function p end
p(x::C{Tuple{typeof(p)}}) = :callable
p(x::Function) = :function
function q end
q(y::C{Tuple{typeof(q)}}) = :q
r1 = (typeof(q) <: C{Tuple{typeof(p)}}, typeof(p) <: C{Tuple{typeof(p)}})
r2 = (typeof(p) <: C{Tuple{typeof(p)}}, typeof(q) <: C{Tuple{typeof(p)}})
@assert r1 == reverse(r2) "the same answers in either order: $r1, $r2"
@assert r1 == (true, true) "q takes p (p is callable at q as a Function); p takes itself as a Function"

# never a member: the builtins' types and Core's kinds
@assert !(typeof(getfield) <: C{Tuple{Any, Symbol}})

println("n8_callable: OK")
