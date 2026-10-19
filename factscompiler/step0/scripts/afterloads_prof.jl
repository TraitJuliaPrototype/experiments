# Profile of the control's work after the loads (all frames, C included), flat by count.
const csv = ARGS[1]; pk = ARGS[2:end]
using CSV, DataFrames, Profile
w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
Base.invokelatest(w); Base.invokelatest(w)
for p in pk; Core.eval(Main, Meta.parse("using $p")); end
Profile.init(n = 10^7, delay = 0.0005)
t = @elapsed @profile Base.invokelatest(w)
println("work after the loads: ", round(1000t; digits = 1), " ms")
Profile.print(IOContext(stdout, :displaysize => (2000, 250)); format = :flat, sortedby = :count, C = true, mincount = 60)
