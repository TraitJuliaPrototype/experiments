# E-175: a flat profile of a whole workload session (the script and output dir as for record_cis.jl)
using Profile
Profile.init(n = 10^7, delay = 0.001)
const _S, _O = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _O)
@profile include(joinpath(@__DIR__, _S))
Profile.print(format = :flat, sortedby = :count, mincount = 25, noisefloor = 0, C = false)
