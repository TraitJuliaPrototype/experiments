# W-145, part 4b (G-4; GT-1, compiler C-88 (c)): what a package's load costs and what it ends.
#     julia --project=<env> load.jl <walk|nowalk> <package> [<package> …]
# The time of `using` (the packages one after another, each timed), Julia's invalidation log around it by
# event (a method's insertion, the membership walk, the walk's conservative pass), the code instances
# ended, by the root module of their method. "nowalk": the membership walk lowers the dispatch caches
# and invalidates no code: a control for the walk's cost (wrong answers can follow; nothing is run after).
mode = popfirst!(ARGS)
mode == "nowalk" && ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), 0)
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
times = Float64[]
for p in ARGS
    push!(times, @elapsed @eval using $(Symbol(p)))
end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
events = Dict{String, Int}(); ended = Dict{String, Int}()
for x in log
    if x isa String
        events[x] = get(events, x, 0) + 1
    elseif x isa Core.CodeInstance
        d = x.def; d isa Core.MethodInstance || (d = d.def)
        m = d.def
        r = string(Base.moduleroot(m isa Method ? m.module : m))
        ended[r] = get(ended, r, 0) + 1
    end
end
println("LOAD ", mode, " ", join(ARGS, "+"), " | ", join((string(p, " ", round(1e3 * t; digits = 1), " ms") for (p, t) in zip(ARGS, times)), ", "),
        " | total ", round(1e3 * sum(times); digits = 1), " ms | log entries ", length(log), " | code instances ended ", sum(values(ended); init = 0))
for (k, v) in sort!(collect(events); by = last, rev = true); println("  EVENT ", v, " ", k); end
for (k, v) in sort!(collect(ended); by = last, rev = true); println("  ENDED ", v, " ", k); end
