# E-157 check 2: what an `rhs!` call costs and allocates, as the solver makes it (through the
# problem's bound, in trait code), `Dynamic` against `compiled_for`, with a `Vector` p, a named
# tuple p that is a bits type, and a named tuple p that is not (it holds a vector); against the
# plain function called directly. Lorenz (3 states) and ChainModel{PathGraph} (40 states).
# A quick regression check, not a benchmark: loops of ~0.3 s, the best of three.
include(joinpath(@__DIR__, "common.jl"))
using ChainModels
header("check 2", "per rhs! call: Dynamic against compiled_for; Vector and NamedTuple p")

@trait_module module Bench
using TraitWorld
using TraitDifferentialEquations
"`n` calls of the problem's `rhs!` through its bound, as the solvers call it."
function rhs_loop(prob::ODEProblemTrait{T,P}, du::Vector{T}, u::Vector{T}, n::Int) where {T,P}
    for _ in 1:n
        rhs!(prob, du, u, 0.0)
    end
    return nothing
end
end

lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
lorenzw!(du, u, p, t) = (c = p.c; s = p.scale; du[1] = s * c[1] * (u[2] - u[1]); du[2] = u[1] * (s * c[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - s * c[3] * u[3]; nothing)

"Time and allocations of `n` calls through the bound, measured inside a typed plain function."
function through_bound(prob, du, u, n)
    g0 = Base.gc_num(); t0 = time_ns()
    Bench.rhs_loop(prob, du, u, n)
    t1 = time_ns(); d = Base.GC_Diff(Base.gc_num(), g0)
    return (t1 - t0) / n, d.allocd / n, Base.gc_alloc_count(d) / n
end
function direct(f::F, du, u, p, n) where {F}
    g0 = Base.gc_num(); t0 = time_ns()
    for _ in 1:n
        f(du, u, p, 0.0)
    end
    t1 = time_ns(); d = Base.GC_Diff(Base.gc_num(), g0)
    return (t1 - t0) / n, d.allocd / n, Base.gc_alloc_count(d) / n
end
function best(g, n)
    g(1000)                               # warm-up (compiles)
    t1 = g(10_000)[1]
    m = max(10_000, round(Int, 0.3e9 / max(t1, 0.1)))    # ~0.3 s per loop
    rs = [g(m) for _ in 1:3]
    ns = minimum(r[1] for r in rs)
    return (ns = ns, bytes = rs[end][2], allocs = rs[end][3], n = m)
end

const PV = [10.0, 28.0, 8 / 3]
const PNT = (σ = 10.0, ρ = 28.0, β = 8 / 3)               # a bits type
const PNTW = (c = [10.0, 28.0, 8 / 3], scale = 1.0)        # not a bits type
const CV = [1.0, 0.1]
const CNT = (k = 1.0, d = 0.1)
const CNTW = (k = 1.0, d = 0.1, w = fill(1.0, 40))
cases = [
    ("Lorenz, p::Vector{Float64}", lorenz!, PV, 3),
    ("Lorenz, p::NamedTuple (bits)", lorenz!, PNT, 3),
    ("Lorenz, p::NamedTuple (holds a Vector)", lorenzw!, PNTW, 3),
    ("ChainModel{PathGraph}, p::Vector{Float64}", ChainModel(PathGraph(40)), CV, 40),
    ("ChainModel{PathGraph}, p::NamedTuple (bits)", ChainModel(PathGraph(40)), CNT, 40),
    ("ChainModel{PathGraph}, p::NamedTuple (holds a Vector)", ChainModel(PathGraph(40)), CNTW, 40),
]
println(rpad("case", 56), rpad("mode", 14), lpad("ns/call", 9), lpad("bytes/call", 12), lpad("allocs/call", 13), lpad("calls", 12))
for (label, f, p, n) in cases
    u = collect(range(0.1, 1.0; length = n)); du = zeros(n)
    rd = best(m -> direct(f, du, u, p, m), 0)
    for (mode, ff) in (("Dynamic", f), ("compiled_for", compiled_for(f)))
        prob = ODEProblem(ff, u, (0.0, 1.0), p)
        r = best(m -> through_bound(prob, du, u, m), 0)
        @printf("%-56s%-14s%9.2f%12.1f%13.3f%12d\n", label, mode, r.ns, r.bytes, r.allocs, r.n)
    end
    @printf("%-56s%-14s%9.2f%12.1f%13.3f%12d\n", label, "direct (plain)", rd.ns, rd.bytes, rd.allocs, rd.n)
    p isa NamedTuple && println("   isbits(p) = ", isbits(p), "; problem type under Dynamic: ", nameof(typeof(ODEProblem(f, u, (0.0, 1.0), p))),
                                "{…, P = ", typeof(p), "}")
end
footer()
