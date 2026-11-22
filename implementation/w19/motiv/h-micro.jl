# W-19, fourth part: what subtyping, intersection, the type cache and method matching cost plain code with no
# set declared in the session. Each kind loops over a fixed list of plain pairs (no set anywhere), calling the
# runtime's entry point with values typed Any (nothing folds); per kind, 7 rounds, the minimum per call in ns.
#     julia --startup-file=no h-micro.jl
const PAIRS = Any[
    (Int, Integer), (Int, AbstractString), (Vector{Int}, AbstractVector), (Vector{Int}, AbstractVector{<:Real}),
    (Tuple{Int, String}, Tuple{Any, Any}), (Tuple{Int, Vararg{Int}}, Tuple{Vararg{Integer}}),
    (Dict{Symbol, Any}, AbstractDict), (Union{Int, Nothing}, Any), (Union{Int, Nothing}, Integer),
    (Type{Int}, DataType), (Type{Vector{Int}}, Type{<:AbstractArray}), (Float64, Real), (String, Number),
    (NamedTuple{(:a,), Tuple{Int}}, NamedTuple), (Array{Float64, 3}, AbstractMatrix),
    (Pair{Symbol, Int}, Pair{Symbol}), (Ref{Int}, Ref{<:Integer}), (Base.OneTo{Int}, AbstractUnitRange{Int}),
]
const PARAMS = Any[Int, Float64, String, Symbol, Vector{Int}, Dict{Symbol, Any}, Nothing, Missing, UInt8, Char]
const SIGS = Any[Tuple{typeof(+), Int, Int}, Tuple{typeof(getindex), Vector{Int}, Int}, Tuple{typeof(length), String},
                 Tuple{typeof(push!), Vector{Any}, Int}, Tuple{typeof(show), IO, Float64}, Tuple{typeof(convert), Type{Int}, Float64}]
function sub(n)
    s = 0
    for _ in 1:n, (a, b) in PAIRS
        s += ccall(:jl_subtype, Cint, (Any, Any), a, b)
    end
    return s
end
function isect(n)
    s = 0
    for _ in 1:n, (a, b) in PAIRS
        s += ccall(:jl_type_intersection, Any, (Any, Any), a, b) === Union{} ? 1 : 0
    end
    return s
end
function cache(n)
    s = 0
    for _ in 1:n, T in PARAMS, S in PARAMS
        s += Core.apply_type(Tuple, T, S) isa DataType ? 1 : 0
        s += Core.apply_type(Vector, T) isa DataType ? 1 : 0
    end
    return s
end
function matching(n)
    s = 0; w = Base.get_world_counter()
    for _ in 1:n, sig in SIGS
        s += length(Base._methods_by_ftype(sig, -1, w))
    end
    return s
end
for (name, f, n, per) in (("jl_subtype", sub, 20_000, length(PAIRS)), ("jl_type_intersection", isect, 5_000, length(PAIRS)),
                          ("type cache (apply_type)", cache, 5_000, 2 * length(PARAMS)^2), ("method matching", matching, 500, length(SIGS)))
    f(10)
    best = Inf
    for _ in 1:7
        t = @elapsed f(n)
        best = min(best, t)
    end
    println(rpad(name, 26), round(1e9 * best / (n * per); digits = 1), " ns per call (minimum of 7 rounds of ", n * per, ")")
end
