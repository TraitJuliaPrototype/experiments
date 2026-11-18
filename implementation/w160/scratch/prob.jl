using TraitWorld
using TraitWorld.ByType: compiled_for
module BT
using TraitWorld
@trait_module first_seen = false
@trait Shape begin
    @default_dynamic
    area(s::Shape)::Float64
end
struct Circle; r::Float64; end
area(c::Circle) = 3.0 * c.r^2
@implement Shape Circle
struct Prob{S <: Shape}; s::S; end
end
for m in methods(BT.Prob); println(m, " fwd=", TraitWorld._is_forwarder(m)); end
c = BT.Circle(1.0)
@show typeof(BT.Prob(c)) typeof(BT.Prob(compiled_for(c)))
