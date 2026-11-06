# E-261's work step for the g2all-shaped session: experiments/facts/g2all.jl's work(), twice
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
const _xs = collect(range(0.0, 10.0; length = 200))
function _work()
    TDE = TraitDifferentialEquations
    TDE.solve(TDE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), TDE.Tsit5())
    TDE.solve(TDE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), TDE.Rodas5())
    TDE.solve(TDE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), TDE.Tsit5();
              callback = TDE.DiscreteCallback((u, t, i) -> t > 0.5, i -> (i.u[1] += 1.0; nothing)))
    f = TraitMakie.lines(_xs, sin.(_xs); color = :blue); TraitMakie.scatter!(f, _xs[1:10:end], cos.(_xs[1:10:end]); color = :red)
    TraitMakie.save(joinpath(tempdir(), "e261-g2work.png"), f)
end
_work(); _work()
