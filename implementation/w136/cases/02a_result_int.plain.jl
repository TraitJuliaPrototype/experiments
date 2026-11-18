include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
println("PHASE definition")
struct Square <: Shape
    side::Int
end
Geometry.area(s::Square) = s.side^2
Geometry.perimeter(s::Square) = 4.0 * s.side
println("PHASE call")
println(report(Square(2)))
println("PHASE end")
