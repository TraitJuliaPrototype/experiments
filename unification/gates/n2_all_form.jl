# Gate (W-107; compiler §4.9; the review of 2026-11-07, §6): the encoding Core.All{Tuple{X, Y}}
# where the runtime reads names, parameters and wrappers: instantiation, reflection, the typemap,
# the fold gates, the diagonal rule, the left rule's backtracking, the normal form's further rules.
using Traits, Serialization
const All = Core.All      # Core does not export it (open issue 148)
include("util.jl")

@trait PX
@trait PY
struct SXY end
@implement PX SXY
@implement PY SXY
const A = All{PX, PY}

# instantiation keeps the normal form (finding 4)
@assert (All{T, PX} where T){PX} === PX
@assert (All{T, PY} where T){PX} === A
@assert (All{T, Integer} where T){Union{}} === Union{}

# the encoding written so is the same type; reflection round-trips (finding 5)
@assert Core.All{Tuple{PX, PY}} === A
@assert A.name.wrapper{A.parameters...} === A
@assert deserialize(IOBuffer(sprint(serialize, A))) === A
@assert A <: Core.All

# the normal form's further rules (findings 9, 10, 11)
@assert All{AbstractArray{Int}, AbstractVector} === AbstractVector{Int}
@assert All{Union{PX, Int}, PY} === Union{A, All{Int, PY}}
let raised = try
        All{Int, Core.All.body}
        false
    catch e
        e isa TypeError
    end
    @assert raised
end

# the typemap: a method at an intersection at a split level, and an intersection as the query (finding 1)
@implement PX Vector{Int}
@implement PY Vector{Int}
for (i, T) in enumerate((Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float16,
                         Float32, Float64, String, Symbol, Char, Bool, Nothing))
    @eval f(::Int, ::$T) = $i
end
f(::Int, ::A) = :all
@assert f(1, Int[]) === :all
@assert !isempty(methods(length, (A,)))
h(@nospecialize(x::AbstractArray{Int})) = x isa A ? length(x) : -1
@assert h(Int[1, 2, 3]) == 3

# a negative isa against an intersection is not folded (finding 2)
struct SX end
@implement PX SX
q(x::SX) = x isa A
@assert q(SX()) === false
@implement PY SX
@assert SX() isa A
@assert q(SX()) === true

# the diagonal rule sees a variable inside an intersection (finding 3)
@assert !(Tuple{Int, Float64} <: (Tuple{All{T, Real}, T} where T))
g(::All{T, Real}, ::T) where {T} = T
let raised = try
        g(1, 2.0)
        false
    catch e
        e isa MethodError
    end
    @assert raised
end

# the left rule backtracks over its choice (finding 6)
@trait QY{T}
@trait QX
struct V end
@implement QY{Int} V
@implement QY{Float64} QX
@assert Tuple{All{V, QX}, Int} <: (Tuple{QY{T}, T} where T)
@assert Tuple{All{V, QX}, Float64} <: (Tuple{QY{T}, T} where T)

println("n2_all_form: OK")
