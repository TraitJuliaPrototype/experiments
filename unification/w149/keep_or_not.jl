# W-149: what storage typed by the trait holds, with `keep` and without it, when the storing method is
# called from the prompt's side (not knowing the type) and from code that knows it.
# Run from TraitWorld-unified: julia --startup-file=no --project=. ../experiments/unification/w149/keep_or_not.jl
using TraitWorld
module M
using TraitWorld
@trait_module
export Shape, Scalable, Circle, Scene, add_keep!, add_plain!, area
@trait Shape begin
    area(s::Shape)::Float64
end
@trait Scalable
struct Circle; r::Float64; end
area(c::Circle) = 3.14 * c.r^2
@implement Shape Circle
@implement Scalable Circle
struct Scene; shapes::Vector{Shape}; end
add_keep!(sc::Scene, s::Shape) = (push!(sc.shapes, keep(s)); sc)
add_plain!(sc::Scene, s::Shape) = (push!(sc.shapes, s); sc)
end
using .M
known(sc, f!) = (f!(sc, Circle(1.0)); sc)                # a caller compiled with the value's type
unknown(sc, f!, xs::Vector{Any}) = (f!(sc, xs[1]); sc)   # a caller that does not know it
for (name, f!) in (("keep", add_keep!), ("no keep", add_plain!))
    a = known(Scene(Shape[]), f!); b = unknown(Scene(Shape[]), f!, Any[Circle(1.0)])
    println(rpad(name, 8), " from typed code: ", typeof(a.shapes[1]), ", isa Scalable ", a.shapes[1] isa Scalable,
            " | from untyped code: ", typeof(b.shapes[1]), ", isa Scalable ", b.shapes[1] isa Scalable)
end
