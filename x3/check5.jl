# E-227 (W-70, the Makie port's finish): the workload's plotting calls, upstream's user API unchanged
# (experiments/ttfx/plotting.jl: Figure, fig[r, c], Axis with xscale = log10, lines!, save with px_per_unit), over
# TraitMakie. Each PNG against the same figure drawn through the core's own functions (bytes), and against upstream
# CairoMakie's PNG of E-168 (size; the share of pixels that differ, reported, not a criterion).
#     julia --project=experiments/x3/env experiments/x3/check5.jl <out dir>
using TraitMakie
const PC = TraitMakie.PlotCore
const Cairo = PC.Cairo
const OUT = isempty(ARGS) ? mktempdir() : ARGS[1]
include(joinpath(@__DIR__, "data", "solutions.jl"))
include(joinpath(@__DIR__, "..", "ttfx", "plotting.jl"))          # plot_two, plot_one: upstream's calls, unchanged
const UP = joinpath(@__DIR__, "..", "ttfx", "out", "png")         # E-168's PNGs (upstream CairoMakie, setting S)

"The pixels of a PNG (ARGB, one UInt32 each), height × width, read from Cairo's image data (TraitMakie's test suite)."
function pixels(path)
    s = Cairo.read_from_png(path)
    w, h = Int(s.width), Int(s.height)
    stride = ccall((:cairo_image_surface_get_stride, Cairo.libcairo), Int32, (Ptr{Nothing},), s.ptr)
    p = ccall((:cairo_image_surface_get_data, Cairo.libcairo), Ptr{UInt32}, (Ptr{Nothing},), s.ptr)
    return permutedims(copy(unsafe_wrap(Array, p, (Int(stride) ÷ 4, h))[1:w, :]))
end
"The same figures through the core's own functions: axes, primitives, the palette's colours, the render."
function core_two(a, b, path)
    f = PC.Figure(800, 600, PC.Axis[])
    a1 = PC.add_axis!(f, 1, 1, identity, identity, "", "", ""); a2 = PC.add_axis!(f, 2, 1, log10, identity, "", "", "")
    for k in 1:3; PC.add_lines!(a1, hcat(a.t, getindex.(a.u, k)), PC.PALETTE[k], 1.5); end
    for k in 1:3; PC.add_lines!(a2, hcat(b.t, getindex.(b.u, k) .* (k == 2 ? 1e4 : 1.0)), PC.PALETTE[k], 1.5); end
    PC.render_png(f, path, 1.0)
end
function core_one(c, path)
    f = PC.Figure(800, 400, PC.Axis[])
    PC.add_lines!(PC.add_axis!(f, 1, 1, identity, identity, "", "", ""), hcat(c.t, getindex.(c.u, 1)), PC.PALETTE[1], 1.5)
    PC.render_png(f, path, 1.0)
end
function compare(name, ours, core, up)
    A, B, U = pixels(ours), pixels(core), pixels(up)
    println("X3S5 $name: equal bytes to the core's own: ", read(ours) == read(core), "; pixels differing: ", count(A .!= B),
            "; size ", size(A, 2), "×", size(A, 1), " (upstream ", size(U, 2), "×", size(U, 1), ")",
            "; pixels not white: $(count(!=(0xffffffff), A))",
            size(A) == size(U) ? "; pixels differing from upstream's: $(round(100 * count(A .!= U) / length(A); digits = 1))%" : "")
end

a, b, c = readsolutions()
plot_two(a, b, joinpath(OUT, "s5-up-1.png")); core_two(a, b, joinpath(OUT, "s5-core-1.png"))
compare("plot_two", joinpath(OUT, "s5-up-1.png"), joinpath(OUT, "s5-core-1.png"), joinpath(UP, "jl-1.png"))
plot_one(c, joinpath(OUT, "s5-up-2.png")); core_one(c, joinpath(OUT, "s5-core-2.png"))
compare("plot_one", joinpath(OUT, "s5-up-2.png"), joinpath(OUT, "s5-core-2.png"), joinpath(UP, "jl-2.png"))

# what the log axis draws: its ticks and labels, for the robertson time range with the 5% margin
lo, hi = log10(first(b.t)), log10(last(b.t)); d = 0.05 * (hi - lo)
tk = PC.scaleticks(log10, lo - d, hi + d, 6)
println("X3S5 log axis: ticks at exponents ", tk, ", labels ", [PC.ticklabel(log10, v) for v in tk])
# the axes' scales are kept values; a scale that does not conform is refused at the bound
fig = Figure(size = (400, 300))
println("X3S5 scales: ", typeof(Axis(fig[1, 1]; xscale = log10).xscale), "; sqrt refused: ",
        try Axis(fig[2, 1]; xscale = sqrt); false catch e; sprint(showerror, e)[1:min(end, 120)] end)
# the palette's cycle per axis; a given colour leaves it
fig = Figure(); ax = Axis(fig[1, 1])
l1 = lines!(ax, [1.0, 2.0], [1.0, 2.0]); l2 = lines!(ax, [1.0, 2.0], [2.0, 1.0]; color = :red); l3 = lines!(ax, [1.0, 2.0], [0.0, 0.0])
println("X3S5 palette: ", PC.rgba(l1.color, 1) == PC.PALETTE[1], " ", PC.rgba(l3.color, 1) == PC.PALETTE[2])
# px_per_unit
p = save(joinpath(OUT, "s5-ppu2.png"), fig; px_per_unit = 2)
println("X3S5 px_per_unit = 2: ", size(pixels(p), 2), "×", size(pixels(p), 1))
