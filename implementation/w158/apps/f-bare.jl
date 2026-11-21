# W-158, fourth part (E-510; compiler C-155): the call of a function known only as `Callable`, with no signature (an
# element of a `Vector{Callable}`, as TraitIndexing's `VectorGetter` calls its getters): in a closed build it branches
# over `Callable`'s members by use, its result the join of the branches'. A box among the elements is a branch; the
# box's call checks its signature. `julia --project=<TraitWorld> apps/f-bare.jl` runs `main` in a session.
using TraitWorld
const F = Callable{Tuple{Float64}, Float64}
double(x::Float64) = 2x
struct Near; k::Float64; end
(g::Near)(x::Float64) = g.k * x
@implement Callable Near
@noinline each(fs::Vector{Callable}, x::Float64) = [f(x) for f in fs]
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    v = each(Callable[double, Near(2.0), Dynamic{F}(Near(1.0))], Float64(n))
    print(Core.stdout, "each")
    for x in v
        print(Core.stdout, " ", x)
    end
    println(Core.stdout, " sum ", sum(v))
    return 0
end
