include(joinpath(@__DIR__, "..", "lib_trait.jl")); using .Geometry, TraitWorld
module Layout          # a second library, with two methods of one function that tie for two shapes
using TraitWorld, ..Geometry
@trait_module
export overlap
overlap(a::Shape, b) = "a shape and something"
overlap(a, b::Shape) = "something and a shape"
end
using .Layout
println("PHASE definition")
struct Circle
    r::Float64
end
@implement Shape Circle begin
    area(c) = pi * c.r^2
    perimeter(c) = 2pi * c.r
end
println("PHASE call")
println(overlap(Circle(1.0), Circle(2.0)))
println("PHASE end")
