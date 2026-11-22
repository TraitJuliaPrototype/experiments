# W-169: does the sampling profiler change a load? `using CSV, DataFrames` timed with Julia's compile timer, with the
# profiler off (none), loaded but stopped (loaded), or running (prof) at the given delay.
#     julia --project=<env_up> profiled_load.jl <none|loaded|prof> [delay=0.001]
mode = ARGS[1]; delay = length(ARGS) > 1 ? parse(Float64, ARGS[2]) : 0.001
mode == "none" || (@eval using Profile; Profile.init(n = 10^7, delay = delay))
Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
t = @elapsed (mode == "prof" ? (@eval Profile.@profile using CSV, DataFrames) : (@eval using CSV, DataFrames))
c1 = Base.cumulative_compile_time_ns()
n = mode == "prof" ? length(Profile.fetch(include_meta = false)) : 0
println("PROFLOAD ", mode, " delay ", delay, " | load ", round(1000t; digits = 1), " ms | compiling ", round((c1[1] - c0[1]) / 1e6; digits = 1),
        " ms, again ", round((c1[2] - c0[2]) / 1e6; digits = 1), " ms | profile entries ", n)
