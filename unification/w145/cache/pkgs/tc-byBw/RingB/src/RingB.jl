module RingB
using TraitWorld
@trait_module
import SeriesA
export Ring, capacity, ringat, rotated
struct Ring; data::Vector{Float64}; head::Int; end
Ring(n::Int) = Ring(Float64[sin(0.37 * i) * i for i in 1:n], 1)
capacity(r::Ring) = length(r.data)
ringat(r::Ring, i::Int) = r.data[mod1(r.head + i - 1, length(r.data))]
rotated(r::Ring, k::Int) = Ring(r.data, mod1(r.head + k, length(r.data)))
let r = Ring(16); capacity(r); ringat(r, 3); rotated(r, 2); end
SeriesA.len(r::Ring) = capacity(r)
SeriesA.at(r::Ring, i::Int) = ringat(r, i)
@implement SeriesA.Series Ring

let r = Ring(16); SeriesA.total(r); SeriesA.mean(r); SeriesA.variance(r); SeriesA.normalize(r); SeriesA.smooth(r, 3); SeriesA.histogram(r, 8); SeriesA.topk(r, 5); SeriesA.describe(r); end
end
