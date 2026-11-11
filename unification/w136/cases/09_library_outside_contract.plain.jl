println("PHASE library")
module Geometry
export Shape, area, perimeter, density
"A subtype implements `area(s)::Float64` and `perimeter(s)::Float64`."
abstract type Shape end
function area end
function perimeter end
density(s::Shape) = s.mass / area(s)
end
using .Geometry
println("PHASE definition")
struct Circle <: Shape
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
Geometry.perimeter(c::Circle) = 2pi * c.r
println("PHASE call")
println(density(Circle(1.0)))
println("PHASE end")
