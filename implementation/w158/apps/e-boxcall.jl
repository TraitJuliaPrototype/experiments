# W-158, third part (E-510): the call of a function known only by its signature (compiler §7.4, §7.6: C-154). A box
# of an intersection of two signatures, called at each (the library's box call method calls the object it holds); a
# box of one signature called as itself; a function passed to an argument declared `@nospecialize`.
# `julia --project=<TraitWorld> apps/e-boxcall.jl` runs `main` in a session.
using TraitWorld
const G2 = All{Callable{Tuple{Float64}, Float64}, Callable{Tuple{Int}, Float64}}
const G1 = Callable{Tuple{Float64}, Float64}
hh(x::Float64) = 2x
hh(x::Int) = 3.0 * x
kk(x::Float64) = x + 1
kk(x::Int) = Float64(x)
@noinline boxall(ds::Vector{Dynamic{G2}}, n::Int) = (s = 0.0; for d in ds; s += d(1.0) + d(n); end; s)
@noinline boxone(ds::Vector{Dynamic{G1}}, n::Int) = (s = 0.0; for d in ds; s += d(Float64(n)); end; s)
@noinline callns(@nospecialize(f::Callable{Tuple{Float64}, Float64}), x::Float64) = f(x)
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    println(Core.stdout, "two signatures ", boxall(Dynamic{G2}[Dynamic{G2}(hh), Dynamic{G2}(kk)], n))
    println(Core.stdout, "one signature ", boxone(Dynamic{G1}[Dynamic{G1}(hh), Dynamic{G1}(kk)], n))
    println(Core.stdout, "nospecialize ", callns(hh, Float64(n)) + callns(kk, 1.0))
    return 0
end
