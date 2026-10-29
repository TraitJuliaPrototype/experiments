# E-242: what inferring the session's `solve_two` (ttfx/workload_d.jl) infers: the compiler's own timings
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
const C = Base.Compiler
C.Timings.reset_timings(); C.__set_measure_typeinf(true)
t = @elapsed precompile(solve_two, ())
C.__set_measure_typeinf(false)
root = C.Timings._timings[1]
rows = Tuple{Float64,Float64,String}[]
function walk(n)
    incl = n.time / 1e6
    exc = (n.time - sum((c.time for c in n.children); init = UInt64(0))) / 1e6
    push!(rows, (incl, exc, first(string(n.mi_info.mi), 200)))
    foreach(walk, n.children)
end
walk(root)
println("precompile(solve_two) ", round(1000t; digits = 1), " ms; inferred MethodInstances ", length(rows) - 1)
println("-- by inclusive time")
for r in sort(rows; by = first, rev = true)[1:min(25, end)]
    println(round(r[1]; digits = 1), " ms  (excl ", round(r[2]; digits = 1), ")  ", r[3])
end
