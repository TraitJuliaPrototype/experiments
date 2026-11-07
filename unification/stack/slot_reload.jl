# E-283 (3b), E-261's shape on the unified build: work, a load that invalidates, the same work again.
# The work is plain Base code (a Dict, sorting, printing, a matrix product, a sum over a vector); the
# load is TraitWorld with BaseTraits, which puts methods at sets on Base's and LinearAlgebra's
# functions. Counted: the CodeInstances the load invalidates (Julia's invalidation log), the callers it
# marks, and after the second round of work those kept and those whose mark became final; timed: the
# second round. Run with JULIA_CODE_SLOT=1 and =0, each with a depot of its own (TraitWorld compiled).
# Usage: JULIA_CODE_SLOT=1 julia --project=TraitWorld-unified slot_reload.jl
stat(k) = Int(ccall(:jl_code_slot_stat, Csize_t, (Cint,), k))
function work()
    d = Dict(string(i) => i for i in 1:200)
    v = sort!(collect(keys(d)); by = length)
    io = IOBuffer()
    show(io, v[1:10]); print(io, d["7"]); show(io, MIME"text/plain"(), d)
    A = [Float64(i + j) for i in 1:6, j in 1:6]
    B = A * A
    x = sum(abs2, B) + sum(values(d)) + length(String(take!(io)))
    s = Set(v); x += length(s)
    return x
end
r1 = work()
t1 = @elapsed work()
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
m0, k0, f0 = stat(0), stat(1), stat(2)
@eval using TraitWorld
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
invalidated = count(x -> x isa Core.MethodInstance, log)
m1 = stat(0)
t2 = @elapsed r2 = work()
@assert r1 == r2
k2, f2 = stat(1), stat(2)
println("JULIA_CODE_SLOT=", get(ENV, "JULIA_CODE_SLOT", "1"), ": the load's log names ", invalidated,
        " MethodInstances; marked ", m1 - m0, "; after the work again: kept ", k2 - k0, ", final ", f2 - f0,
        "; the work again ", round(t2; digits = 3), " s (warm ", round(t1; digits = 4), " s)")
