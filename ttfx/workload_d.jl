# E-168, settings D and Dp: the session of the plan (§2) with the demonstrators (D: TraitDifferentialEquations,
# TraitMakie) or their plain twins (Dp: PlainODE, PlainPlots). Rodas5 for Rodas5P (none there); no log axis,
# and two PNGs for the first plot (no layout of two axes). Same marks, variants and trailer as workload.jl.
#     WL_D=trait|plain WL_SHAPE=… WL_ORDER=… julia --startup-file=no --project=env_d workload_d.jl <outdir>
Base.cumulative_compile_timing(true)
const G0 = Base.gc_num()
mark(step) = println("T ", step, " ", repr(time()), " ", Base.cumulative_compile_time_ns()[1] / 1e9, " ",
                     Base.GC_Diff(Base.gc_num(), G0).total_time / 1e9)
mark("start")
const SHAPE = get(ENV, "WL_SHAPE", "matched"); const ORDER = get(ENV, "WL_ORDER", "A"); const KIND = get(ENV, "WL_D", "trait")
KIND == "trait" ? (@eval using TraitDifferentialEquations; @eval const ODE = TraitDifferentialEquations) :
                  (@eval using PlainODE; @eval const ODE = PlainODE)
loadplots() = KIND == "trait" ? (@eval using TraitMakie; @eval const PL = TraitMakie) : (@eval using PlainPlots; @eval const PL = PlainPlots)
ORDER == "A" && loadplots()
haskey(ENV, "WL_CACHE") && @eval using $(Symbol(ENV["WL_CACHE"]))   # E-172: a cache across sessions, emulated
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
# the solution's times and component k, for either library
ts(s) = KIND == "trait" ? ODE.ODECore.times(s) : s.t
comp(s, k) = KIND == "trait" ? [ODE.ODECore.state(s, i)[k] for i in 1:length(ODE.ODECore.times(s))] : getindex.(s.u, k)
function solve_two()
    a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), shape([10.0, 28.0, 8 / 3])), ODE.Tsit5(); saveat = TL, reltol = RT, abstol = AT)
    b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), shape([0.0])), ODE.Rodas5(); saveat = TR, reltol = RT, abstol = AT)
    a, b
end
function plot_two(a, b, path)
    f = PL.lines(ts(a), comp(a, 1)); PL.lines!(f, ts(a), comp(a, 2)); PL.lines!(f, ts(a), comp(a, 3)); PL.save(path, f)
    g = PL.lines(ts(b), comp(b, 1)); PL.lines!(g, ts(b), comp(b, 2) .* 1e4); PL.lines!(g, ts(b), comp(b, 3))
    PL.save(replace(path, ".png" => "b.png"), g)
end
a, b = solve_two()
mark("solve1")
ORDER == "B" && loadplots()
plot_two(a, b, joinpath(OUT, "d-1.png"))
mark("plot1")
c = ODE.solve(ODE.ODEProblem(vanderpol!, [2.0, 0.0], (0.0, 3000.0), shape([1000.0])), ODE.Rodas5(); saveat = TV, reltol = RT, abstol = AT)
PL.save(joinpath(OUT, "d-2.png"), PL.lines(ts(c), comp(c, 1)))
mark("model2")
a2, b2 = solve_two(); plot_two(a2, b2, joinpath(OUT, "d-3.png"))
mark("again")
function digest(name, s, tq)
    tt = ts(s); n = length(comp(s, 1)) > 0 ? (KIND == "trait" ? length(ODE.ODECore.state(s, 1)) : length(s.u[1])) : 0
    println("D ", name, " ", join((string(round(comp(s, k)[argmin(abs.(tt .- t))]; sigdigits = 6)) for t in tq for k in 1:n), " "))
end
digest("lorenz", a, (1.0, 2.0)); digest("robertson", b, (1.0, 1e3, 1e5)); digest("vanderpol", c, (1000.0, 3000.0))
include("pngs.jl"); pngs(OUT, "d-")
println("V julia ", Base.GIT_VERSION_INFO.commit_short, " ", Sys.BINDIR, " kind ", KIND, " strict ", get(ENV, "JULIA_TW_STRICT", "0"), " shape ", SHAPE, " order ", ORDER)
println("V pkgs ", join(sort!([string(nameof(m), "@", pkgversion(m)) for m in values(Base.loaded_modules) if pkgversion(m) !== nothing]), " "))
mark("trailer")
