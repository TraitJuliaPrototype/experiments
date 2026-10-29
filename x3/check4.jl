# E-226 (X3, slice 4): upstream's `hist.jl`, unchanged, in MakieCompatStats. `stephist` → `stairs` → `lines`: a recipe
# whose `plot!` calls another recipe with its own `Attributes`. Each old-style PNG against TraitMakie's own `stairs`
# through the step points StatsBase gives for the same edges (bytes; pixels where the bytes differ). `Observable`s as an
# argument and an attribute; `Attributes` as an argument, as keywords and as the plot's own.
#     julia --project=experiments/x3/env experiments/x3/check4.jl <out dir>
using MakieCompat, MakieCompatStats, TraitMakie, StatsBase
const Cairo = TraitMakie.PlotCore.Cairo                 # the core's Cairo, for the pixel comparison
const OUT = isempty(ARGS) ? mktempdir() : ARGS[1]

# the image surface's own data, by its stride (tools/pngdiff.jl; fixed 2026-10-29, E-227)
function pixels(path)
    s = Cairo.read_from_png(path)
    w, h = Int(s.width), Int(s.height)
    stride = ccall((:cairo_image_surface_get_stride, Cairo.libcairo), Int32, (Ptr{Nothing},), s.ptr)
    d = ccall((:cairo_image_surface_get_data, Cairo.libcairo), Ptr{UInt32}, (Ptr{Nothing},), s.ptr)
    return vec(copy(unsafe_wrap(Array, d, (Int(stride) ÷ 4, h))[1:w, :]))
end
"Save both figures; equal by bytes, else the number of pixels that differ."
function compare(name, fold, fcore)
    a = TraitMakie.save(joinpath(OUT, "s4-old-$name.png"), fold)
    b = TraitMakie.save(joinpath(OUT, "s4-core-$name.png"), fcore)
    read(a) == read(b) && return println("X3S4 $name: equal bytes: true")
    d = count(pixels(a) .!= pixels(b))
    println("X3S4 $name: equal bytes: false; pixels differing: $d")
end

# TraitMakie's own `stairs` through the step points of upstream's `stephist`: edges by `pick_hist_edges` (`bins`
# equal bins, the last edge `nextfloat` of the maximum), heights by StatsBase, a phantom edge back to zero
function steppoints(x, bins; normalization = :none)
    mi, ma = extrema(x)
    edges = range(mi, nextfloat(ma); length = bins + 1)
    w = Float64.(StatsBase.normalize(fit(Histogram, x, edges); mode = normalization).weights)
    return vcat(edges, edges[end]), vcat(0.0, w, 0.0)
end
function core(x; bins = 15, normalization = :none, step = :pre, color = :blue)
    f = TraitMakie.figure()
    xs, ys = steppoints(x, bins; normalization)
    TraitMakie.stairs!(f, xs, ys; step, color)
    return f
end

x = [sin(3k) + 0.3 * cos(7k) for k in 1:200]
y = [2sin(k)^2 for k in 1:150]
z = [cos(0.1k)^3 for k in 1:150]

f = TraitMakie.figure(); p = stephist!(f, x)
compare("default", f, core(x))
println("X3S4 the tree: ", nameof(typeof(p).parameters[1].instance), " → ",
        join(map(c -> c isa MakieCompat.Plot ? string(nameof(typeof(c).parameters[1].instance)) : "leaf $(c.kind)", p.children), ", "),
        " → ", join(map(c -> c isa MakieCompat.Plot ? "plot" : "leaf $(c.kind)", p.children[1].children), ", "))
println("X3S4 types: ", typeof(p), "; child ", typeof(p.children[1]))

f = TraitMakie.figure(); stephist!(f, x; bins = 8, normalization = :pdf)
compare("pdf", f, core(x; bins = 8, normalization = :pdf))

# the parent's attributes changed after the plot is made: the child takes them by reference
p.bins = 5; p.step = :post; p.color = :red
f = TraitMakie.figure(); TraitMakie.plot!(f, p)
compare("changed", f, core(x; bins = 5, step = :post, color = :red))

# an Observable argument: replaced, then changed in place and notified
obs = Observable(x)
f = TraitMakie.figure(); po = stephist!(f, obs; bins = 10)
compare("obs-1", f, core(x; bins = 10))
obs[] = copy(y)
compare("obs-replaced", f, core(y; bins = 10))
obs[] .= z
compare("obs-mutated-unnotified", f, core(y; bins = 10))   # not followed before the notification, as upstream
notify(obs)
compare("obs-notified", f, core(z; bins = 10))

# an Observable attribute
col = Observable(:green)
f = TraitMakie.figure(); stephist!(f, x; color = col)
compare("obs-color-1", f, core(x; color = :green))
col[] = :purple
compare("obs-color-2", f, core(x; color = :purple))

# Attributes: as an argument, splatted as keywords, the plot's own by reference, and an argument through `p[1]`
a = Attributes(bins = 6, color = :orange)
f = TraitMakie.figure(); stephist!(f, a, x)
compare("attrs-arg", f, core(x; bins = 6, color = :orange))
f = TraitMakie.figure(); pa = stephist!(f, x; a...)
compare("attrs-kw", f, core(x; bins = 6, color = :orange))
Attributes(pa)[:bins][] = 4
compare("attrs-own", f, core(x; bins = 4, color = :orange))
pa[1][] = y
compare("arg-replaced", f, core(y; bins = 4, color = :orange))

# `stairs` of a StatsBase histogram, by `hist.jl`'s own `convert_arguments(::Type{Stairs}, ::Histogram)`
h = fit(Histogram, x, -1.5:0.25:1.5)
f = TraitMakie.figure(); MakieCompat.stairs!(f, h)
xs = Float64.(h.edges[1]); push!(xs, xs[end])
ys = map(w -> w == 0 ? eps(Float64) : Float64(w), h.weights); pushfirst!(ys, eps()); push!(ys, eps())
g = TraitMakie.figure(); TraitMakie.stairs!(g, xs, ys)
compare("histogram-conversion", f, g)

# both kinds and both depths in one axis
f = TraitMakie.figure(); TraitMakie.lines!(f, [-1.0, 1.0], [0.0, 20.0]; color = :gray)
MakieCompat.stairs!(f, collect(-1.0:0.5:1.0), [1.0, 5.0, 3.0, 8.0, 2.0]); stephist!(f, x; color = :red)
println("X3S4 three kinds in one axis: ", isfile(TraitMakie.save(joinpath(OUT, "s4-mixed.png"), f)))

# the cases differ from each other (a check that equal files are not trivially so)
println("X3S4 distinct PNGs among the old-style cases: ", length(unique(read.(filter(n -> occursin("s4-old-", n), readdir(OUT; join = true))))),
        " of ", count(n -> occursin("s4-old-", n), readdir(OUT)))
