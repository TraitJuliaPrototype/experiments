# A glue extension: GGeom's types conform to GShapes' trait, declared by GShapes (the trait's
# owner; an extension counts as its parent). The pair (GGeom's types, GShapes' workers) belongs to
# no package that depends on both; the workload puts its workers in the extension's image.
module GShapesGGeomExt
using TraitWorld
using GShapes: GShapes, Shape, area
using GGeom: Circle, Square
@implement Shape{Circle} begin
    area(c) = pi * c.r^2
end
@implement Shape{Square} begin
    area(s) = s.a^2
end
TraitWorld.@workload begin
    GShapes.twice(Circle(1.0)); GShapes.twice(Square(2.0))
    GShapes.areasum([Dynamic{Shape}(Circle(1.0)), Dynamic{Shape}(Square(2.0))])
end
end
