# E-361 (3): TraitDifferentialEquations solving Lorenz with Tsit5 and Robertson with Rodas5.
# ODE_PLAIN=1 builds the plain twin (PlainODE); ODE_AD=1 adds a gradient of a loss through a solve (ForwardDiff).
const PLAIN = get(ENV, "ODE_PLAIN", "0") == "1"
const AD = get(ENV, "ODE_AD", "0") == "1"
@static if PLAIN
    using PlainODE; const ODE = PlainODE
    last1(s) = s.u[end][1]
else
    using TraitWorld, TraitDifferentialEquations; const ODE = TraitDifferentialEquations
    last1(s) = ODE.ODECore.state(s, length(ODE.ODECore.times(s)))[1]
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
function loss(p)
    s = ODE.solve(ODE.ODEProblem(lorenz!, [one(eltype(p)), zero(eltype(p)), zero(eltype(p))], (0.0, 1.0), p), ODE.Tsit5();
                  reltol = 1e-6, abstol = 1e-8)
    return last1(s)
end
function (@main)(args::Vector{String})::Cint
    a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]), ODE.Tsit5();
                  saveat = collect(range(0.0, 20.0; length = 2001)), reltol = 1e-6, abstol = 1e-8)
    println(Core.stdout, "lorenz ", round(last1(a); sigdigits = 6))
    b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.0]), ODE.Rodas5();
                  saveat = exp10.(range(-5, 5; length = 201)), reltol = 1e-6, abstol = 1e-8)
    println(Core.stdout, "robertson ", round(last1(b); sigdigits = 6))
    @static if AD
        g = ODE.gradient(loss, [10.0, 28.0, 8 / 3])
        println(Core.stdout, "gradient ", round(g[1]; sigdigits = 6), " ", round(g[2]; sigdigits = 6), " ", round(g[3]; sigdigits = 6))
    end
    return 0
end
PLAIN || include("verify.jl")
include("jllhole.jl")
