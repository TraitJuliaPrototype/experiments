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
