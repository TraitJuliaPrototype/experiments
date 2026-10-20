# Rows 1, 4 and 6 of the README in one fresh process, with big loads before, after or not at all.
#
#     JULIA_LOAD_PATH="<env with TraitMakie>:<env with CSV, DataFrames, CairoMakie>:@stdlib" \
#         julia --startup-file=no scripts/rows.jl none|before|after
#
# "after": CSV, DataFrames and CairoMakie load after the first PNG, before rows 4 and 6.
# Each line is one first call: "row <n> <what> <ms>".
const LOADS = ARGS[1]
load_big() = (t = @elapsed(@eval Main using CSV, DataFrames, CairoMakie); println("loads ", round(t; digits = 2), " s"))
LOADS == "before" && load_big()
row(n, what, r) = println("row ", n, " ", rpad(what, 44), lpad(round(1000r.time; digits = 1), 7), " ms, compile ", lpad(round(1000r.compile_time; digits = 1), 6), " ms, recompile ", round(1000r.recompile_time; digits = 1), ", gc ", round(1000r.gctime; digits = 1))
row(1, "using TraitMakie", @timed @eval using TraitMakie, TraitWorld)
const TM = TraitMakie                     # qualified: CairoMakie exports lines, scatter!, save too
const OUT = mktempdir()
xs = collect(range(0.0, 2pi; length = 100))
row(1, "first PNG: lines, scatter, save", @timed (f = TM.lines(xs, sin.(xs); title = "t"); TM.scatter!(f, xs, cos.(xs); color = :red); TM.save(joinpath(OUT, "a.png"), f)))
LOADS == "after" && load_big()

@eval struct Trajectory; name::String; pts::Vector{NTuple{2,Float64}}; end
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
r4 = @timed @eval @implement TM.Positions Trajectory by pts
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
row(4, "a new data type: @implement (forwarding)", r4)
sh(x) = x isa Core.MethodInstance ? "MI " * first(string(x.specTypes), 150) : x isa Core.CodeInstance ? "CI " * first(string((x.def isa Core.MethodInstance ? x.def : x.def.def).specTypes), 150) * " owner=" * repr(x.owner) : x isa Method ? "METHOD " * string(x.module) * "." * string(x.name) * " " * first(string(x.sig), 150) : first(repr(x), 150)
println("invalidation log: ", length(invs), " entries")
for (i, x) in enumerate(invs); i > 60 && break; println("  ", lpad(i, 3), " ", sh(x)); end
exit()
tr = Trajectory("w", [(Float64(i), Float64(i)^2) for i in 1:20])
row(4, "a new data type: first PNG", @timed TM.save(joinpath(OUT, "b.png"), TM.lines(tr)))
@eval struct Gradient; from::NTuple{4,Float64}; to::NTuple{4,Float64}; n::Int; end
@eval TraitMakie.rgba(g::Gradient, i::Int) = (t = (i - 1) / max(g.n - 1, 1); g.from .+ t .* (g.to .- g.from))
row(4, "a new colour type: @implement", @timed @eval @implement TM.ColorSpec Gradient)
g = Gradient((1.0, 0.0, 0.0, 1.0), (0.0, 0.0, 1.0, 1.0), length(xs))
f2 = TM.lines(tr; color = (0.1, 0.5, 0.2))
row(4, "a new colour type: first PNG", @timed (TM.scatter!(f2, xs, sin.(xs); color = g); TM.save(joinpath(OUT, "c.png"), f2)))

row(6, "render", @timed TM.save(joinpath(OUT, "d.png"), f2))
row(6, "recolor to a vector, render", @timed (TM.recolor!(f2, 2, [(0.1, 0.2, 0.3, 1.0) for _ in xs]); TM.save(joinpath(OUT, "e.png"), f2)))
row(6, "recolor to :purple, render", @timed (TM.recolor!(f2, 2, :purple); TM.save(joinpath(OUT, "f.png"), f2)))
row(6, "recolor plot 1 to a Gradient, render", @timed (TM.recolor!(f2, 1, Gradient((0.0, 0.0, 0.0, 1.0), (1.0, 1.0, 1.0, 1.0), 20)); TM.save(joinpath(OUT, "g.png"), f2)))
