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
t1 = @elapsed for _ in 1:10^5; f1(v); end
t2 = @elapsed for _ in 1:10^5; f2(v); end
println("B follows: ", round(t1 * 1e4; digits = 1), " ns/call; fixed: ", round(t2 * 1e4; digits = 1), " ns/call")
