module RingBSeriesAExt
using TraitWorld
using RingB, SeriesA
import RingB: Ring, capacity, ringat
SeriesA.len(r::Ring) = capacity(r)
SeriesA.at(r::Ring, i::Int) = ringat(r, i)
@implement SeriesA.Series Ring

let r = Ring(16); total(r); mean(r); variance(r); normalize(r); smooth(r, 3); histogram(r, 8); topk(r, 5); describe(r); end
end
