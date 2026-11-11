include(joinpath(@__DIR__, "..", "lib_trait.jl")); using .Geometry, TraitWorld
println("PHASE definition")
struct Circle
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
Geometry.perimeter(c::Circle) = 2pi * c.r
println("PHASE call")
println(report(Circle(1.0)))
println("PHASE end")
