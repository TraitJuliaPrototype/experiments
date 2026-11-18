# Gate (compiler §4.4; the review of 2026-11-07, finding 1): a set as a query's type meets methods
# keyed by any typename, also at a typemap level that has split by typename.
using Traits
include("util.jl")

@trait PX
@implement PX Vector{Int}
for (i, T) in enumerate((Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float16,
                         Float32, Float64, String, Symbol, Char, Bool, Nothing))
    @eval f(::Int, ::$T) = $i
end
f(::Int, ::Vector{Int}) = :vec
@assert f(1, Int[]) === :vec
@assert typeintersect(PX, Vector{Int}) === Vector{Int}
@assert !isempty(methods(f, (Int, PX)))
@assert Symbol <: Base.infer_return_type(f, (Int, PX))

println("m2_set_query_split: OK")
