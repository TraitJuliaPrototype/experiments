# W-158, fourth part (E-510; open issue 247): beside a method at any value, one at a union of two records, called at
# the object a box of a signature holds: the member's type chooses the method (compiler §7.6).
# `julia --project=<TraitWorld> apps/f-union.jl` runs `main` in a session.
using TraitWorld
const F = Callable{Tuple{Float64}, Float64}
double(x::Float64) = 2x
struct RecA{G}; f::G; end
(r::RecA)(x::Float64) = r.f(x)
@implement Callable RecA{G} where {G}
struct RecB{G}; f::G; end
(r::RecB)(x::Float64) = 2.0 * r.f(x)
@implement Callable RecB{G} where {G}
kind(k, f) = 1.0
kind(k, f::Union{RecA, RecB}) = 10.0 + f(1.0)
@noinline obj(ds::Vector{Dynamic{F}}) = (s = 0.0; for d in ds; s += kind(d, unwrap(d)); end; s)
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "union ", obj(Dynamic{F}[Dynamic{F}(double), Dynamic{F}(RecA(double)), Dynamic{F}(RecB(double))]))
    return 0
end
