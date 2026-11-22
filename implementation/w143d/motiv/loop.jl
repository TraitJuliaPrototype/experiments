# W-143d (E-540): jl_subtype or jl_type_intersection over ../../w19/motiv/h-micro.jl's plain pairs (copied), in a
# loop of a few seconds, for `perf record`:   julia loop.jl sub|isect <seconds>
const PAIRS = Any[
    (Int, Integer), (Int, AbstractString), (Vector{Int}, AbstractVector), (Vector{Int}, AbstractVector{<:Real}),
    (Tuple{Int, String}, Tuple{Any, Any}), (Tuple{Int, Vararg{Int}}, Tuple{Vararg{Integer}}),
    (Dict{Symbol, Any}, AbstractDict), (Union{Int, Nothing}, Any), (Union{Int, Nothing}, Integer),
    (Type{Int}, DataType), (Type{Vector{Int}}, Type{<:AbstractArray}), (Float64, Real), (String, Number),
    (NamedTuple{(:a,), Tuple{Int}}, NamedTuple), (Array{Float64, 3}, AbstractMatrix),
    (Pair{Symbol, Int}, Pair{Symbol}), (Ref{Int}, Ref{<:Integer}), (Base.OneTo{Int}, AbstractUnitRange{Int}),
]
sub(n) = (s = 0; for _ in 1:n, (a, b) in PAIRS; s += ccall(:jl_subtype, Cint, (Any, Any), a, b); end; s)
isect(n) = (s = 0; for _ in 1:n, (a, b) in PAIRS; s += ccall(:jl_type_intersection, Any, (Any, Any), a, b) === Union{} ? 1 : 0; end; s)
f = ARGS[1] == "sub" ? sub : isect
f(10); t0 = time()
n = 0
while time() - t0 < parse(Float64, ARGS[2]); f(10_000); global n += 10_000 * length(PAIRS); end
println(ARGS[1], " calls ", n, " in ", round(time() - t0; digits = 2), " s")
