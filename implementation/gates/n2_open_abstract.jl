# Gate (W-107; compiler §4.7, §4.9, §5.3): an open set meets an abstract type that no entry
# relates to it as their intersection All{X, T}, so a query at either side sees the methods at
# the other. A concrete non-member still meets nothing.
using Traits
const All = Core.All      # Core does not export it (open issue 148)
include("util.jl")

@trait PX
@implement PX Vector{Int}

# intersection
let t = typeintersect(PX, AbstractArray)        # All{PX, AbstractArray{T, N}} where {T, N}
    @assert t !== Union{} && t <: PX && t <: AbstractArray && Vector{Int} <: t
end
@assert typeintersect(AbstractVector{Int}, PX) === All{AbstractVector{Int}, PX}
@assert typeintersect(PX, Vector{Int}) === Vector{Int}
@assert typeintersect(PX, Vector{Float64}) === Union{}
@assert typeintersect(Vector{PX}, Vector{AbstractArray}) === Union{}     # invariant: no meet
@assert Base.hasintersect(PX, AbstractVector)

# a query at an abstract type sees a method at a set
f(::Any) = :any
f(::PX) = :px
g(@nospecialize(x::AbstractVector)) = f(x)
@assert g(Int[1]) === :px
@assert g(Float64[1]) === :any
@assert length(methods(f, (AbstractVector,))) == 2

# a query at a set sees the methods at abstract types
@assert !isempty(methods(length, (PX,)))
@assert Base.infer_return_type(length, (PX,)) !== Union{}
k(@nospecialize(x::PX)) = length(x)
@assert k(Int[1, 2]) == 2

# a closed method that covers an abstract query still dominates a method at a set (§5.2)
f(::AbstractArray) = :array
@assert length(methods(f, (AbstractVector,))) == 1
@assert Base.infer_return_type(f, (AbstractVector,)) === Symbol
@assert g(Int[1]) === :array

# an intersection as the query
@trait PY
@implement PY Vector{Int}
const A = All{PX, PY}
@assert !isempty(methods(length, (A,)))
h(@nospecialize(x::A)) = length(x)
@assert h(Int[1, 2, 3]) == 3

println("n2_open_abstract: OK")
