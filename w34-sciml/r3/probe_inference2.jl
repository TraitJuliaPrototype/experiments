# E-242: (probe_inference.jl split by call) what inferring the session's `solve_two` (ttfx/workload_d.jl) infers: the compiler's own timings
# (Base.Compiler.Timings), the costliest MethodInstances by exclusive time, after vs before (run in either env).
using TraitDifferentialEquations, TraitMakie
const ODE = TraitDifferentialEquations
const RT, AT = 1e-6, 1e-8
function lorenz!(du, u, p, t)
    s, r, b = p
    du[1] = s * (u[2] - u[1]); du[2] = u[1] * (r - u[3]) - u[2]; du[3] = u[1] * u[2] - b * u[3]
    nothing
end
function robertson!(du, u, p, t)
    du[1] = -0.04u[1] + 1e4 * u[2] * u[3]; du[2] = 0.04u[1] - 1e4 * u[2] * u[3] - 3e7 * u[2]^2; du[3] = 3e7 * u[2]^2
    nothing
end
const SHAPE = get(ENV, "WL_SHAPE", "matched")
shape(v::Vector{Float64}) = SHAPE == "matched" ? v : Tuple(v)
times(a, b, n) = SHAPE == "matched" ? collect(range(a, b; length = n)) : range(a, b; length = n)
const TL = times(0.0, 20.0, 2001); const TR = exp10.(range(-5, 5; length = 201))
function solve_two()
    a = ODE.solve(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), shape([10.0, 28.0, 8 / 3])), ODE.Tsit5(); saveat = TL, reltol = RT, abstol = AT)
    b = ODE.solve(ODE.ODEProblem(robertson!, [1.0, 0.0, 0.0], (0.0, 1e5), shape([0.0])), ODE.Rodas5(); saveat = TR, reltol = RT, abstol = AT)
    a, b
end
pt(name, f) = (t = @elapsed f(); println(rpad(name, 50), round(1000t; digits = 1), " ms"))
PL = typeof(ODE.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3]))
KW = NamedTuple{(:saveat, :reltol, :abstol), Tuple{Vector{Float64}, Float64, Float64}}
pt("ODEProblem(lorenz!, …, Vector)", () -> precompile(ODE.ODEProblem, (typeof(lorenz!), Vector{Float64}, Tuple{Float64,Float64}, Vector{Float64})))
pt("ODEProblem(lorenz!, …, Tuple)", () -> precompile(ODE.ODEProblem, (typeof(lorenz!), Vector{Float64}, Tuple{Float64,Float64}, NTuple{3,Float64})))
pt("kwcall solve(::Any, ::Tsit5)", () -> precompile(Core.kwcall, (KW, typeof(ODE.solve), Any, ODE.Tsit5)))
pt("kwcall solve(::ODEProblem, ::Tsit5)", () -> precompile(Core.kwcall, (KW, typeof(ODE.solve), PL, ODE.Tsit5)))
pt("kwcall solve(::ODEProblem, ::Rodas5)", () -> precompile(Core.kwcall, (KW, typeof(ODE.solve), PL, typeof(ODE.Rodas5()))))
pt("solve_two", () -> precompile(solve_two, ()))
println("return type of ODEProblem(lorenz!, …): ", Base.return_types(ODE.ODEProblem, (typeof(lorenz!), Vector{Float64}, Tuple{Float64,Float64}, Vector{Float64})))
println("return type of solve: ", Base.return_types(Core.kwcall, (KW, typeof(ODE.solve), PL, ODE.Tsit5)))
