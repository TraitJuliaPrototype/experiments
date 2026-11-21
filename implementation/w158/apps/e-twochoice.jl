# W-158, third part (E-510): a call at two values known only by their trait where the member's types choose the
# method (compiler §7.6, "With several such arguments the call branches over each": C-151).
# `julia --project=<TraitWorld> apps/e-twochoice.jl` runs `main` in a session.
using TraitWorld
@trait ShapeE begin
    areaE(s::ShapeE)::Float64
end
struct SqE; a::Float64; end
struct CiE; r::Float64; end
struct ReE{T}; t::T; end
areaE(s::SqE) = s.a^2
areaE(c::CiE) = 3.0 * c.r^2
areaE(r::ReE) = 1.0
@implement ShapeE SqE
@implement ShapeE CiE
@implement ShapeE ReE{T} where {T}
pairup(@nospecialize(x), @nospecialize(y)) = 0
pairup(x::SqE, y::CiE) = 1
pairup(x::CiE, y::SqE) = 2
pairup(x::CiE, y::CiE) = 3
pairup(x::ReE, y::SqE) = 4
@noinline twochoice(v::Vector{ShapeE}) = (s = 0; for a in v, b in v; s += pairup(a, b); end; s)
function (@main)(args::Vector{String})::Cint
    n = length(args) + 2
    println(Core.stdout, "pairs ", twochoice(ShapeE[SqE(Float64(n)), CiE(1.0), ReE(n)]))
    return 0
end
