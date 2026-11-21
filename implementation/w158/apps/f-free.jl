# W-158, fourth part (E-510; compiler C-155): a type that one entry makes a member of every instance of a set
# (`@implement Callable T`) is a member by use at each instance. `Far` is declared callable and never handed to the
# signature `F`; its call reaches a call at `Any`, which a closed build cannot resolve: a branch for it at `F` would
# be refused. `Near` is handed to `F`. `julia --project=<TraitWorld> apps/f-free.jl` runs `main` in a session.
using TraitWorld
const F = Callable{Tuple{Float64}, Float64}
double(x::Float64) = 2x
struct Far; v::Vector{Any}; end
(g::Far)(x::Float64) = g.v[1](x)::Float64
@implement Callable Far
struct Near; k::Float64; end
(g::Near)(x::Float64) = g.k * x
@implement Callable Near
@noinline viabox(ds::Vector{Dynamic{F}}, x::Float64) = (s = 0.0; for d in ds; s += d(x); end; s)
@noinline hold(fs::Vector{Callable}) = length(fs)
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    println(Core.stdout, "handed ", viabox(Dynamic{F}[Dynamic{F}(double), Dynamic{F}(Near(3.0))], Float64(n)))
    println(Core.stdout, "held ", hold(Callable[Far(Any[double])]))
    return 0
end
