# W-159 probe: where a package's load goes (the ODE session's load: 2.06 s on the head, 0.59 s at the tag).
#     julia --project=<env> load_profile.jl <Pkg> [<Pkg> ...]
# Times `using TraitWorld`, then each package, the second under the profiler (1 ms); prints the leaf frames and the
# frames of TraitWorld and Base.loading by inclusive samples, and the instances compiled during the load.
using Profile
t = @elapsed @eval using TraitWorld; println("using TraitWorld ", round(1000t; digits = 1), " ms")
Profile.init(n = 10^7, delay = 0.001)
for p in ARGS
    local t, c0, c1
    Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
    t = @elapsed @eval @profile using $(Symbol(p))
    c1 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(false)
    println("using ", p, " ", round(1000t; digits = 1), " ms, compiling ", round((c1[1] - c0[1]) / 1e6; digits = 1), " ms, of it recompiling ", round((c1[2] - c0[2]) / 1e6; digits = 1), " ms")
end
Profile.print(IOContext(stdout, :displaysize => (1000, 230)); format = :flat, sortedby = :count, mincount = 20, C = true)
