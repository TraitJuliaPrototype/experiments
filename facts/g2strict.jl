# g2all with strict mode (JULIA_TW_STRICT=1): what the mode refuses across the loads, and what its
# check costs at load time. Usage: julia g2strict.jl interleaved|before
include(joinpath(@__DIR__, "g2all.jl"))
println("strict mode: ", TW.STRICT[], "; misses of the check before definitions: ", length(TW._STRICT_MISSES))
