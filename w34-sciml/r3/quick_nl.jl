# E-242: TDE's nonlinear tests alone (test/nonlinear.jl), for quick iteration; run with --project=<TDE>
using Test, TraitDifferentialEquations, TraitWorld
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
const P0 = [10.0, 28.0, 8 / 3]
const U0 = [1.0, 0.0, 0.0]
const REF = [-9.408450567056128, -9.096199071186515, 28.581627624392613]
caught(f) = try; f(); nothing; catch e; e; end
for f in ARGS
    include(joinpath(dirname(pathof(TraitDifferentialEquations)), "..", "test", f))
end
