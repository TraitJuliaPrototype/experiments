println("PHASE library")
module Geometry
using TraitWorld
@trait_module
export Shape, area, perimeter, density
@trait Shape begin
    area(s::Shape)::Float64
    perimeter(s::Shape)::Float64
end
density(s::Shape) = s.mass / area(s)
end
using .Geometry, TraitWorld
println("PHASE definition")
struct Circle
    r::Float64
end
@implement Shape Circle begin
    area(c) = pi * c.r^2
    perimeter(c) = 2pi * c.r
end
println("PHASE call")
println(density(Circle(1.0)))
println("PHASE end")
