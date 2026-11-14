using TraitWorld
SeriesA.len(r::Ring) = capacity(r)
SeriesA.at(r::Ring, i::Int) = ringat(r, i)
@implement SeriesA.Series Ring
function main(args)
    r = Ring(1000)
    s = total(r) + mean(r) + variance(r)
    s += sum(normalize(r)) + sum(smooth(r, 3)) + sum(histogram(r, 8)) + sum(topk(r, 5))
    println(describe(rotated(r, 3)), " ", round(s; digits = 3))
    return 0
end
