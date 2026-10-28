# W-81: allocation of a typed call, a Callable whose argument type follows a bound against a fixed one
using TraitWorld
@trait_module module G83b
using TraitWorld
count_if(f::Callable{Tuple{T}, Bool}, xs::Iterable{T}) where {T} = (n = 0; for x in xs; f(x) && (n += 1); end; n)
count_int(f::Callable{Tuple{Int}, Bool}, xs::Iterable{Int}) = (n = 0; for x in xs; f(x) && (n += 1); end; n)
end
f1(v) = G83b.count_if(iseven, v)
f2(v) = G83b.count_int(iseven, v)
v = [1, 2, 3, 4]
f1(v); f2(v)
println("B follows: ", @allocated(f1(v)), " bytes; fixed: ", @allocated(f2(v)), " bytes")
# timed inside a function, minimum of five repetitions of 10^5 calls each
function bench(g, v)
    best = Inf
    for _ in 1:5
        t = @elapsed for _ in 1:10^5; g(v); end
        best = min(best, t)
    end
    return best * 1e4                                  # ns per call
end
bench(f1, v); bench(f2, v)
for _ in 1:2
    println("B follows: ", round(bench(f1, v); digits = 1), " ns/call; fixed: ", round(bench(f2, v); digits = 1), " ns/call")
end
