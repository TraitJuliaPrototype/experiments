# E-357: a demonstrator's session: the packages and the work. Expects `kind` (D, Dp, T, Tp), `csv`, `out`.
mkpath(out)
t0 = @elapsed if kind == "D"
    @eval using TraitDifferentialEquations, TraitMakie
    @eval const ODE = TraitDifferentialEquations; @eval const PL = TraitMakie
elseif kind == "Dp"
    @eval using PlainODE, PlainPlots
    @eval const ODE = PlainODE; @eval const PL = PlainPlots
elseif kind == "T"
    @eval using TraitCSV, TraitTables, TraitMakie
    @eval const RD = TraitCSV.read; @eval const TB = TraitTables; @eval const PL = TraitMakie
else
    @eval using PlainTables, PlainPlots
    @eval const RD = PlainTables.readcsv; @eval const TB = PlainTables; @eval const PL = PlainPlots
end
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
@eval begin
    ts(s) = $(kind == "D") ? ODE.ODECore.times(s) : s.t
    comp(s, k) = $(kind == "D") ? [ODE.ODECore.state(s, i)[k] for i in 1:length(ODE.ODECore.times(s))] : getindex.(s.u, k)
    pts(s, k) = $(kind == "D") ? ODE.plotpoints(s, k) : hcat(ts(s), comp(s, k))
end
function work_d()
    a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), ODE.Tsit5();
                  saveat = collect(range(0.0, 20.0; length = 2001)), reltol = 1e-6, abstol = 1e-8)
    b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), ODE.Rodas5();
                  saveat = exp10.(range(-5, 5; length = 201)), reltol = 1e-6, abstol = 1e-8)
    f = PL.lines(pts(a, 1)); PL.lines!(f, pts(a, 2)); PL.lines!(f, pts(a, 3)); PL.save(joinpath(out, "d.png"), f)
    string(hash((round.(comp(a, 1)[[100, 2001]]; sigdigits = 6), round.(comp(b, 1)[[50, 201]]; sigdigits = 6))); base = 16)
end
function work_t()
    t = RD(csv)
    s = TB.summary_text(t)
    x = TB.floats(t, TB.colnames(t)[1])
    f = PL.hist(x; bins = 24, title = "loads", size = (1200, 800))
    PL.vlines!(f, sum(x) / length(x); color = :red)
    PL.save(joinpath(out, "t.png"), f)
    string(hash((s, sum(x))); base = 16)
end
const w = kind in ("D", "Dp") ? work_d : work_t
