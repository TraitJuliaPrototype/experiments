# Gate (W-107; compiler §5.2, traits §6.2): the rank of an intersection. It is more specific than
# each component; one with a closed component ranks as a closed type against an open set; two
# intersections by their components.
using Traits
const All = Core.All      # Core does not export it (open issue 148)
include("util.jl")

@trait PX
@trait PY
@trait PZ
ms(a, b) = Base.morespecific(Tuple{typeof(identity), a}, Tuple{typeof(identity), b})

# the rank, argument by argument
@assert ms(All{PX, PY}, PX) && !ms(PX, All{PX, PY})
@assert !ms(All{PX, PY}, PZ) && !ms(PZ, All{PX, PY})               # open against open: unordered
@assert ms(All{AbstractVector, PX}, PY) && !ms(PY, All{AbstractVector, PX})   # a closed component
@assert ms(AbstractVector, All{PX, PY}) && !ms(All{PX, PY}, AbstractVector)   # closed beats open
@assert ms(All{AbstractVector, PX}, All{PX, PY}) && !ms(All{PX, PY}, All{AbstractVector, PX})
@assert ms(All{PX, PY, PZ}, All{PX, PY}) && !ms(All{PX, PY}, All{PX, PY, PZ})
@assert ms(Vector{Int}, All{AbstractVector, PX}) && !ms(All{AbstractVector, PX}, Vector{Int})
@assert ms(All{AbstractVector, PX}, AbstractArray)

# dispatch follows the rank
@implement PX Vector{Int}
@implement PY Vector{Int}
f(::PY) = :y
f(::All{AbstractVector, PX}) = :vx
@assert f(Int[]) === :vx
g(::PX) = :x
g(::All{PX, PY}) = :xy
@assert g(Int[]) === :xy
struct SXYZ end
@implement PX SXYZ
@implement PY SXYZ
@implement PZ SXYZ
h(::All{PX, PY}) = :xy
h(::PZ) = :z
let raised = try
        h(SXYZ())
        false
    catch e
        e isa MethodError
    end
    @assert raised "two unordered methods are ambiguous at a member of both"
end
h(::All{PX, PY, PZ}) = :xyz
@assert h(SXYZ()) === :xyz

println("n2_all_rank: OK")
