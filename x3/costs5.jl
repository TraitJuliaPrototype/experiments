# E-227 (W-70, the Makie port's finish): costs in a fresh process, as the slices measured them. Upstream's user API
# (experiments/ttfx/plotting.jl, unchanged) over TraitMakie: the load, the first PNG of `plot_two` (two axes, one of them
# log10, three lines each) and of `plot_one`; then a late `using DataFrames` and `plot_two` again, with the CodeInstances
# inferred for it. With `--project=experiments/x3/env-nowl5` TraitMakie's workload is off (PrecompileTools' preference).
#     julia --project=experiments/x3/env experiments/x3/costs5.jl <out dir>
const OUT = ARGS[1]
t0 = time()
using TraitMakie
tload = time() - t0
include(joinpath(@__DIR__, "data", "solutions.jl"))
include(joinpath(@__DIR__, "..", "ttfx", "plotting.jl"))
a, b, c = readsolutions()
t1 = @elapsed plot_two(a, b, joinpath(OUT, "c5-1.png"))
t2 = @elapsed plot_one(c, joinpath(OUT, "c5-2.png"))
t3 = @elapsed plot_two(a, b, joinpath(OUT, "c5-3.png"))
tl = @elapsed using DataFrames
new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
t4 = @elapsed plot_two(a, b, joinpath(OUT, "c5-4.png"))
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
println("X3C5 ", rpad("upstream API" * (occursin("nowl", Base.active_project()) ? ", no workload" : ""), 26), "load ", round(tload; digits = 3),
        " s; first plot_two ", round(t1 * 1e3; digits = 1), " ms; plot_one ", round(t2 * 1e3; digits = 1), " ms; plot_two again ",
        round(t3 * 1e3; digits = 1), " ms; using DataFrames ", round(tl; digits = 2), " s; plot_two after it ", round(t4 * 1e3; digits = 1),
        " ms, CodeInstances ", count(x -> x isa Core.CodeInstance, new))
