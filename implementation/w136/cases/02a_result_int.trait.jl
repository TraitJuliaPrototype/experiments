include(joinpath(@__DIR__, "..", "lib_trait.jl")); using .Geometry, TraitWorld
println("PHASE definition")
struct Square
    side::Int
end
Geometry.area(s::Square) = s.side^2
Geometry.perimeter(s::Square) = 4.0 * s.side
@implement Shape Square
println("PHASE call")
println(report(Square(2)))
println("PHASE end")
