# E-144: `Dynamic{X}` with exactly 2, 4, 5, 8 and 64 implementations, in idiomatic trait code.
# For each n: a sum of areas over 1000 shapes cycling through the n types, as
#   - Vector{Dynamic{Sn}} (a copy),
#   - a lazy view of the user's Vector{AShape} and of a Vector{Any} holding the same objects,
#   - plain Julia over the Vector{AShape} (one function with n methods),
#   - interop: a trait module calling that plain function on the Vector{AShape} (hc2's `Vector{Sh}`),
# and the cost of the copy. Then, for n = 64, vectors of one type only: which types the split
# covers (the first four declared, E-130), and what the others cost.
#
#     ./run.sh product --project=. hi2_shapes.jl      (and ./run.sh all …)
include("common.jl")
using TraitWorld
header("hi2_shapes")
include("shapes_defs.jl")
const N = 1000
const TYPES = [getfield(Main, Symbol(:P, i)) for i in 1:64]
const NS = (2, 4, 5, 8, 64)
cycle(n) = AShape[TYPES[mod1(i, n)](1.0) for i in 1:N]
F(n) = getfield(ShapeCore, Symbol(:S, n))
cands = Base.Compiler.dynamic_candidates(TraitWorld._family(ShapeCore.S64))
println("candidates the split of S64 covers: ", join(string.(cands), ", "))
for n in NS
    S = F(n)
    tot = getfield(ShapeCore, Symbol(:total, n)); itot = getfield(ShapeCore, Symbol(:itotal, n)); ptot = getfield(Main, Symbol(:ptotal, n))
    v = cycle(n); va = Vector{Any}(v)
    c = collect(DynamicItems{S}(v))
    dv = DynamicItems{S}(v); dva = DynamicItems{S}(va)
    @assert tot(c) == tot(dv) == tot(dva) == ptot(v) == itot(v)
    println("-- n = $n implementations")
    @row "Σ parea$n(x) over Vector{AShape}" "plain" N $ptot($v)
    @row "the same in a trait module" "interop" N $itot($v)
    @row "Σ area$n(x) over Vector{Dynamic{S$n}}" "copy" N $tot($c)
    @row "Σ area$n(x) over DynamicItems{S$n}(Vector{AShape})" "view" N $tot($dv)
    @row "Σ area$n(x) over DynamicItems{S$n}(Vector{Any})" "view" N $tot($dva)
    @row "collect(DynamicItems{S$n}(v)): the copy" "make" N collect(DynamicItems{$S}($v))
end
println("-- n = 64, one type only")
let S = ShapeCore.S64
    for i in (1, 4, 5, 64)
        v = AShape[TYPES[i](1.0) for _ in 1:N]
        c = collect(DynamicItems{S}(v)); dv = DynamicItems{S}(v)
        @row "only P$i: Vector{Dynamic{S64}}" "copy" N total64($c)
        @row "only P$i: DynamicItems{S64}(Vector{AShape})" "view" N total64($dv)
        @row "only P$i: plain, 64 methods" "plain" N ptotal64($v)
    end
end
println("== done  load ", join(loadavg(), " "))
