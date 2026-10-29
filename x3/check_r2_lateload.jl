# E-240 (W-32 R2, the Makie side): the old-API leaves' path after a late load. Calls as GraphMakie's recipe makes them
# (a recipe's `scatter!` leaf with numbers through a colormap, a `lines!` leaf given the compute graph with a colour per
# point and NaN breaks), the user API's `lines!` of an `Observable`, `hidedecorations!`, `limits!`; then `using
# DataFrames` and the same calls again, with the CodeInstances inferred for them (none expected).
#     julia --project=experiments/x3/env experiments/x3/check_r2_lateload.jl <out dir>
using MakieCompat
const OUT = ARGS[1]
function oldleaves(path, k)
    fig = Figure(size = (400, 300))
    ax = Axis(fig[1, 1])
    q = stairs!(ax, collect(1.0:5.0), [1.0, 3.0, 2.0, 4.0, 3.0])
    scatter!(q, Point2f[(1, 1), (2, 3), (3, 2)]; color = [0.0, 0.5, 1.0] .+ k, colormap = :balance, markersize = 14)
    lines!(q, q.attributes, Point2f[(1, 1), (2, 3), (NaN, NaN), (3, 2), (4, 4)]; color = [0.0, 0.5, 1.0, 1.0, 0.2])
    hidedecorations!(ax)
    obs = Observable(Point2f[(0, 0), (1, 1)])
    a2 = Axis(fig[1, 2])
    lines!(a2, obs)
    limits!(a2, 0, 2, 0, 2)
    save(path, fig)
    obs[] = Point2f[(0, 1), (2, 0)]
    save(path, fig)
    return nothing
end
t1 = @elapsed oldleaves(joinpath(OUT, "r2-late-1.png"), 0)
t2 = @elapsed oldleaves(joinpath(OUT, "r2-late-2.png"), 1)
tl = @elapsed using DataFrames
new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
t3 = @elapsed oldleaves(joinpath(OUT, "r2-late-3.png"), 2)
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
cis = filter(x -> x isa Core.CodeInstance, new)
println("X3R2 old-API leaves: first ", round(t1 * 1e3; digits = 1), " ms; again ", round(t2 * 1e3; digits = 1),
        " ms; using DataFrames ", round(tl; digits = 2), " s; after it ", round(t3 * 1e3; digits = 1), " ms, CodeInstances ", length(cis))
for ci in first(cis, 20)
    println("X3R2   ", ci.def)
end
