"A package that declares an implementation of GShapes' trait, and nothing else (plan step 4)."
module AheadP
using TraitWorld, GShapes
struct Hexagon; s::Float64; end
@implement Shape{Hexagon} begin
    area(h) = 2.598076211353316 * h.s^2
end
end
