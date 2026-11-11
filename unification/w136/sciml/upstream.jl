# E-363: the three cases on upstream SciML (OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, SciMLBase).
using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, SciMLBase
const FD = Base.require(Base.PkgId(Base.UUID("f6369f11-7733-5829-9624-2563aa707210"), "ForwardDiff"))
include(joinpath(@__DIR__, "report.jl"))
println("versions: OrdinaryDiffEqTsit5 ", pkgversion(OrdinaryDiffEqTsit5), ", OrdinaryDiffEqRosenbrock ", pkgversion(OrdinaryDiffEqRosenbrock),
        ", SciMLBase ", pkgversion(SciMLBase), ", ForwardDiff ", pkgversion(FD))
function lorenz!(du, u, p, t)
    du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]
    nothing
end
const U0 = [1.0, 0.0, 0.0]
report("upstream", "1-noparams", () -> solve(ODEProblem(lorenz!, U0, (0.0, 1.0)), Tsit5()))
const cache = zeros(3)
function cached!(du, u, p, t)
    cache .= u                       # a Float64 buffer: it cannot hold dual numbers
    lorenz!(du, cache, p, t)
end
const prob = ODEProblem(cached!, U0, (0.0, 1.0), [10.0, 28.0, 8 / 3])
loss(p) = sum(solve(remake(prob; p, u0 = eltype(p).(prob.u0)), Tsit5(); saveat = 0.5)[end])
report("upstream", "2-dualcache-gradient", () -> FD.gradient(loss, [10.0, 28.0, 8 / 3]))
report("upstream", "3-dualcache-rodas5", () -> solve(prob, Rodas5()))
T = string(typeof(init(prob, Tsit5())))
println("upstream | typeof(integrator) | ", sizeof(T), " characters, ", count(==('{'), T), " type-parameter lists")
