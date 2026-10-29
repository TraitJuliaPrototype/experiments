# E-245: can TraitWorld express IndexProvider{I} with an abstract or union I, an operation with a default
# returning Union{Nothing, Kept{Callable}}, and a bounded getter that takes any index of type I?
using TraitWorld
@trait_module module P118
using TraitWorld
export IP, vindex, obs, getter, Sys1, Names, Ix, Ix1, Ix2
abstract type Ix end
struct Ix1 <: Ix; i::Int; end
struct Ix2 <: Ix; s::Symbol; end
@trait IP{I} begin
    @default_with_dynamic_self
    vindex(ip::IP{I}, idx::I)::Union{Nothing,Int}
    obs(ip::IP{I}, idx::I)::Union{Nothing,Kept{Callable}} = nothing
end
struct Sys1; n::Int; end
const SysIx = Union{Ix, AbstractVector{<:Ix}}
@implement IP{SysIx} Sys1 begin
    vindex(s, idx) = idx isa Ix1 ? idx.i : nothing
    obs(s, idx) = idx isa Ix2 ? Kept{Callable}((u, p, t) -> sum(u) * p + t) : nothing
end
struct Names; v::Vector{Symbol}; end
@implement IP{Symbol} Names begin
    vindex(s, idx) = findfirst(==(idx), s.v)
end
struct SG; i::Int; end
(g::SG)(u, p, t) = u[g.i]
function getter(ip::IP{I}, idx) where {I}
    idx isa I || throw(ArgumentError("index type"))
    i = vindex(ip, idx)
    i === nothing || return Kept{Callable}(SG(i))
    g = obs(ip, idx)
    g === nothing && throw(ArgumentError("no such"))
    return g
end
end
using .P118
s = Sys1(3)
g1 = getter(s, Ix1(2)); println("g1 ", typeof(g1), " ", g1([1.0, 2.0, 3.0], 2.0, 0.5))
g2 = getter(s, Ix2(:a)); println("g2 ", typeof(g2), " ", g2([1.0, 2.0, 3.0], 2.0, 0.5))
g3 = getter(Names([:x, :y]), :y); println("g3 ", g3([1.0, 2.0], 0, 0))
println("dyn ", getter(Dynamic{IP{P118.SysIx}}(s), Ix1(1))([5.0], 0, 0))
try getter(s, :y) catch e; println("refused: ", sprint(showerror, e)[1:min(end,200)]) end
println("conforms ", conforms(Sys1, IP{P118.SysIx}), " ", conforms(Names, IP{Symbol}), " ", conforms(Sys1, IP{Symbol}))
f(x) = x isa Kept ? "kept" : "plain"
println(f(g1))
