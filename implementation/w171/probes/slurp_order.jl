# W-171, third part (E-544): the method table's lists are sorted by specificity when a method is inserted. A
# membership declared later can make a method listed after another a subtype of it (`g(::Y0)` after `g(::X)`, once
# `Y0` joins `X`); the lookup's shortcut that skips the methods a match dominates (`typemap_slurp_search`) then
# drops `g(::Y0)` from a lookup at `X`, and code compiled at `X` calls `g(::X)` for a member of `Y0`.
#     julia --project=experiments/implementation slurp_order.jl
using Traits
@trait X
@trait Y0
struct S0 end
@implement Y0 S0
g(::Any) = :Any
g(::X) = :X
g(::Y0) = :Y0
@implement X Y0
Base.@nospecializeinfer q(@nospecialize(x::X)) = g(x)
println("lookup at X: ", [m.method.sig for m in Base._methods_by_ftype(Tuple{typeof(g), X}, -1, Base.get_world_counter())])
println("q(S0()) = ", q(S0()), " (dispatch: ", g(Base.inferencebarrier(S0())), ")")
