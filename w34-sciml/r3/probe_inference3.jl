# E-242: inference of the umbrella's solve path at abstract problem types, piece by piece (after vs before)
using TraitDifferentialEquations, TraitMakie
const ODE = TraitDifferentialEquations; const OC = ODE.ODECore
pt(name, f) = (t = @elapsed f(); println(rpad(name, 60), round(1000t; digits = 1), " ms"))
O = OC.SolverOptions
pt("solve_ode(::Any, ::Tsit5, …)", () -> precompile(OC.solve_ode, (Any, OC.Tsit5, Vector{Any}, O)))
pt("tsit5_init(::Any, ::Vector{Float64}, …)", () -> precompile(OC.tsit5_init, (Any, Vector{Float64}, Tuple{Float64,Float64}, Vector{Any}, O)))
pt("tsit5_advance!(::Tsit5Integrator{Float64})", () -> precompile(OC.tsit5_advance!, (OC.Tsit5Integrator{Float64},)))
pt("run_to_end!(::Any)", () -> precompile(OC.run_to_end!, (Any,)))
isdefined(OC, :kept_interpolant) && pt("kept_interpolant(::Any)", () -> precompile(OC.kept_interpolant, (Any,)))
isdefined(OC, :HermiteSteps) && pt("kept_interpolant(::HermiteSteps{Float64})", () -> precompile(OC.kept_interpolant, (OC.HermiteSteps{Float64},)))
pt("with_problem(::CoreSolution{Float64}, ::Any, …)", () -> precompile(OC.with_problem, (OC.CoreSolution{Float64}, Any, Any, Any, Vector{Float64}, Any)))
pt("_solve(::Any, ::Tsit5, …)", () -> precompile(ODE._solve, (Any, OC.Tsit5, Vector{Any}, O)))
KW = NamedTuple{(:saveat, :reltol, :abstol), Tuple{Vector{Float64}, Float64, Float64}}
pt("kwcall solve(::Any, ::Tsit5)", () -> precompile(Core.kwcall, (KW, typeof(ODE.solve), Any, OC.Tsit5)))
