# Gate for compiler C-54 (§6.2, §6.3): a trait argument whose type names the method's variables
# (`Callable{Tuple{T}, T}` with `T` from another argument) takes its attribute as any trait argument:
# `Callable`'s default `Dynamic` compiles the method once at the instance with the variables' values,
# `Callable{Tuple{Int}, Int}`, shared by every function; `keep` gives the value as a `Dynamic` there.
using Traits
include("util.jl")

f1(x) = x + 1
f2(x) = x + 2
kept(f::Core.Callable{Tuple{T}, T}, x::T) where {T} = Core.keep(f)
r1 = kept(f1, 1)
r2 = kept(f2, 1)
@assert r1 isa Core.Dynamic "compiled once: keep gives a Dynamic ($(typeof(r1)))"
@assert r2 isa Core.Dynamic
erased = Core.Callable{Tuple{Int}, Int}
mis = [mi for mi in Base.specializations(only(methods(kept))) if mi !== nothing]
@assert count(mi -> mi.specTypes.parameters[2] === erased, mis) == 1 "one instance at the erased key: $([mi.specTypes for mi in mis])"
@assert !any(mi -> mi.specTypes.parameters[2] in (typeof(f1), typeof(f2)), mis) "no instance per function"
# a cast still decides: Compiled gives the function itself
kc(f::Core.Callable{Tuple{T}, T}, x::T) where {T} = Core.keep(f)
@assert kc(compiled_for(f1), 1) === f1 "a cast to Compiled keeps the function itself"
println("n13_attribute_free_vars: OK")
