# E-158 check 3: in a callback, `integ.p` is typed `P`, and a write to its contents reaches the solve.
# Check 4: a callback type without `affect!` is refused at `@implement` (and two neighbours: a
# condition of the wrong result type; a callback type at other parameters than the problem's).
include("common.jl")
const TDE = TraitDifferentialEquations
include("models.jl")
using LorenzModels
header("checks 3, 4", "integ.p typed in a callback; a callback type without affect! refused at @implement")

const OV = Dynamic{IntegratorView{Vector{Float64}, Float64, OscParams}}
println("Check 3: the integrator as callbacks see it, ", OV)
for (lbl, f) in (("integ.p", i -> i.p), ("integ.p.k", i -> i.p.k), ("integ.u", i -> i.u), ("integ.t", i -> i.t), ("integ.dt", i -> i.dt))
    rt = Base.return_types(f, (OV,))
    println("  ", rpad(lbl, 10), " infers ", rt)
end
check("integ.p infers OscParams (plain code reading the kept view)", Base.return_types(i -> i.p, (OV,)) == [OscParams])
check("integ.p.k infers Float64", Base.return_types(i -> i.p.k, (OV,)) == [Float64])
# inside the user's affect! closure as the library calls it (the Callable's signature fixes the argument)
aff = i -> (i.p.c = 0.5; nothing)
check("an affect! closure writing integ.p.c infers at the declared argument", Base.return_types(aff, (OV,)) == [Nothing])
# a callback type's own method (LorenzModels.RaiseSigma reads integ.p.σ without an assertion)
LV = Dynamic{IntegratorView{Vector{Float64}, Float64, LorenzParams{Float64}}}
rt_rs = Base.return_types(TDE.condition, (LorenzModels.RaiseSigma, Vector{Float64}, Float64, LV))
println("  RaiseSigma's condition (reads integ.p.σ, no assertion) infers ", rt_rs)
check("a callback type's method reads integ.p at LorenzParams{Float64}", rt_rs == [Bool])
ci = code_typed(TDE.affect!, (LorenzModels.RaiseSigma, LV))[1]
println("  RaiseSigma's affect! typed: ", ci.second, "; dynamic calls in its body: ", count(x -> x isa Expr && x.head === :call && !(x.args[1] isa GlobalRef && x.args[1].mod === Core), ci.first.code))
# the write reaches the solve: p.c changed by the damping callback (check 1's set), the solution differs from one without it
log = Any[]; p = oscp()
dset = discrete_set(TDE.add_tstop!, TDE.terminate!, log)
s_all = TDE.solve(TDE.ODEProblem(osc!, [1.0, 0.0], (0.0, 10.0), p), TDE.Tsit5(); callback = Any[TDE.DiscreteCallback(c, a) for (c, a) in dset])
p2 = oscp()
s_nodamp = TDE.solve(TDE.ODEProblem(osc!, [1.0, 0.0], (0.0, 10.0), p2), TDE.Tsit5();
                     callback = Any[TDE.DiscreteCallback(c, a) for (c, a) in dset[[1, 3]]])
k4 = findfirst(>=(4.0), s_all.t)
println("  p after the solve: ", (p.k, p.c, p.tk), "; without the damping callback: ", (p2.k, p2.c, p2.tk))
check("the write to integ.p.c reached the user's p", p.c == 0.5 && p2.c == 0.1)
check("… and the solve: equal before t = 4, different after", s_all.u[1:k4] == s_nodamp.u[1:k4] && s_all.u[end] != s_nodamp.u[end],
      "u at t = 4: equal; final u $(s_all.u[end]) vs $(s_nodamp.u[end])")

println("\nCheck 4: callback types refused at @implement")
caught(f) = try f(); nothing catch e; e end
etext(e) = e === nothing ? "accepted" : string(typeof(e), ": ", first(split(sprint(showerror, e), '\n'), 3) |> x -> join(x, " / "))
module U4
using TraitWorld, TraitDifferentialEquations
const V = Dynamic{IntegratorView{Vector{Float64}, Float64, Vector{Float64}}}
struct NoAffect end
TraitDifferentialEquations.condition(cb::NoAffect, u::Vector{Float64}, t::Float64, integ::V) = u[1] > 1.0
struct WithAffect end
TraitDifferentialEquations.condition(cb::WithAffect, u::Vector{Float64}, t::Float64, integ::V) = u[1] > 0.5
TraitDifferentialEquations.affect!(cb::WithAffect, integ::V) = (integ.u[1] = 0.0; nothing)
struct IntCondition end
TraitDifferentialEquations.condition(cb::IntCondition, u::Vector{Float64}, t::Float64, integ::V) = 1
TraitDifferentialEquations.affect!(cb::IntCondition, integ::V) = nothing
end
e1 = caught(() -> Core.eval(U4, :(@implement Callback{Vector{Float64}, Float64, Vector{Float64}} NoAffect)))
println("  NoAffect (condition only): ", etext(e1))
check("a callback type without affect! is refused at @implement (ImplementError, at the macro's expansion)", e1 isa ImplementError || (e1 isa LoadError && e1.error isa ImplementError))
e2 = caught(() -> Core.eval(U4, :(@implement Callback{Vector{Float64}, Float64, Vector{Float64}} WithAffect)))
println("  WithAffect (both): ", etext(e2))
check("the same type with affect! is accepted", e2 === nothing)
e3 = caught(() -> Core.eval(U4, :(@implement Callback{Vector{Float64}, Float64, Vector{Float64}} IntCondition)))
println("  IntCondition (condition returns Int): ", etext(e3))
check("a condition returning Int is refused at @implement", e3 isa ImplementError)
decay!(du, u, p, t) = (du .= -p[1] .* u; nothing)
s = TDE.solve(TDE.ODEProblem(decay!, [1.0], (0.0, 1.0), [-1.0]), TDE.Tsit5(); callback = U4.WithAffect())
check("WithAffect acts in a solve (P = Vector{Float64})", s.u[end][1] < 0.6 && any(u -> u[1] == 0.0, s.u), string(s.u[end]))
# a callback type at other parameters than the problem's: refused at init
e5 = caught(() -> TDE.solve(TDE.ODEProblem(osc!, [1.0, 0.0], (0.0, 1.0), oscp()), TDE.Tsit5(); callback = U4.WithAffect()))
println("  WithAffect (P = Vector{Float64}) given to a problem with P = OscParams: ", etext(e5))
check("a callback type at other parameters is refused when init keeps it (Kept{Callback{U, T, P}}(cb))",
      e5 !== nothing && !(e5 isa TraitWorld.TraitArgumentError), "refused only at its first call: repro_kept_params.jl")
footer()
