include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
println("PHASE definition")
struct Circle <: Shape
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
Geometry.perimeter(c::Circle) = 2pi * c.r
println(report(Circle(1.0)))
println("PHASE later method")
Geometry.area(c::Circle) = c.r > 10 ? "big" : pi * c.r^2
println("PHASE call")
println(report(Circle(11.0)))
println("PHASE end")
