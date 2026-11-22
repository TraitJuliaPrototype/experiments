# W-171 (E-542): `hasmethod` at an abstract member's type, compiled where the method does not apply; a path of two
# memberships (AM in Yc, then Yc in X) makes it apply
#     julia --project=experiments/implementation hasm_abstract_path.jl
using Traits
@trait X
@trait Yc
abstract type AM end
h(::X) = :h
q() = hasmethod(h, Tuple{AM})
println("before: ", q())
Traits.declare_membership(AM, Yc, @__MODULE__)
println("AM in Yc: ", q())
Traits.declare_membership(Yc, X, @__MODULE__)
println("Yc in X: compiled ", Base.invokelatest(q), "  fresh ", hasmethod(Base.inferencebarrier(h), Base.inferencebarrier(Tuple{AM})),
        "  AM <: X ", ccall(:jl_subtype, Cint, (Any, Any), AM, X) != 0)
mi = only(Base.specializations(only(methods(q)))); c = mi.cache; println("  worlds ", Int(c.min_world), ":", c.max_world, " edges ", c.edges)
mi2 = only(filter(m -> m.specTypes == Tuple{typeof(hasmethod), typeof(h), Type{Tuple{AM}}}, collect(Base.specializations(only(methods(hasmethod, (Any, Any)))))))
c2 = mi2.cache; println("  hasmethod's instance: worlds ", Int(c2.min_world), ":", c2.max_world, " edges ", c2.edges)
