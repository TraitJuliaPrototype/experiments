# E-219 (X3): costs in a fresh process. `core`: TraitMakie's own `stairs`; `old`: upstream's `stairs.jl` through
# MakieCompat; the control (slice 2): `plain`, PlainPlots' own `stairs`; `plainold`, upstream's `stairs.jl` through
# MakieCompatPlain over PlainPlots. The load and the first PNG; then a late `using DataFrames` and the second PNG (another
# figure, the same kind), with the CodeInstances inferred for it. Slice 4 (E-226): `stephist`, upstream's `hist.jl`
# through MakieCompatStats, of an `Observable`; with `--project=experiments/x3/env-nowl` the workloads of MakieCompat
# and MakieCompatStats are off (PrecompileTools' preference, `env-nowl/LocalPreferences.toml`).
#     julia --project=experiments/x3/env experiments/x3/costs.jl <core|old|plain|plainold|stephist> <out dir>
const KIND, OUT = ARGS[1], ARGS[2]
t0 = time()
if KIND in ("core", "old", "stephist")
    @eval using TraitMakie
    KIND == "old" && @eval using MakieCompat
    KIND == "stephist" && @eval using MakieCompatStats
    const LIB = TraitMakie
else
    @eval using PlainPlots
    KIND == "plainold" && @eval using MakieCompatPlain
    const LIB = PlainPlots
end
tload = time() - t0
xs = collect(1.0:10.0); ys = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0, 5.0, 3.0]
hs = [sin(3k) + 0.3 * cos(7k) for k in 1:200]
mk(f) = KIND == "stephist" ? Base.invokelatest(MakieCompatStats.stephist!, f, Base.invokelatest(MakieCompatStats.Observable, hs); bins = 12) :
        KIND == "old" ? Base.invokelatest(MakieCompat.stairs!, f, xs, ys; step = :post) :
        KIND == "plainold" ? Base.invokelatest(MakieCompatPlain.stairs!, f, xs, ys; step = :post) :
        Base.invokelatest(LIB.stairs!, f, xs, ys; step = :post)
t1 = @elapsed (f = Base.invokelatest(LIB.figure); mk(f); Base.invokelatest(LIB.save, joinpath(OUT, "$KIND-1.png"), f))
t2 = @elapsed using DataFrames
new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
t3 = @elapsed (f = Base.invokelatest(LIB.figure); mk(f); Base.invokelatest(LIB.save, joinpath(OUT, "$KIND-2.png"), f))
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
println("X3C ", rpad(KIND * (occursin("nowl", Base.active_project()) ? "-nowl" : ""), 14), "load ", round(tload; digits = 3), " s; first PNG ", round(t1 * 1e3; digits = 1),
        " ms; using DataFrames ", round(t2; digits = 2), " s; second PNG after it ", round(t3 * 1e3; digits = 1),
        " ms, CodeInstances ", count(x -> x isa Core.CodeInstance, new))
