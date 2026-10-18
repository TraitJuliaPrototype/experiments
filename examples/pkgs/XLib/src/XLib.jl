"A trait package: workers over `Vals`, compiled for `Vector{Float64}` in its image, calling XFun at `Float64`."
module XLib
using TraitWorld
@trait_module module XCore
using TraitWorld
import XFun
export Vals, vals, total, wtotal
@trait Vals{R} begin
    vals(r::R)::Vector{Float64}
end
@implement Vals{Vector{Float64}} begin
    vals(r) = r
end
total(v::Vals) = (s = 0.0; for x in vals(v); s += XFun.score(x); end; s)
wtotal(v::Vals) = (s = 0.0; for x in vals(v); s += XFun.weight(x) * x; end; s)
end
using .XCore
export Vals, vals, total, wtotal
TraitWorld.@workload begin
    total([1.0, 2.0]); wtotal([1.0, 2.0])
end
end
