include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
println("PHASE definition")
struct Circle <: Shape
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
println("PHASE call")
println(report(Circle(1.0)))
println("PHASE end")
