# Gate (W-107's probe; compiler §4.9, traits §3.6): intersections All{X, Y, …}, subtyping and the
# normal form alone. Intersection, dispatch with All bounds and specificity are the stage's next steps.
using Traits
const All = Core.All      # Core does not export it (open issue 148: DataAPI exports an All of its own)
include("util.jl")

@trait PX
@trait PY
@trait PZ
struct SXY end
struct SX end
@implement PX SXY
@implement PY SXY
@implement PX SX
const A = All{PX, PY}

# the normal form: flattened, sorted, deduplicated, absorbed by declared supertypes only
@assert All{PX, PY} === All{PY, PX}
@assert All{PX, PX} === PX
@assert All{PX} === PX
@assert All{} === Any
@assert All{PX, All{PY, PZ}} === All{PX, PY, PZ} === All{PZ, PY, PX}
@assert All{PX, Any} === PX
@assert All{PX, Union{}} === Union{}
@assert All{AbstractVector, AbstractArray} === AbstractVector       # a declared supertype absorbs
@assert All{AbstractArray, Number} === Union{}                      # closed, nothing in common
@assert All{Vector{Int}, PX} isa DataType                          # a membership never absorbs

# subtyping: on the right each component, on the left some component
@assert SXY <: A && SXY() isa A
@assert !(SX <: A) && !(SX() isa A)
@assert A <: PX && A <: PY && !(A <: PZ)
@assert A <: All{PY, PX}
@assert All{PX, PY, PZ} <: A && !(A <: All{PX, PY, PZ})
@assert A <: Union{PX, Int}
@assert !(Int <: A)
@assert Union{SXY} <: A && !(Union{SXY, SX} <: A)
@assert Vector{SXY} <: Vector{<:A} && !(Vector{SX} <: Vector{<:A})
@assert Tuple{SXY, Vararg{SXY}} <: Tuple{Vararg{A}}
@assert (Tuple{T, T} where {T <: A}) <: Tuple{A, A}
@assert Vector{A} <: Vector{All{PY, PX}}                            # one type object, invariance holds

# the normal form does not depend on the world: a set-in-set membership absorbs nothing
B = All{PX, PZ}
@implement PZ PX
@assert PX <: PZ
@assert All{PX, PZ} === B && B isa DataType
@assert SX <: B                                                    # SX in PX, PX in PZ

# printing
@assert sprint(show, A) == "All{PX, PY}"

println("n2_all_probe: OK")
