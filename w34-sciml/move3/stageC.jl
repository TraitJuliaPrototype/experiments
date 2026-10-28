# E-220 (SciML move 3, stage C): linear solvers inside Rodas5. Results with each linear solver; a user's own at
# the prompt; the CodeInstances a new linear solver makes in the solver package (TraitRodas) under `Dynamic`
# and under its own type; the time of a stiff solve per linear solver.
#     julia --project=experiments/w34-sciml/move3/envC experiments/w34-sciml/move3/stageC.jl
using TraitDifferentialEquations, TraitLinSolvers, TraitWorld
import ODECore, LinearAlgebra
function rober!(du, u, p, t)
    k1, k2, k3 = p
    du[1] = -k1 * u[1] + k3 * u[2] * u[3]
    du[2] = k1 * u[1] - k2 * u[2]^2 - k3 * u[2] * u[3]
    du[3] = k2 * u[2]^2
    nothing
end
prob = ODEProblem(rober!, [1.0, 0.0, 0.0], (0.0, 1e5), [0.04, 3e7, 1e4])
ref = solve(prob, Rodas5(); abstol = 1e-8, reltol = 1e-6)
# a user's linear solver at the prompt: Base's backslash on a copy
struct Backslash end
mutable struct BackslashCache; W::Matrix{Float64}; end
@implement ODECore.LinearCache BackslashCache begin
    linfactor!(c, W) = (copyto!(c.W, W); nothing)
    linsolve!(c, x, b) = (x .= c.W \ b; nothing)
end
@implement ODECore.LinearSolver Backslash begin
    lincache(ls, n) = BackslashCache(zeros(n, n))
end
for (name, ls) in ["DenseLU (default)" => DenseLU(), "DenseQR (TraitLinSolvers)" => DenseQR(), "Backslash (the prompt)" => Backslash(),
                   "Dynamic DenseQR" => with_dynamic(DenseQR())]
    s = solve(prob, Rodas5(linsolve = ls); abstol = 1e-8, reltol = 1e-6)
    err = maximum(abs.(s.u[end] .- ref.u[end]))
    println("C ", rpad(name, 28), "steps ", length(s.t), ", max |u - u_LU| at the end ", err, ", identical to LU: ", s.u == ref.u)
end
rodasmod = only(m for (id, m) in Base.loaded_modules if id.name == "TraitRodas")
function newcis(f)
    new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
    t = @elapsed f()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    n = count(ci -> ci isa Core.CodeInstance && (m = (ci.def isa Core.MethodInstance ? ci.def : ci.def.def).def; m isa Method && Base.moduleroot(m.module) === rodasmod), new)
    return n, t
end
struct Backslash2 end
@implement ODECore.LinearSolver Backslash2 begin
    lincache(ls, n) = BackslashCache(zeros(n, n))
end
n1, t1 = newcis(() -> solve(prob, Rodas5(linsolve = with_dynamic(Backslash())); abstol = 1e-8, reltol = 1e-6))
n2, t2 = newcis(() -> solve(prob, Rodas5(linsolve = with_dynamic(Backslash2())); abstol = 1e-8, reltol = 1e-6))
n3, t3 = newcis(() -> solve(prob, Rodas5(linsolve = Backslash2()); abstol = 1e-8, reltol = 1e-6))
println("C a new linear solver, Dynamic, after another Dynamic one: ", n2, " CodeInstances of TraitRodas (", round(t2 * 1e3; digits = 1), " ms); the first Dynamic: ", n1)
println("C the same solver as its own type (Compiled): ", n3, " CodeInstances of TraitRodas (", round(t3 * 1e3; digits = 1), " ms)")
for (name, ls) in ["DenseLU" => DenseLU(), "Dynamic DenseLU" => with_dynamic(DenseLU()), "DenseQR" => DenseQR()]
    a = Rodas5(linsolve = ls)
    solve(prob, a; abstol = 1e-8, reltol = 1e-6)
    t = minimum(@elapsed(solve(prob, a; abstol = 1e-8, reltol = 1e-6)) for _ in 1:20)
    println("C time of the stiff solve, ", rpad(name, 16), round(t * 1e6; digits = 1), " µs")
end
