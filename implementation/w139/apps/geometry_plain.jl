# E-364: the library and two members, in plain Julia.
module Geometry
export Shape, area, perimeter, label, ratio, report
abstract type Shape end
function area end
function perimeter end
label(s::Shape) = "shape"
ratio(s::Shape) = area(s) / perimeter(s)
report(s::Shape) = string(label(s), ": area ", round(area(s); digits = 3), ", ratio ", round(ratio(s); digits = 3))
end
using .Geometry
struct Circle <: Shape
    r::Float64
end
Geometry.area(c::Circle) = pi * c.r^2
Geometry.perimeter(c::Circle) = 2pi * c.r
Geometry.label(c::Circle) = "circle"
struct Rect <: Shape
    w::Float64
    h::Float64
end
Geometry.area(r::Rect) = r.w * r.h
Geometry.perimeter(r::Rect) = 2 * (r.w + r.h)
