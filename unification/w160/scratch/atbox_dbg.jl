using TraitWorld
module Bounded
using TraitWorld
@trait_module bounded = false
@trait Pt begin
    px(p::Pt)::Float64
end
struct P2; x::Float64; end
px(p::P2) = p.x
@implement Pt P2
bad(p::Pt) = p.x
end
m = only(methods(Bounded.bad))
sig = TraitWorld.box_signature(m)
@show sig
w = Base.get_world_counter()
src = TraitWorld._box_instance(sig, w)
println("cached: ", src === nothing ? "nothing" : "")
src === nothing || display(src)
mi = Base.method_instance(sig; world = w)
@show mi mi.specTypes
isdefined(mi, :cache) && (ci = mi.cache; @show ci.rettype ci.owner typeof(ci.inferred))
println(TraitWorld.check_at_box(m))
r = Base.code_typed_by_type(sig; interp = TraitWorld.CC.NativeInterpreter(w; facts = true), optimize = true)
display(r)
