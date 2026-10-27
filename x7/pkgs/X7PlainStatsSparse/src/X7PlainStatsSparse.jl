# E-182 (X7): the plain control: a provider of a histogram recipe of its own for PlainPlots (methods of
# PlainPlots' `datalimits` and `draw!` for its own type), loaded by a stub at the first `hist2!`. This one also loads SparseArrays, as a statistics tree does.
module X7PlainStatsSparse
import PlainPlots
import SparseArrays                      # what a statistics tree brings (StatsBase, Distributions)
struct Hist2P
    values::Vector{Float64}
    bins::Int
    color::Symbol
end
function PlainPlots.datalimits(h::Hist2P)
    pts, w = PlainPlots.binned(h.values, h.bins)
    xmin, xmax, ymin, ymax = PlainPlots.limits(pts)
    return (xmin - w / 2, xmax + w / 2, min(ymin, 0.0), max(ymax, 0.0))
end
function PlainPlots.draw!(h::Hist2P, c::PlainPlots.Canvas, t::PlainPlots.Transform2D)
    pts, w = PlainPlots.binned(h.values, h.bins)
    PlainPlots.drawbars(pts, c, t, h.color, w)
    return nothing
end
hist2!(fig, x; bins = 10) = PlainPlots.plot!(fig, Hist2P(Vector{Float64}(x), Int(bins), PlainPlots._color(:orange)))
end
