# W-106's first workload, shaped like a column store: a trait with an equation for its
# parameter, a default, a member by its own methods, one by forwarding, a family, a Dynamic.
# The same program in plain Julia (abstract types) gives the same results.
#     <unified julia> --project=TraitWorld-unified columns.jl
using TraitWorld

module Traited
using TraitWorld
@trait Column{T} begin
    T = eltype(Self)
    clen(c::Column)::Int
    cget(c::Column{T}, i::Int)::T
    csum(c::Column{T})::T = (s = zero(T); for i in 1:clen(c); s += cget(c, i); end; s)
end
struct Stored{T}; data::Vector{T}; end
Base.eltype(::Type{Stored{T}}) where {T} = T
clen(c::Stored) = length(c.data)
cget(c::Stored, i::Int) = c.data[i]
@implement Column{T} Stored{T} where {T}
struct Named; name::String; col::Stored{Float64}; end
Base.eltype(::Type{Named}) = Float64
@implement Column Named by col
struct Ramp; n::Int; step::Float64; end
Base.eltype(::Type{Ramp}) = Float64
clen(r::Ramp) = r.n
cget(r::Ramp, i::Int) = r.step * i
@implement Column Ramp
colmean(c::Column) = csum(c) / clen(c)
spread(c::Column{Float64}) = (m = colmean(c); sqrt(sum((cget(c, i) - m)^2 for i in 1:clen(c)) / clen(c)))
end

module Plain
abstract type Column{T} end
struct Stored{T} <: Column{T}; data::Vector{T}; end
clen(c::Stored) = length(c.data)
cget(c::Stored, i::Int) = c.data[i]
struct Named <: Column{Float64}; name::String; col::Stored{Float64}; end
clen(c::Named) = clen(c.col)
cget(c::Named, i::Int) = cget(c.col, i)
struct Ramp <: Column{Float64}; n::Int; step::Float64; end
clen(r::Ramp) = r.n
cget(r::Ramp, i::Int) = r.step * i
csum(c::Column{T}) where {T} = (s = zero(T); for i in 1:clen(c); s += cget(c, i); end; s)
colmean(c::Column) = csum(c) / clen(c)
spread(c::Column{Float64}) = (m = colmean(c); sqrt(sum((cget(c, i) - m)^2 for i in 1:clen(c)) / clen(c)))
end

function run(M, wrap)
    xs = [sin(0.1i) for i in 1:1000]
    cols = Any[M.Stored(xs), M.Named("n", M.Stored(xs .+ 1.0)), M.Ramp(1000, 0.001), M.Stored(collect(1:10))]
    out = Any[]
    for c in cols
        push!(out, (M.clen(c), M.csum(c), M.colmean(c)))
    end
    fl = [wrap(c) for c in cols[1:3]]
    push!(out, sum(M.spread, fl))
    return out
end

a = run(Traited, c -> Dynamic{Traited.Column{Float64}}(c))
b = run(Plain, identity)
println("traited: ", a)
println("plain:   ", b)
a == b || error("the workloads disagree")
println("columns: equal results")
