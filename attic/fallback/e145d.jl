# E-145, the as-built check (after julia-1.13 `split-table`): TraitWorld's own `Dynamic` with 64
# implementations, in a fresh session. The first use of each type beyond the split's four (its
# pointer made), the steady state per element, the allocation, and making `Dynamic` values from a
# `Vector{Any}` (the conformance check's split).
#     ./run.sh product --project=. e145d.jl
include("common.jl")
using TraitWorld, Random, Printf
header("e145d")
const N = 1000
let io = IOBuffer()
    for i in 1:64
        println(io, "struct T$i; a::Float64; end")
    end
    include_string(Main, String(take!(io)), joinpath(@__DIR__, "e145d_types.jl"))
end
const TYPES = Any[getfield(Main, Symbol(:T, i)) for i in 1:64]
@trait_module module FD
using TraitWorld
export S, sarea, tot
@trait S begin
    sarea(s::S)::Float64
end
tot(v::Vector{Dynamic{S}}) = (s = 0.0; for d in v; s += sarea(d); end; s)
end
let io = IOBuffer()
    for i in 1:64
        println(io, "TraitWorld.@implement FD.S T$i begin sarea(s) = $(Float64(i)) * s.a end")
    end
    include_string(Main, String(take!(io)), joinpath(@__DIR__, "e145d_impls.jl"))
end
println("split covers: ", join(string.(Base.Compiler.dynamic_candidates(TraitWorld._family(FD.S))), ", "))
# the loop compiled once, with the four candidates
FD.tot(Dynamic{FD.S}[Dynamic{FD.S}(T1(1.0))])
# the first use of each of eight types beyond the split: one call each
for i in 5:12
    v = Dynamic{FD.S}[Dynamic{FD.S}(TYPES[i](1.0))]
    t = @elapsed FD.tot(v)
    t2 = @elapsed FD.tot(v)
    @printf("%-8s %-12s T%-2d first call %7.2f ms, second %7.4f ms\n", SETTING, "first", i, 1000t, 1000t2)
end
rng = Xoshiro(145)
for n in (5, 8, 16, 64)
    va = Any[TYPES[rand(rng, 1:n)](1.0) for _ in 1:N]
    vt = Dynamic{FD.S}[Dynamic{FD.S}(x) for x in va]
    FD.tot(vt)
    @row "tw: Σ sarea over Vector{Dynamic{S}}, uniform n=$n" "as built" N FD.tot($vt)
end
va = Any[TYPES[rand(rng, 1:64)](1.0) for _ in 1:N]
@row "collect(DynamicItems{S}(v)) from a Vector{Any}, 64 types" "make" N collect(DynamicItems{FD.S}($va))
println("== done  load ", join(loadavg(), " "))
