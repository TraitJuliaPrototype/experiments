include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
# Plain Julia has one supertype per type: the second interface is a convention (a field `name`),
# and `tag`'s method for it is the untyped one. No ambiguity arises; the method at Shape wins silently.
println("PHASE definition")
struct Sprite <: Shape
    name::String
    r::Float64
end
Geometry.area(c::Sprite) = pi * c.r^2
Geometry.perimeter(c::Sprite) = 2pi * c.r
println("PHASE call")
println(tag(Sprite("ball", 1.0)))
println("PHASE end")
