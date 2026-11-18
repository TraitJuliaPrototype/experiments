# A typical plotting session with upstream packages only (no trait code), in the order a user
# works: load the table packages and read data; load analysis packages and read again; load the
# plotting package, make plots, render, edit them; then repeat the whole round. Each phase is timed
# with @timed, which separates compile time and recompile time from run time.
# Usage: julia plotwork.jl <csv> <reps> <outdir> <analysis loads...>
const CSVPATH = ARGS[1]; const REPS = parse(Int, ARGS[2]); const OUT = ARGS[3]; const LOADS = ARGS[4:end]
const MODE = Base.JLOptions().image_file |> unsafe_string |> p -> occursin("facts", p) ? "all" : "plain"
const T0 = time()
row(phase, i, t) = println("ROW ", MODE, ' ', phase, ' ', i, ' ',
    round(t.time * 1e3; digits = 2), ' ', round(t.compile_time * 1e3; digits = 2), ' ',
    round(t.recompile_time * 1e3; digits = 2), ' ', t.bytes)

const ORDER = get(ENV, "PLOTWORK_ORDER", "interleaved")
if ORDER == "together"
    # Plain Julia's best case: every package loaded before any work, so nothing compiled is lost.
    t = @timed begin
        @eval using CSV, DataFrames, Statistics, CairoMakie
        for L in LOADS; @eval using $(Symbol(L)); end
    end
    row("load-all", 0, t)
else
    t = @timed @eval using CSV, DataFrames, Statistics
    row("load-tables", 0, t)
end

function read_data(path)
    df = CSV.read(path, DataFrame)
    df.xy = df.x .* df.y
    transform!(df, [:x, :y] => ByRow((a, b) -> a > 5 ? b : -b) => :yflip)
    sub = filter(r -> r.flag == false && r.n > 10, df)
    g = combine(groupby(sub, :group), :y => mean => :ymean, :y => std => :ystd, nrow => :count)
    sort!(g, :ymean)
    return df, sub, g
end

function make_plots(df, sub, g)
    fig = Figure(size = (1200, 800))
    ax1 = Axis(fig[1, 1]; title = "scatter", xlabel = "x", ylabel = "y")
    sc = scatter!(ax1, Point2f.(sub.x, sub.y); color = sub.n, markersize = 3)
    Colorbar(fig[1, 2], sc)
    ax2 = Axis(fig[1, 3]; title = "lines by group")
    ls = Any[]
    for (k, part) in pairs(groupby(df, :group))
        push!(ls, lines!(ax2, part.t, part.y; label = string(k.group)))
    end
    axislegend(ax2)
    ax3 = Axis(fig[2, 1]; title = "means", xticks = (1:nrow(g), String.(g.group)))
    bp = barplot!(ax3, 1:nrow(g), g.ymean; color = collect(1:nrow(g)))
    errorbars!(ax3, 1:nrow(g), g.ymean, g.ystd)
    ax4 = Axis(fig[2, 3]; title = "histogram")
    h = hist!(ax4, df.yflip; bins = 40)
    return fig, (; ax1, ax2, ax3, ax4, sc, ls, bp, h)
end

function edit_plots!(fig, p, sub, k)
    p.sc.colormap = k % 2 == 0 ? :viridis : :plasma
    p.sc.markersize = 2 + k % 3
    p.sc[1] = Point2f.(sub.x, sub.y .+ 0.01k)
    p.ax1.title = "scatter, edit $k"
    xlims!(p.ax1, 0, 10 - k % 3)
    p.ls[1].linewidth = 1 + k % 4
    p.ls[2].visible = isodd(k)
    p.bp.color = circshift(1:length(p.bp[1][]), k)
    text!(p.ax3, 1, 0; text = "note $k")
    p.ax4.yscale = k % 2 == 0 ? identity : Makie.pseudolog10
    return fig
end

render(fig, i) = save(joinpath(OUT, "plot-$MODE-$i.png"), fig; px_per_unit = 1)

function work(i)
    t = @timed read_data(CSVPATH); row("read", i, t); df, sub, g = t.value
    t = @timed make_plots(df, sub, g); row("plot", i, t); fig, p = t.value
    t = @timed render(fig, i); row("render", i, t)
    t = @timed edit_plots!(fig, p, sub, i); row("edit", i, t)
    t = @timed render(fig, i); row("render-edited", i, t)
    t = @timed for k in 1:10; edit_plots!(fig, p, sub, k); end; row("edit10", i, t)
    return nothing
end

if ORDER != "together"
    t = @timed read_data(CSVPATH); row("read", -2, t)
    t = @timed for L in LOADS; @eval using $(Symbol(L)); end; row("load-analysis", 0, t)
    t = @timed read_data(CSVPATH); row("read", -1, t)
    t = @timed @eval using CairoMakie; row("load-plots", 0, t)
end
for i in 1:REPS
    Base.invokelatest(work, i)
end
println("TOTAL ", MODE, ' ', ORDER, ' ', round((time() - T0) * 1e3; digits = 1))
