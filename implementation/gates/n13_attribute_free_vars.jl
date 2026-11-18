# Gate for compiler C-54 (§6.2, §6.3): a trait argument declared `@nospecialize` whose type names the method's
# variables (`Callable{Tuple{T}, T}` with `T` from another argument) is compiled once at the instance with the
# variables' values, `Callable{Tuple{Int}, Int}`, shared by every function: what a forwarder at such an argument
# needs. A caller that knows the function's type calls that instance statically. Without `@nospecialize` the argument
# is compiled as Julia compiles it, per function (the stub library makes no forwarder).
using Traits
include("util.jl")

f1(x) = x + 1
f2(x) = x + 2
once(@nospecialize(f::Core.Callable{Tuple{T}, T}), x::T) where {T} = f(x)
pertype(f::Core.Callable{Tuple{T}, T}, x::T) where {T} = f(x)
@assert once(f1, 1) == 2 && once(f2, 1) == 3 && pertype(f1, 1) == 2 && pertype(f2, 1) == 3
erased = Core.Callable{Tuple{Int}, Int}
insts(fn) = [mi.specTypes.parameters[2] for mi in Base.specializations(only(methods(fn))) if mi !== nothing && isdefined(mi, :cache)]
@assert insts(once) == [erased] "one instance at the erased key: $(insts(once))"
@assert sort!(string.(insts(pertype))) == sort!(string.([typeof(f1), typeof(f2)])) "per function: $(insts(pertype))"
# a caller that knows the function: a static call of the instance at the erased key
callonce(x::Int) = once(f1, x)
@assert callonce(1) == 2
inv = [st for st in first(only(code_typed(callonce, (Int,)))).code if Meta.isexpr(st, :invoke)]
@assert any(st -> (st.args[1] isa Core.CodeInstance ? st.args[1].def : st.args[1]).specTypes.parameters[2] === erased, inv) ||
        isempty(inv) "the call reaches the instance at the erased key: $inv"
println("n13_attribute_free_vars: OK")
