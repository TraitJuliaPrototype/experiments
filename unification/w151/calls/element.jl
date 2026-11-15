# E-402, the element row alone: E-374's `vec_t` in a module with the trait and its two members only, on each library.
#     julia --project=<TraitWorld-base | TraitWorld-unified> element.jl
using TraitWorld
module T
using TraitWorld
@trait_module
@trait Shape begin
    area(s::Shape)::Float64
end
struct Circle; r::Float64; end
struct Square; a::Float64; end
area(c::Circle) = 3.0 * c.r * c.r
area(s::Square) = s.a * s.a
@implement Shape Circle
@implement Shape Square
end
function vec_t(xs::Vector{T.Shape}, n); s = 0.0; m = length(xs); for i in 1:n; s += T.area(xs[mod1(i, m)]); end; s; end
txs = T.Shape[isodd(i) ? T.Circle(1.0) : T.Square(1.0) for i in 1:64]
vec_t(txs, 10)
const SINK = Ref(0.0); ns(h, args...; n = 10^7) = minimum(@elapsed(SINK[] += h(args..., n)) for _ in 1:7) / n * 1e9; println("vec_t ", round(ns(vec_t, txs); digits = 2))
#, vec_t, (Vector{T.Shape}, Int); debuginfo = :none)
