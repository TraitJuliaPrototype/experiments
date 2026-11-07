# Gate (W-107; compiler §4.9, §5.2; traits §3.6): intersection with All, two sets meeting as
# All{X, Y}, dispatch at an All bound and its rank above each component.
using Traits
const All = Core.All      # Core does not export it (open issue 148)
include("util.jl")

@trait PX
@trait PY
struct SXY end
struct SX end
struct SY end
@implement PX SXY
@implement PY SXY
@implement PX SX
@implement PY SY

# intersection
@assert typeintersect(SXY, All{PX, PY}) === SXY
@assert typeintersect(SX, All{PX, PY}) === Union{}
@assert typeintersect(PX, PY) === All{PX, PY}
@assert typeintersect(All{PX, PY}, PX) === All{PX, PY}
@assert typeintersect(Tuple{SXY, Int}, Tuple{All{PX, PY}, Integer}) === Tuple{SXY, Int}

# dispatch at an All bound, ranked above each component
f(::PX) = :x
f(::PY) = :y
f(::All{PX, PY}) = :both
@assert f(SXY()) === :both
@assert f(SX()) === :x && f(SY()) === :y
@assert Base.morespecific(Tuple{typeof(f), All{PX, PY}}, Tuple{typeof(f), PX})
g(::All{PX, PY}) = 1
let raised = try
        g(SX())
        false
    catch e
        e isa MethodError
    end
    @assert raised
end
h(x) = f(x)
@assert h(SXY()) === :both                                   # compiled with the type known
k(v::Vector{<:All{PX, PY}}) = length(v)
@assert k([SXY()]) == 1
@assert Base.invokelatest(f, Any[SXY()][1]) === :both          # dynamic

println("n2_all_dispatch: OK")
