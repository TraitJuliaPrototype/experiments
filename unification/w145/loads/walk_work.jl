# W-145, part 4b: does the membership walk at the forks' load cost the first work?
#     julia --project=../../w134/env_forks walk_work.jl <walk|nowalk>
# "nowalk": the walk lowers the dispatch caches and invalidates no code (a control).
ARGS[1] == "nowalk" && ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), 0)
t0 = time(); using CSV, DataFrames; t1 = time()
df = DataFrame(a = rand(100), b = rand(1:5, 100), c = string.(rand(1:5, 100)))
c0 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(true)
a = @elapsed describe(df); b = @elapsed sort(df, :a); c = @elapsed combine(groupby(df, :b), :a => sum)
c1 = Base.cumulative_compile_time_ns()
println(ARGS[1], ": load ", round(t1 - t0; digits = 2), " s | describe ", round(1e3a; digits = 0), " ms | sort ", round(1e3b; digits = 0),
        " ms | groupby-combine ", round(1e3c; digits = 0), " ms | compiling ", round((c1[1] - c0[1]) / 1e6; digits = 0),
        " ms, again after an invalidation ", round((c1[2] - c0[2]) / 1e6; digits = 0), " ms")
