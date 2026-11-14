module RingBSeriesAExt

using RingB, SeriesA
import RingB: Ring, capacity, ringat
SeriesA.len(r::Ring) = capacity(r)
SeriesA.at(r::Ring, i::Int) = ringat(r, i)


end
