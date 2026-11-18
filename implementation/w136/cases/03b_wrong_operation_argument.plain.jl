include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
println("PHASE definition")
struct Circle <: Shape
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
Geometry.perimeter(c::Circle) = 2pi * c.r
Geometry.scale(c::Circle, k::Float64) = Circle(k * c.r)
println("PHASE call")
println(scale(Circle(1.0), 2))
println("PHASE end")
