# E-159, checks 2 and 4: the front end outside its owner (the negative control, as DiffEqBase defines
# CommonSolve's `solve` for SciMLBase's problems), and the bounded form in the core's own trait module
# (lowering L-3), against a plain stand-in that owns `solve` (as CommonSolve does).
#     julia --project=TraitDifferentialEquations experiments/w34-sciml/move3/frontend.jl
using TraitDifferentialEquations, TraitWorld
import ODECore
module MiniCommonSolve                                   # owns `solve`, `init`, `solve!`, as CommonSolve does
function solve end
function init end
function solve! end
end
# the negative control: a third package's method on the stand-in's function for the core's type
module FrontEndElsewhere
import ..MiniCommonSolve, ODECore
MiniCommonSolve.solve(prob::ODECore.ODEProblem, alg; kw...) = ODECore.solve_ode(prob, alg, Any[], ODECore.SolverOptions(1e-6, 1e-3, Inf, 100_000, Float64[]))
end
m = only(methods(MiniCommonSolve.solve))
println("FRONTEND the negative control is a pirate by the letter: ", !TraitWorld.owned_method(m))
# the typed route: the core's own type, by the core (here written in a module standing for the core's package)
println("FRONTEND a typed method by the type's owner would be owned: the core owns `ODEProblem` (", parentmodule(ODECore.ODEProblem), ")")
# the bounded form by the core's trait module: a bounded method on a function the definer does not own
probe = quote
    @trait_module module CoreFrontEnd
    using TraitWorld
    using ODECore: ODEProblemTrait
    import ..MiniCommonSolve
    MiniCommonSolve.solve(prob::ODEProblemTrait, alg) = :bounded
    end
end
r = try
    Core.eval(Main, Expr(:toplevel, probe.args...))
    "defined"
catch e
    sprint(showerror, e)
end
println("FRONTEND a bounded `solve(prob::ODEProblemTrait, alg)` on the stand-in's function: ", first(r, 400))
# the default algorithm by the umbrella's own function (check 4)
f!(du, u, p, t) = (du .= -p .* u; nothing)
prob = ODEProblem(f!, [1.0], (0.0, 1.0), 0.5)
println("FRONTEND the default algorithm: ", solve(prob).u[end] == solve(prob, Tsit5()).u[end])
