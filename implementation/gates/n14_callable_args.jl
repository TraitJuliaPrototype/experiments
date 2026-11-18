# Gate for compiler C-60 (§7.4): a call of a value known as `Callable{A, S}` checks its arguments
# against `A`: outside `A` it raises `MethodError`, even where the function has a method there, and
# where inference proves them outside `A` the call infers as never returning.
using Traits
include("util.jl")

g1(x::Int) = x + 1
g1(x::String) = 0                                   # a method outside the signature the caller states
callit(f::Core.Callable{Tuple{Int}, Int}, x) = f(x) # `x` untyped: the check runs with the call
@assert callit(g1, 1) == 2
@assert (try callit(g1, "s"); false catch e; e isa MethodError end) "outside A: MethodError, not g1(::String)"
callstr(f::Core.Callable{Tuple{Int}, Int}) = f("s")  # proved outside A
@assert (try callstr(g1); false catch e; e isa MethodError end)
println("n14_callable_args: OK")
