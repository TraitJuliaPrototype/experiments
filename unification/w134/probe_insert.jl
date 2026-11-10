# E-356, the follow-up: which plain callers does a method at an open set end when it is added?
# Callers of `length` at a concrete type, at a struct family, at an abstract type and at `Any`,
# compiled (as callees of a caller that holds the argument in a typed field) before the library
# (BaseTraits' `length(::HasLength)`) is loaded.
#     julia --project=env_lib probe_insert.jl
struct P{T}; x::T; end
Base.length(p::P) = 1
abstract type A end
struct C <: A end
Base.length(::C) = 2
@noinline f(x) = length(x) + 1
k(r::Base.RefValue) = f(r[])
cases = [P{Int}, P, A, Any, Vector{Int}, AbstractVector{Int}, AbstractVector, Dict{Symbol,Int}, AbstractDict, Tuple{Int,Int}, Tuple, String, AbstractString]
for T in cases; r = Ref{T}(); Base.return_types(k, (typeof(r),)); precompile(k, (typeof(r),)); end
allci() = [(mi.specTypes, mi.cache) for mi in Base.specializations(only(methods(f))) if mi isa Core.MethodInstance && isdefined(mi, :cache)]
before = allci()
@eval using TraitWorld
for (s, c) in before
    println(rpad(string(s.parameters[2]), 22), " inferred ", rpad(c.rettype, 6), c.max_world == typemax(UInt) ? " kept" : " ENDED")
end
