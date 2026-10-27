# E-168: the session of the plan (writeup/plans/2026-10-27-ttfx-sciml-makie.md §2) in Julia, upstream API
# (settings S, U, A, C). Marks "T <step> <epoch s> <compile s> <gc s>"; digests and versions after the last mark.
#     WL_SHAPE=matched|perturbed WL_ORDER=A|B julia --startup-file=no --project=<env> workload.jl <outdir>
# matched: Vector{Float64} parameters and saving times (as Python); perturbed: Tuple parameters and a range.
# A: the plotting library loaded with the solver; B: loaded after the first simulation.
Base.cumulative_compile_timing(true)
const G0 = Base.gc_num()
mark(step) = println("T ", step, " ", repr(time()), " ", Base.cumulative_compile_time_ns()[1] / 1e9, " ",
                     Base.GC_Diff(Base.gc_num(), G0).total_time / 1e9)
mark("start")
const SHAPE = get(ENV, "WL_SHAPE", "matched"); const ORDER = get(ENV, "WL_ORDER", "A")
using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
ORDER == "A" && @eval using CairoMakie
mark("load")
const OUT = isempty(ARGS) ? "out" : ARGS[1]
const RT, AT = 1e-6, 1e-8
function lorenz!(du, u, p, t)
    s, r, b = p
    du[1] = s * (u[2] - u[1]); du[2] = u[1] * (r - u[3]) - u[2]; du[3] = u[1] * u[2] - b * u[3]
    nothing
end
function robertson!(du, u, p, t)
    du[1] = -0.04u[1] + 1e4 * u[2] * u[3]
    du[2] = 0.04u[1] - 1e4 * u[2] * u[3] - 3e7 * u[2]^2
    du[3] = 3e7 * u[2]^2
    nothing
end
function vanderpol!(du, u, p, t)
    du[1] = u[2]; du[2] = p[1] * ((1 - u[1]^2) * u[2]) - u[1]
    nothing
end
shape(v::Vector{Float64}) = SHAPE == "matched" ? v : Tuple(v)
times(a, b, n) = SHAPE == "matched" ? collect(range(a, b; length = n)) : range(a, b; length = n)
const TL = times(0.0, 20.0, 2001); const TR = exp10.(range(-5, 5; length = 201)); const TV = times(0.0, 3000.0, 3001)
function solve_two()
    a = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), shape([10.0, 28.0, 8 / 3])), Tsit5(); saveat = TL, reltol = RT, abstol = AT)
    b = solve(ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), shape([0.0])), Rodas5P(); saveat = TR, reltol = RT, abstol = AT)
    a, b
end
a, b = solve_two()
mark("solve1")
ORDER == "B" && @eval using CairoMakie
include("plotting.jl")
plot_two(a, b, joinpath(OUT, "jl-1.png"))
mark("plot1")
c = solve(ODEProblem(vanderpol!, [2.0, 0.0], (0.0, 3000.0), shape([1000.0])), Rodas5P(); saveat = TV, reltol = RT, abstol = AT)
plot_one(c, joinpath(OUT, "jl-2.png"))
mark("model2")
a2, b2 = solve_two(); plot_two(a2, b2, joinpath(OUT, "jl-3.png"))
mark("again")
digest(name, sol, ts) = println("D ", name, " ", join((string(round(sol(t)[k]; sigdigits = 6)) for t in ts for k in 1:length(sol.u[1])), " "))
digest("lorenz", a, (1.0, 2.0)); digest("robertson", b, (1.0, 1e3, 1e5)); digest("vanderpol", c, (1000.0, 3000.0))
pngs(OUT, "jl-")
println("V julia ", Base.GIT_VERSION_INFO.commit_short, " ", Sys.BINDIR, " image ", unsafe_string(Base.JLOptions().image_file),
        " strict ", get(ENV, "JULIA_TW_STRICT", "0"), " shape ", SHAPE, " order ", ORDER)
println("V pkgs ", join(sort!([string(nameof(m), "@", pkgversion(m)) for m in values(Base.loaded_modules) if pkgversion(m) !== nothing]), " "))
mark("trailer")
