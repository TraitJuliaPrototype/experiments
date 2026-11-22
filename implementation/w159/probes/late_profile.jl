# W-159 probe (E-515): where the library's late load goes (168 ms on the head after plain work, 41 ms at the tag,
# 58 ms loaded first). Upstream CSV and DataFrames' work (w134/plain.jl's), then `using TraitWorld` profiled.
#     julia --project=<env_lib> late_profile.jl <csv>
using Profile, CSV, DataFrames, Statistics
csv = ARGS[1]
w = () -> (df = CSV.read(csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
w()
Profile.init(n = 10^7, delay = 0.0005)
t = @elapsed @eval @profile using TraitWorld
println("using TraitWorld (late, profiled) ", round(1000t; digits = 1), " ms")
Profile.print(IOContext(stdout, :displaysize => (1000, 200)); format = :flat, sortedby = :count, mincount = 8, C = true)
