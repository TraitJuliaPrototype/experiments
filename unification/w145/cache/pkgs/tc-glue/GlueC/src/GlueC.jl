module GlueC
using TraitWorld
using RingB, SeriesA
SeriesA.len(r::Ring) = capacity(r)
SeriesA.at(r::Ring, i::Int) = ringat(r, i)
@implement SeriesA.Series Ring

end
