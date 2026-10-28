# E-219 (X3, slice 1): costs in a fresh process. `core`: TraitMakie's own `stairs`; `old`: upstream's `stairs.jl`
# through MakieCompat. The load and the first PNG; then a late `using DataFrames` and the second PNG (another
# figure, the same kind), with the CodeInstances inferred for it.
#     julia --project=experiments/x3/env experiments/x3/costs.jl <core|old> <out dir>
const KIND, OUT = ARGS[1], ARGS[2]
t0 = time()
using TraitMakie
KIND == "old" && @eval using MakieCompat
tload = time() - t0
xs = collect(1.0:10.0); ys = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0, 5.0, 3.0]
mk(f) = KIND == "old" ? Base.invokelatest(MakieCompat.stairs!, f, xs, ys; step = :post) : TraitMakie.stairs!(f, xs, ys; step = :post)
t1 = @elapsed (f = TraitMakie.figure(); mk(f); TraitMakie.save(joinpath(OUT, "$KIND-1.png"), f))
t2 = @elapsed using DataFrames
new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
t3 = @elapsed (f = TraitMakie.figure(); mk(f); TraitMakie.save(joinpath(OUT, "$KIND-2.png"), f))
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
println("X3C ", rpad(KIND, 5), "load ", round(tload; digits = 3), " s; first PNG ", round(t1 * 1e3; digits = 1),
        " ms; using DataFrames ", round(t2; digits = 2), " s; second PNG after it ", round(t3 * 1e3; digits = 1),
        " ms, CodeInstances ", count(x -> x isa Core.CodeInstance, new))
