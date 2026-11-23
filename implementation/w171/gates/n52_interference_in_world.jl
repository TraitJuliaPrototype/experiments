# Gate (compiler §5.2; E-544): a method's list of interferences is made at its insertion; a membership declared later
# orders a pair of methods at sets (`g(::Y0)` is more specific than `g(::X)` once `Y0` joins `X`). The lookup asks each
# listed pair again in the query's world, so a lookup at `X` keeps `g(::Y0)`, and code compiled at `X` after the
# membership calls it for a member of `Y0`. A candidate for `gates/`; fails on `next` 3e9c193025.
#     julia --project=experiments/implementation n52_interference_in_world.jl
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
ms = [m.method.sig for m in Base._methods_by_ftype(Tuple{typeof(g), X}, -1, Base.get_world_counter())]
@assert Tuple{typeof(g), Y0} in ms "the lookup at X keeps g(::Y0): $ms"
@assert q(S0()) === :Y0 "code compiled at X: $(q(S0()))"
@assert which(g, Tuple{S0}).sig == Tuple{typeof(g), Y0}
println("n52_interference_in_world: OK")
