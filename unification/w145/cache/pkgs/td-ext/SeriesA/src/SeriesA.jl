module SeriesA
using TraitWorld
@trait_module
export Series, len, at, total, mean, variance, normalize, smooth, histogram, topk, describe
@trait Series begin
    @default_dynamic
    len(s::Series)::Int
    at(s::Series, i::Int)::Float64
end
total(s::Series) = (t = 0.0; for i in 1:len(s); t += at(s, i); end; t)
mean(s::Series) = total(s) / len(s)
function variance(s::Series)
    m = mean(s); v = 0.0
    for i in 1:len(s); d = at(s, i) - m; v += d * d; end
    return v / max(len(s) - 1, 1)
end
normalize(s::Series) = (m = mean(s); sd = sqrt(variance(s)); Float64[(at(s, i) - m) / sd for i in 1:len(s)])
function smooth(s::Series, w::Int)
    n = len(s); out = Vector{Float64}(undef, n)
    for i in 1:n
        lo = max(1, i - w); hi = min(n, i + w); t = 0.0
        for j in lo:hi; t += at(s, j); end
        out[i] = t / (hi - lo + 1)
    end
    return out
end
function histogram(s::Series, nb::Int)
    lo = Inf; hi = -Inf
    for i in 1:len(s); x = at(s, i); lo = min(lo, x); hi = max(hi, x); end
    counts = zeros(Int, nb); width = (hi - lo) / nb
    for i in 1:len(s)
        b = width == 0 ? 1 : clamp(floor(Int, (at(s, i) - lo) / width) + 1, 1, nb)
        counts[b] += 1
    end
    return counts
end
topk(s::Series, k::Int) = partialsort!(Float64[at(s, i) for i in 1:len(s)], 1:min(k, len(s)); rev = true)
function describe(s::Series)
    io = IOBuffer()
    print(io, "n=", len(s), " mean=", round(mean(s); digits = 3), " sd=", round(sqrt(variance(s)); digits = 3))
    print(io, " top=", join(string.(round.(topk(s, 3); digits = 2)), ","))
    return String(take!(io))
end

struct Vec; data::Vector{Float64}; end
len(v::Vec) = length(v.data)
at(v::Vec, i::Int) = v.data[i]
@implement Series Vec
let v = Vec(collect(1.0:50.0)); total(v); mean(v); variance(v); normalize(v); smooth(v, 3); histogram(v, 8); topk(v, 5); describe(v); end
end
