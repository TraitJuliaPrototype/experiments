# The plots of workload.jl (CairoMakie), included after the plotting library is loaded.
function plot_two(a, b, path)
    fig = Figure(size = (800, 600))
    ax1 = Axis(fig[1, 1]); ax2 = Axis(fig[2, 1]; xscale = log10)
    for k in 1:3; lines!(ax1, a.t, getindex.(a.u, k)); end
    for k in 1:3; lines!(ax2, b.t, getindex.(b.u, k) .* (k == 2 ? 1e4 : 1.0)); end
    save(path, fig; px_per_unit = 1)
end
function plot_one(c, path)
    fig = Figure(size = (800, 400)); lines!(Axis(fig[1, 1]), c.t, getindex.(c.u, 1)); save(path, fig; px_per_unit = 1)
end
include("pngs.jl")
