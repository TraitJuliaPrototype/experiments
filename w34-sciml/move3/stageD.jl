# E-221 (SciML move 3, stage D): implicit Euler (TraitImplicit) with nonlinear solvers (the core's Newton,
# TraitNLSolvers' SimplifiedNewton) with linear solvers (the core's DenseLU, TraitLinSolvers' DenseQR), nested.
#     julia --project=experiments/w34-sciml/move3/envC experiments/w34-sciml/move3/stageD.jl
using TraitDifferentialEquations, TraitImplicit, TraitNLSolvers, TraitLinSolvers, TraitWorld
import ODECore
decay!(du, u, p, t) = (du .= -p .* u; nothing)
p = [2.0, 0.5]; u0 = [1.0, 3.0]; dt = 0.01
prob = ODEProblem(decay!, u0, (0.0, 1.0), p)
exact = u0 ./ (1 .+ p .* dt) .^ 100
combos = ["Newton, DenseLU" => ODECore.Newton(),
          "Newton, DenseQR" => ODECore.Newton(linsolve = DenseQR()),
          "SimplifiedNewton, DenseLU" => SimplifiedNewton(),
          "SimplifiedNewton, Dynamic DenseQR" => SimplifiedNewton(linsolve = with_dynamic(DenseQR())),
          "Dynamic Newton, Dynamic DenseLU" => with_dynamic(ODECore.Newton(linsolve = with_dynamic(DenseLU())))]
for (name, nl) in combos
    s = solve(prob, ImplicitEuler(dt = dt, nlsolve = nl))
    println("D ", rpad(name, 36), "steps ", length(s.t) - 1, ", ", s.retcode, ", max error against the exact discrete solution ",
            maximum(abs.(s.u[end] .- exact)))
end
function rober!(du, u, p, t)
    k1, k2, k3 = p
    du[1] = -k1 * u[1] + k3 * u[2] * u[3]
    du[2] = k1 * u[1] - k2 * u[2]^2 - k3 * u[2] * u[3]
    du[3] = k2 * u[2]^2
    nothing
end
rp = ODEProblem(rober!, [1.0, 0.0, 0.0], (0.0, 40.0), [0.04, 3e7, 1e4])
ref = solve(rp, Rodas5(); abstol = 1e-10, reltol = 1e-8)
for (name, nl) in ["Newton" => ODECore.Newton(), "SimplifiedNewton" => SimplifiedNewton()]
    s = solve(rp, ImplicitEuler(dt = 0.01, nlsolve = nl))
    println("D Robertson, implicit Euler at dt 0.01, ", rpad(name, 17), s.retcode, ", |u - u_Rodas5| at t = 40: ", maximum(abs.(s.u[end] .- ref.u[end])),
            " (first order), mass conserved to ", abs(sum(s.u[end]) - 1))
end
function newcis(f, names)
    new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
    t = @elapsed f()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    mods = [only(m for (id, m) in Base.loaded_modules if id.name == n) for n in names]
    counts = [count(ci -> ci isa Core.CodeInstance && (m = (ci.def isa Core.MethodInstance ? ci.def : ci.def.def).def; m isa Method && Base.moduleroot(m.module) === M), new) for M in mods]
    return counts, t
end
# a user's nonlinear solver at the prompt, and a user's linear solver inside it, each Dynamic: written in a trait
# module at the prompt, where a trait's name bounds a struct parameter and keeps a field (traits §7.2, §7.4)
@trait_module module UserSolvers
using TraitWorld
import ODECore, LinearAlgebra
export MyNewton, MyLU
struct MyNewton{L <: ODECore.LinearSolver}; linsolve::L; end
struct MyNewtonCache; ls::ODECore.LinearSolver; J::Matrix{Float64}; r::Vector{Float64}; dx::Vector{Float64}; fx::Vector{Float64}; end
@implement ODECore.NLCache MyNewtonCache begin
    nlstage!(c, m, x, z, t, γdt) = ODECore.newton_stage!(c.ls, c.J, c.r, c.dx, c.fx, 30, 1e-10, false, m, x, z, t, γdt)
end
@implement ODECore.NonlinearSolver MyNewton{L} where {L} begin
    nlcache(nl, n) = MyNewtonCache(nl.linsolve, zeros(n, n), zeros(n), zeros(n), zeros(n))
end
struct MyLU end
@implement ODECore.LinearSolver MyLU begin
    linfactor(ls, W) = LinearAlgebra.lu(W)
end
end
using .UserSolvers
names = ["TraitImplicit", "ODECore"]
c1, t1 = newcis(() -> solve(prob, ImplicitEuler(dt = dt, nlsolve = with_dynamic(MyNewton(with_dynamic(DenseLU()))))), names)
c2, t2 = newcis(() -> solve(prob, ImplicitEuler(dt = dt, nlsolve = with_dynamic(MyNewton(with_dynamic(MyLU()))))), names)
println("D a user's nonlinear solver, Dynamic, its linear solver Dynamic: CodeInstances of TraitImplicit, ODECore ", c1, " (", round(t1 * 1e3; digits = 1), " ms)")
println("D the same with a user's linear solver inside, Dynamic: ", c2, " (", round(t2 * 1e3; digits = 1), " ms)")
s = solve(prob, ImplicitEuler(dt = dt, nlsolve = with_dynamic(MyNewton(with_dynamic(MyLU())))))
println("D the user's pair against the exact discrete solution: ", maximum(abs.(s.u[end] .- exact)))
