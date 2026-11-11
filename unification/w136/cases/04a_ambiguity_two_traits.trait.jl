include(joinpath(@__DIR__, "..", "lib_trait.jl")); using .Geometry, TraitWorld
println("PHASE definition")
struct Sprite
    name::String
    r::Float64
end
@implement Shape Sprite begin
    area(c) = pi * c.r^2
    perimeter(c) = 2pi * c.r
end
println("PHASE second membership")
@implement Named Sprite
println("PHASE call")
println(tag(Sprite("ball", 1.0)))
println("PHASE end")
