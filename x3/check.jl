# E-219 (X3, slice 1): upstream's `stairs.jl`, unchanged, over TraitMakie through MakieCompat. The old-style
# plot against TraitMakie's own `stairs` (PNGs byte for byte), a change of `step` and `color` after the plot
# is made, and an axis holding both kinds.
#     julia --project=experiments/x3/env experiments/x3/check.jl <out dir>
using MakieCompat, TraitMakie
const OUT = isempty(ARGS) ? mktempdir() : ARGS[1]
xs = collect(1.0:10.0); ys = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0, 5.0, 3.0]
same(a, b) = read(a) == read(b)
for step in (:pre, :post, :center)
    f1 = TraitMakie.figure(); MakieCompat.stairs!(f1, xs, ys; step, color = :red, linewidth = 2.0)
    f2 = TraitMakie.figure(); TraitMakie.stairs!(f2, xs, ys; step, color = :red, linewidth = 2.0)
    a = TraitMakie.save(joinpath(OUT, "old-$step.png"), f1); b = TraitMakie.save(joinpath(OUT, "core-$step.png"), f2)
    println("X3 step $step: old-style PNG equals the core's: ", same(a, b))
end
f1 = TraitMakie.figure(); p = MakieCompat.stairs!(f1, xs, ys)
p.step = :post; p.color = :green
f2 = TraitMakie.figure(); TraitMakie.stairs!(f2, xs, ys; step = :post, color = :green)
println("X3 changed after the plot was made (step, color): ", same(TraitMakie.save(joinpath(OUT, "old-changed.png"), f1),
                                                                   TraitMakie.save(joinpath(OUT, "core-changed.png"), f2)))
TraitMakie.recolor!(f1, 1, :black)
f2 = TraitMakie.figure(); TraitMakie.stairs!(f2, xs, ys; step = :post, color = :black)
println("X3 recolored through the core's trait: ", same(TraitMakie.save(joinpath(OUT, "old-recolor.png"), f1),
                                                         TraitMakie.save(joinpath(OUT, "core-recolor.png"), f2)))
f = TraitMakie.figure(); TraitMakie.lines!(f, xs, ys; color = :gray); MakieCompat.stairs!(f, xs, ys .+ 1)
println("X3 both kinds in one axis: ", isfile(TraitMakie.save(joinpath(OUT, "mixed.png"), f)))
println("X3 the plot's type: ", typeof(p))
# slice 3 (E-223): upstream's `band.jl` unchanged: its own `convert_arguments`, named arguments, `@inherit`, a mesh
# of triangles and stroke lines; compared by pixels (experiments/x3/tools/pngdiff.jl), since the files may differ
xb = collect(range(0, 4pi; length = 60)); lo = cos.(xb) .- 1; hi = sin.(xb) .+ 1
fb1 = TraitMakie.figure(); pb = MakieCompat.band!(fb1, xb, lo, hi; color = (0.12, 0.35, 0.8, 0.3))
fb2 = TraitMakie.figure(); TraitMakie.band!(fb2, xb, lo, hi; color = (0.12, 0.35, 0.8, 0.3))
TraitMakie.save(joinpath(OUT, "old-band.png"), fb1); TraitMakie.save(joinpath(OUT, "core-band.png"), fb2)
println("X3 band saved: old-band.png, core-band.png; the plot's type: ", typeof(pb))
pb.direction = :y
TraitMakie.save(joinpath(OUT, "old-band-y.png"), fb1)
println("X3 band with direction = :y saved after the change")
