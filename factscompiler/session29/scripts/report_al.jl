using Profile
include("/tmp/claude-1000/demos/tally.jl")
const csv = "/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv"
for p in split(get(ENV, "PK", "OffsetArrays StatsBase Unitful")); Core.eval(Main, Meta.parse("using $p")); end
@eval using TraitReport
t0 = tally()
Profile.init(n = 10^7, delay = 0.001)
@time @profile TraitReport.report(csv, joinpath(mktempdir(), "r.png"); io = IOBuffer())
t1 = tally(); println("  new CIs: ", sort(collect(diff(t0, t1)); by = string))
Profile.print(IOContext(stdout, :displaysize => (5000, 300)); format = :flat, sortedby = :count, C = true, mincount = 60)
