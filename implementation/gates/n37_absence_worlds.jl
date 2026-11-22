# project: TraitWorld
# n37 (compiler §4.8): code that folds a pair's absence holds only in the worlds where the absence does. A membership
# held, then taken back; a function first compiled after that folds `x isa IX` to false. Called in the world where
# the membership held, it answers true: its code's worlds begin after the membership was taken back.
#     experiments/implementation/gates/run_all.sh <tree> 'n37_*'
using TraitWorld
@trait IX
struct IS end
g(x) = x isa IX
h(x) = g(x)
@implement IX IS
const w_held = Base.get_world_counter()
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), IS, IX, Main)
@assert Base.invokelatest(h, IS()) === false "after the membership is taken back"
ci = only(Base.specializations(only(methods(h)))).cache
@assert ci.min_world > w_held "the folded negative's code begins after the membership's worlds: $(Int(ci.min_world)) against $(Int(w_held))"
@assert Base.invoke_in_world(w_held, h, IS()) === true "in the world where the membership held"
println("n37_absence_worlds: ok")
