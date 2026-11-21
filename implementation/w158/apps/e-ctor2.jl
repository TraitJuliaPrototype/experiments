# W-158, third part (E-510): a constructor that takes two values known only by `Callable` signatures (the ODE port's
# callbacks, compiler §7.4, §7.6: C-154, C-151). The functions are kept in fields typed by bare `Callable`, as the
# port's `DiscreteCallback`; the constructor's method at the two signatures erases by default, so its forwarder boxes
# each function and tests `hasmethod(f, A)`. `pick` chooses the functions at run time; `fixed` builds them as a
# constant. `julia --project=<TraitWorld> apps/e-ctor2.jl` runs `main` in a session.
using TraitWorld
hh(x::Float64) = 2x
hh(x::Int) = 3.0 * x
kk(x::Float64) = x + 1
kk(x::Int) = Float64(x)
struct Pair2{C<:Callable{Tuple{Float64}, Float64}, A<:Callable{Tuple{Int}, Float64}}
    c::C
    a::A
end
mkpair(c::Callable{Tuple{Float64}, Float64}, a::Callable{Tuple{Int}, Float64}) = Pair2{typeof(c), typeof(a)}(c, a)
struct Raw2
    c::Callable
    a::Callable
end
usepair(p::Pair2) = p.c(1.0) + p.a(2)
@noinline enter2(rs::Vector{Raw2}) = (s = 0.0; for r in rs; s += usepair(mkpair(r.c, r.a)); end; s)
pick(n::Int) = Raw2(isodd(n) ? hh : kk, iseven(n) ? hh : kk)
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    println(Core.stdout, "picked ", enter2([pick(n), pick(n + 1)]))
    println(Core.stdout, "fixed ", enter2([Raw2(hh, kk), Raw2(kk, hh)]))
    return 0
end
