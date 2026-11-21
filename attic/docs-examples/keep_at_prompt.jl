using TraitWorld
module G
using TraitWorld
@trait_module
export Shape, area, Scalable, scale, Scene, add!, add_keep!, nscalable
@trait Shape begin
    area(s::Shape)::Float64
end
@trait Scalable begin
    scale(s::Scalable, k::Float64)::Self
end
struct Scene; shapes::Vector{Shape}; end
Scene() = Scene(Shape[])
add!(sc::Scene, s::Shape) = (push!(sc.shapes, s); sc)              # the rule: no `keep` into storage typed by the trait
add_keep!(sc::Scene, s::Shape) = (push!(sc.shapes, keep(s)); sc)    # against it: what is stored depends on the caller
nscalable(sc::Scene) = count(s -> s isa Scalable, sc.shapes)
end
using .G
struct Circle; r::Float64; end
G.area(c::Circle) = π * c.r^2
@implement Shape Circle
@implement Scalable Circle begin
    scale(c, k) = Circle(k * c.r)
end
a = Scene(); add!(a, Circle(1.0))                 # at the prompt
fill_scene() = (b = Scene(); add!(b, Circle(1.0)); b)
b = fill_scene()                                  # from a function that knows the type
println("prompt:   ", typeof(a.shapes[1]), "  isa Scalable: ", a.shapes[1] isa Scalable, "  nscalable: ", nscalable(a), "  == Circle(1.0): ", a.shapes[1] == Circle(1.0))
println("function: ", typeof(b.shapes[1]), "  isa Scalable: ", b.shapes[1] isa Scalable, "  nscalable: ", nscalable(b), "  == Circle(1.0): ", b.shapes[1] == Circle(1.0))
ak = Scene(); add_keep!(ak, Circle(1.0))
fill_keep() = (b = Scene(); add_keep!(b, Circle(1.0)); b)
bk = fill_keep()
println("with keep, prompt:   ", typeof(ak.shapes[1]), "  isa Scalable: ", ak.shapes[1] isa Scalable, "  nscalable: ", nscalable(ak))
println("with keep, function: ", typeof(bk.shapes[1]), "  isa Scalable: ", bk.shapes[1] isa Scalable, "  nscalable: ", nscalable(bk))
