# E-281: what loading TraitWorld invalidates, after plain code that calls the functions BaseTraits'
# operations name. Usage: julia --project=<TraitWorld-unified worktree> e281.jl
using LinearAlgebra
A = [4.0 1.0; 1.0 3.0]; x = [1.0, 2.0]; y = zeros(2)
mul!(y, A, x); s = sum(x); d = Dict("a" => 1); haskey(d, "a"); get(d, "b", 0); length(x); firstindex(x)
v = [1, 2, 3]; resize!(v, 2); v[1] = 5; size(A); for z in x; end
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
t = @elapsed using TraitWorld
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
mis = [x for x in log if x isa Core.MethodInstance]
byf = Dict{Any,Int}()
for mi in mis
    f = mi.def isa Method ? mi.def.name : :toplevel
    byf[f] = get(byf, f, 0) + 1
end
println("load: ", round(t, digits = 2), " s; method instances invalidated: ", length(mis))
for (f, n) in sort(collect(byf), by = last, rev = true)
    println("  ", f, ": ", n)
end
println("after the load, mul! at a matrix: ", (mul!(y, A, x); y == A * x))
