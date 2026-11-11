include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
module Layout          # a second library, with two methods of one function that tie for two shapes
using ..Geometry
export overlap
overlap(a::Shape, b) = "a shape and something"
overlap(a, b::Shape) = "something and a shape"
end
using .Layout
println("PHASE definition")
struct Circle <: Shape
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
Geometry.perimeter(c::Circle) = 2pi * c.r
println("PHASE call")
println(overlap(Circle(1.0), Circle(2.0)))
println("PHASE end")
