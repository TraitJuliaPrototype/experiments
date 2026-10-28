# An A/B probe (W-85's worked example): the forks' import with TraitWorld's load report on, for a change to
# TraitWorld (the override index's functions not specialized on each member's builder type).
#     experiments/tools/ab/ab.sh TraitWorld <ref> <an env of the forks> experiments/tools/ab/examples/forks_load_index.jl
include(joinpath(ENV["AB_TOOLS"], "ABProbe.jl")); using .ABProbe
ENV["JULIA_TW_LOADREPORT"] = "1"                 # read in TraitWorld's __init__
t = @elapsed using CSV, DataFrames, Statistics, Dates
abreport("using_CSV_DataFrames"; ms = t * 1e3)
using TraitWorld
for part in (:total, :check, :builder, :index)
    v = get(TraitWorld._LR_PARTS, (:member_at_load, part), UInt64[0, 0, 0])
    abreport("members_at_load_$part"; n = Int(v[1]), ms = v[2] / 1e6, compile_ms = v[3] / 1e6)
end
