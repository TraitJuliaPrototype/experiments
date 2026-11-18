# Probe: why the lookup at (Callable, Int) reports an ambiguity after dropping the unmet match (C-148)
using Traits
const CC = Base.Compiler
lookup(T) = CC.findall(T, CC.method_table(CC.NativeInterpreter()); limit = -1)
raw(T) = (a = Ref{Int32}(0); mn = Ref{UInt}(0); mx = Ref{UInt}(typemax(UInt));
          r = ccall(:jl_matching_methods, Any, (Any, Any, Cint, Cint, UInt, Ptr{UInt}, Ptr{UInt}, Ptr{Int32}),
                    T, nothing, -1, true, Base.get_world_counter(), mn, mx, a); (r, a[]))
struct MyS20 <: AbstractString end
f20(::AbstractString, xs...) = :str
f20(::Core.Callable, ::Int) = :callable
for T in (Tuple{typeof(f20), Core.Callable, Int}, Tuple{typeof(f20), Core.Callable{Tuple{Int},Int}, Int})
    r = lookup(T)
    println(T, " => ambig=", r.ambig, " n=", length(r.matches))
    rr, a = raw(T)
    println("   raw incl_ambig: ambig=", a, " ", [m.spec_types for m in rr])
end
@trait Z{P}
h(::AbstractString, xs...) = 1
h(::Z, ::Int) = 2
r = lookup(Tuple{typeof(h), Z, Int}); println("bare Z: ambig=", r.ambig, " n=", length(r.matches))
r = lookup(Tuple{typeof(h), Z{1}, Int}); println("Z{1}: ambig=", r.ambig, " n=", length(r.matches))
println("ti = ", typeintersect(Tuple{typeof(f20), Core.Callable, Int}, Tuple{typeof(f20), AbstractString, Vararg}))
println("W-165: ", typeintersect(Core.Callable{Tuple{Int}, Int}, Core.Callable{Tuple{String}, String}))
