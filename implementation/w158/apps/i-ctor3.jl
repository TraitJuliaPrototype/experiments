# W-158, fifth part (E-510; compiler C-156): a constructor at three `Callable` signatures, given values known only
# by bare `Callable` (fields of a record made before the signatures are known, as the ODE port's `DiscreteCallback`).
# Fifteen functions are forgotten at bare `Callable`, so the product of the three arguments' members (15^3) is past
# the bound of 64 branches; the method the members reach is the forwarder (compiler §6.3), which boxes each argument
# apart. `pick` chooses the functions at run time; a record of constants; a record whose first function has no
# method at its signature raises `MethodError` (the forwarder's box test). `julia --project=<TraitWorld>
# apps/i-ctor3.jl` runs `main` in a session.
using TraitWorld
c1(x::Float64) = 2x
c2(x::Float64) = x + 1
c3(x::Float64) = x * x
c4(x::Float64) = -x
c5(x::Float64) = x / 4
a1(n::Int) = Float64(n)
a2(n::Int) = 2.0 * n
a3(n::Int) = n + 0.5
a4(n::Int) = n - 0.25
a5(n::Int) = 1.0 / n
i1(n::Int, y::Float64) = n * y
i2(n::Int, y::Float64) = n + y
i3(n::Int, y::Float64) = y - n
i4(n::Int, y::Float64) = y / n
i5(n::Int, y::Float64) = n * y * y
struct Trip{C<:Callable{Tuple{Float64}, Float64}, A<:Callable{Tuple{Int}, Float64}, I<:Callable{Tuple{Int, Float64}, Float64}}
    c::C
    a::A
    i::I
end
mktrip(c::Callable{Tuple{Float64}, Float64}, a::Callable{Tuple{Int}, Float64}, i::Callable{Tuple{Int, Float64}, Float64}) =
    Trip{typeof(c), typeof(a), typeof(i)}(c, a, i)
struct Raw3
    c::Callable
    a::Callable
    i::Callable
end
usetrip(t::Trip) = t.c(1.5) + t.a(2) + t.i(3, 0.5)
@noinline enter3(rs::Vector{Raw3}) = (s = 0.0; for r in rs; s += usetrip(mktrip(r.c, r.a, r.i)); end; s)
const CS = (c1, c2, c3, c4, c5)
const AS = (a1, a2, a3, a4, a5)
const IS = (i1, i2, i3, i4, i5)
pick(n::Int) = Raw3(CS[mod1(n, 5)], AS[mod1(n + 1, 5)], IS[mod1(n + 2, 5)])
function (@main)(args::Vector{String})::Cint
    n = length(args)
    println(Core.stdout, "picked ", enter3([pick(n + k) for k in 1:5]))
    println(Core.stdout, "fixed ", enter3([Raw3(c2, a3, i4), Raw3(c5, a1, i2)]))
    r = try
        enter3([Raw3(a1, a2, i1)])
        "no error"
    catch e
        e isa MethodError ? "MethodError" : "another error"
    end
    println(Core.stdout, "wrong signature: ", r)
    return 0
end
