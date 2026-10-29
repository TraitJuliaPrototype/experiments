# E-228 (W-70): the plotting part of an E-168-style session over upstream's user API (experiments/ttfx/plotting.jl,
# unchanged) and TraitMakie: marks "T <step> <epoch s> <compile s>" as E-168's; the solutions read from data/ (not
# timed as plotting). The shell prints the epoch before the process starts (session5.sh).
#     julia --project=experiments/x3/env experiments/x3/session5.jl <out dir>
Base.cumulative_compile_timing(true)
mark(step) = println("T ", step, " ", repr(time()), " ", Base.cumulative_compile_time_ns()[1] / 1e9)
mark("start")
using TraitMakie
mark("load")
include(joinpath(@__DIR__, "data", "solutions.jl"))
include(joinpath(@__DIR__, "..", "ttfx", "plotting.jl"))
const OUT = ARGS[1]
a, b, c = readsolutions()
mark("data")
plot_two(a, b, joinpath(OUT, "tm-1.png"))
mark("plot1")
plot_one(c, joinpath(OUT, "tm-2.png"))
mark("plot2")
plot_two(a, b, joinpath(OUT, "tm-3.png"))
mark("again")
