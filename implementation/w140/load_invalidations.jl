# W-140: what loading the library invalidates, in a fresh session (a small control, one run).
# Usage: julia --project=<TraitWorld> load_invalidations.jl [nowalk]
# "nowalk": the membership's walk lowers the dispatch caches and invalidates no code (a control: wrong answers follow)
get(ARGS, 1, "") == "nowalk" && ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), 0)
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
t = @elapsed @eval using TraitWorld
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
cis = count(x -> x isa Core.CodeInstance, log)
reasons = Dict{String,Int}()
for x in log
    x isa String && (reasons[x] = get(reasons, x, 0) + 1)
end
println("load ", round(t, digits = 2), " s; log entries ", length(log), "; code instances ", cis)
for (k, v) in sort(collect(reasons), by = last, rev = true)
    println("  ", v, "  ", k)
end
