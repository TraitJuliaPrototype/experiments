# Gate for compiler §7.4 (traits §9): a call of a function known only as `Callable{A, S}` checks its arguments
# against `A`: outside `A` it raises `MethodError`, even where the function has a method there, and
# where inference proves them outside `A` the call infers as never returning. The argument is declared
# `@nospecialize`: compiled once at the set, the code knows the function by its trait only (compiler §6.2; with
# the stub library no forwarder boxes a plain function, which is otherwise compiled for its type).
using Traits
include("util.jl")

g1(x::Int) = x + 1
g1(x::String) = 0                                   # a method outside the signature the caller states
callit(@nospecialize(f::Core.Callable{Tuple{Int}, Int}), x) = f(x) # `x` untyped: the check runs with the call
@assert callit(g1, 1) == 2
@assert (try callit(g1, "s"); false catch e; e isa MethodError end) "outside A: MethodError, not g1(::String)"
callstr(@nospecialize(f::Core.Callable{Tuple{Int}, Int})) = f("s")  # proved outside A
@assert (try callstr(g1); false catch e; e isa MethodError end)
println("n14_callable_args: OK")
