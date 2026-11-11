include(joinpath(@__DIR__, "..", "lib_trait.jl")); using .Geometry, TraitWorld
println("PHASE definition")
struct Circle
    r::Float64
end
@implement Shape Circle begin
    area(c) = pi * c.r^2
    perimeter(c) = 2pi * c.r
end
println("PHASE call")
println(report(1.0))
println("PHASE end")
