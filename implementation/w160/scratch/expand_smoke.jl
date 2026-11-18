using TraitWorld, Test
using TraitWorld.ByType: compiled_for
module M
using TraitWorld
@trait_module first_seen = false
@trait Model begin
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
@trait Shape begin
    area(s::Shape)::Float64
end
step(m::Model, u::Float64) = u + 1e-9 * rate(m, u)
kind(m::Model) = m isa Dynamic ? :box : m isa Compiled ? :wrapper : :plain
opt(m::Model, k::Int = 2; scale = 1.0) = (kind(m), k, scale)
plainshape(s::Shape) = s isa Dynamic ? :box : :plain
end
module U
using TraitWorld
import ..M: Model, rate, Shape, area
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
area(d::Decay) = 1.0
@implement Shape Decay
end
d = U.Decay(0.5)
for m in methods(M.step); println(m, "  forwarder=", TraitWorld._is_forwarder(m)); end
@show M.kind(d) M.kind(compiled_for(d)) M.kind(Dynamic{M.Model}(d))
@show M.opt(d) M.opt(d, 3) M.opt(d; scale = 2.0) M.opt(compiled_for(d), 4; scale = 3.0)
@show M.plainshape(d)
@show length(methods(M.opt))
@test M.step(d, 1.0) == 1.0 + 1e-9 * (-0.5)
