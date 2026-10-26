# TraitWorld's own judgement of the same method: owned (no pirate)?
t0 = time()
using TraitWorld
println("TraitWorld loaded in ", round(time() - t0; digits = 1), " s")
module Lib
g(x::Integer) = 1
end
module P
struct MyT end
Main.Lib.g(x::Int, y::MyT...) = 2
end
m = only(filter(m -> m.module === P, collect(methods(Lib.g))))
println("owned_method(g(::Int, ::MyT...)) = ", TraitWorld.owned_method(m))
println("sig_owners(Tuple{typeof(g), Int}) = ", collect(TraitWorld.sig_owners(Tuple{typeof(Lib.g), Int})))
println("_stakeholder(P, Tuple{typeof(g), Int}) = ", TraitWorld._stakeholder(TraitWorld.owner(P), Tuple{typeof(Lib.g), Int}))
# a definition laundered through Core.eval(Base, ...) is attributed to Julia
Core.eval(Base, :(Main.Lib.g(x::Int, y::Float64) = 3))
m2 = only(filter(m -> m.module === Base, collect(methods(Lib.g))))
println("owner of a method defined by Core.eval(Base, …): ", TraitWorld.owner(m2.module))
