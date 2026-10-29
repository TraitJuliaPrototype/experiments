# W-88, open issue 105: callback values entered by bounded dispatch (TDE core.jl `_enter_callback!`):
# a callback type in its cast and kept forms reaches its vector; a value of neither trait is refused.
# Run from TraitDifferentialEquations/: julia --project=. ../experiments/checks/w88-105/callbacks-probe.jl
using TraitDifferentialEquations, TraitWorld
include(joinpath(pwd(), "examples", "LorenzModels", "src", "LorenzModels.jl"))
using .LorenzModels
const U0 = [1.0, 0.0, 0.0]
lp() = LorenzProblem(U0, (0.0, 1.0), 10.0, 28.0, 8 / 3)
ref = solve(lp(), Tsit5(); callback = Bounce(5.0)).u
P = typeof(lp().p)
CB = TraitDifferentialEquations.ODECore.Callback{Vector{Float64}, Float64, P}
for (name, cb) in (("plain", Bounce(5.0)), ("compiled_for", compiled_for(Bounce(5.0))),
                   ("with_dynamic", with_dynamic(Bounce(5.0))), ("Dynamic{Callback}", Dynamic{CB}(Bounce(5.0))),
                   ("Kept{Callback}", Kept{CB}(Bounce(5.0))))
    println("RESULT ", name, ": same solution = ", solve(lp(), Tsit5(); callback = cb).u == ref)
end
struct Neither end
e = try; solve(lp(), Tsit5(); callback = Neither()); nothing; catch err; err; end
println("RESULT neither: ", typeof(e))
println(sprint(showerror, e)[1:min(end, 600)])
