"A trait package: `Shape` with `area`; workers over one shape and over a vector of `Dynamic{Shape}`."
module GShapes
using TraitWorld
@trait_module module ShapeCore
using TraitWorld
export Shape, area, twice, areasum
@trait Shape{R} begin
    area(r::R)::Float64
end
struct Unit end
@implement Shape{Unit} begin
    area(r) = 1.0
end
twice(s::Shape) = 2.0 * area(s)
areasum(v::Vector{Dynamic{Shape}}) = (t = 0.0; for s in v; t += area(s); end; t)
end
using .ShapeCore
export Shape, area, twice, areasum
TraitWorld.@workload begin
    twice(ShapeCore.Unit()); areasum([Dynamic{Shape}(ShapeCore.Unit())])
end
end
