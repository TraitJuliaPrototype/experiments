# TraitMakie: a forwarding @implement after big loads; CodeInstances created by owner and module; a profile.
using Profile
include("/tmp/claude-1000/demos/tally.jl")
LOADS = get(ENV, "LOADS", "1") == "1"
LOADS && @eval Main using CSV, DataFrames, CairoMakie
@eval using TraitMakie, TraitWorld
const TM = TraitMakie
xs = collect(range(0.0, 2pi; length = 100))
f = TM.lines(xs, sin.(xs); title = "t"); TM.save(joinpath(mktempdir(), "a.png"), f)
@eval struct Trajectory; name::String; pts::Vector{NTuple{2,Float64}}; end
t0 = tally()
Profile.init(n = 10^7, delay = 0.001)
@time @profile @eval @implement TM.Positions Trajectory by pts
t1 = tally(); println("  new CIs: ", sort(collect(diff(t0, t1)); by = string))

Profile.print(IOContext(stdout, :displaysize => (5000, 400)); format = :tree, C = false, mincount = 1500, noisefloor = 0)
