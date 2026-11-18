# Gate (W-113, C-63; compiler §7.4; traits §9): `Core.Callable{A, S}`. A function is a member where one of its
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

# a match through Callable holds in the worlds of the member's methods (C-63): the dispatch cache
# entry made after the method's definition is not used by a call in a world before it
oldf(x::Float64) = x
w_before = curworld()
oldf(x::Int) = x + 1
@assert apply(oldf, 1) === :int
@assert try Base.invoke_in_world(w_before, apply, oldf, 1); false catch e; e isa MethodError end "the older world: no member"

# the call through a value known as Callable{A, S}: S, asserted on return
call1(f::C{Tuple{Int}, Int}) = f(1)
@assert call1(abs) == 1
@assert Base.infer_return_type(call1, (C{Tuple{Int}, Int},)) === Int
strresult(x::Int) = "s"
@assert try call1(strresult); false catch e; e isa TypeError end

# the declaration decides the check, not what the instance knows of the function (compiler §7.4): an
# instance compiled for the function's type, and one that has the function as a constant, check the
# arguments against `A` and assert `S` as the instance compiled once does
raises(f, E) = try f(); false catch e; e isa E end
viaconst() = call1(strresult)                       # the function a constant of the caller
viacompiled() = call1(compiled_for(strresult))      # compiled for typeof(strresult)
viadynamic() = call1(with_dynamic(strresult))
@assert raises(viaconst, TypeError) && raises(viacompiled, TypeError) && raises(viadynamic, TypeError) "S asserted under every attribute"
call2(f::C{Tuple{Float64}, Float64}, x::Float64) = f(x) + 1     # the result used, not returned
intresult(x::Float64) = 1
@assert raises(() -> call2(intresult, 1.0), TypeError) && raises(() -> call2(compiled_for(intresult), 1.0), TypeError)
okresult(x::Float64) = 2x
@assert call2(okresult, 1.0) == call2(compiled_for(okresult), 1.0) == call2(with_dynamic(okresult), 1.0) == 3.0
# the arguments: a call outside `A` raises `MethodError` though the function has a method for it
wide(x) = 1
callwide(f::C{Tuple{Int}, Int}) = f(1.5)
@assert raises(() -> callwide(wide), MethodError) && raises(() -> callwide(compiled_for(wide)), MethodError) &&
        raises(() -> callwide(with_dynamic(wide)), MethodError) "A checked under every attribute"
# with the method's variables: `S` at the instance's values
samet(f::C{Tuple{T}, T}, x::T) where {T} = f(x)
@assert samet(compiled_for(okresult), 1.0) == 2.0 && raises(() -> samet(compiled_for(intresult), 1.0), TypeError)

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
