# W-143e (E-541): the session's own facts instances, one per line (bit, specTypes), sorted: to tell two builds' sets apart.
include(joinpath(@__DIR__, "..", "census_lib.jl"))
S = census_session(ARGS[1])
for l in sort([string(bit(ci) ? "bit " : "out ", ci.def.specTypes) for ci in S.factsown]); println(l); end
