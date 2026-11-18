# E-182 (X7): a provider of a histogram recipe of its own (`Hist2`), implementing TraitMakie's `Plot`,
# loaded by a stub at the first `hist2!`. 
module X7Stats
using TraitWorld
import TraitMakie

@trait_module module Impl
using TraitWorld
import TraitMakie
using TraitMakie.PlotCore: Plot, Canvas, Transform2D, ColorSpec, Bars, Positions, Figure, add_plot!, NOPOINTS
import TraitMakie.PlotCore: datalimits, draw!, setcolor!
mutable struct Hist2
    values::Vector{Float64}
    bins::Int
    color::ColorSpec
    bars::Bars
end
"Bin centres and counts, and the bins' width."
function binned2(v::Vector{Float64}, bins::Int)
    lo, hi = extrema(v)
    w = hi > lo ? (hi - lo) / bins : 1.0
    counts = zeros(bins)
    for x in v
        counts[clamp(floor(Int, (x - lo) / w) + 1, 1, bins)] += 1
    end
    out = Matrix{Float64}(undef, bins, 2)
    for k in 1:bins
        out[k, 1], out[k, 2] = lo + (k - 0.5) * w, counts[k]
    end
    return out, w
end
function refresh2!(h::Hist2)
    pts, w = binned2(h.values, h.bins)
    b = h.bars
    b.pos = Dynamic{Positions}(pts)
    b.width = w
    b.color = h.color
    return b
end
datalimits(h::Hist2) = datalimits(refresh2!(h))
draw!(h::Hist2, c::Canvas, t::Transform2D) = draw!(refresh2!(h), c, t)
setcolor!(h::Hist2, c::Kept{ColorSpec}) = (h.color = c; nothing)
@implement Plot Hist2
function hist2!(f::Figure, x::Vector{Float64}, bins::Int)
    c = Dynamic{ColorSpec}(:orange)
    p = Hist2(x, bins, c, Bars(Dynamic{Positions}(NOPOINTS), c, 1.0))
    add_plot!(f, Dynamic{Plot}(p))
    return p
end
end
hist2!(fig, x; bins = 10) = Impl.hist2!(fig, Vector{Float64}(x), Int(bins))
end
