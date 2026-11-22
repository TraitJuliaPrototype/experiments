# W-169: E-511's work (w134/lost.jl, order A): upstream CSV and DataFrames (plainly, by facts) or the forks, the
# work, the nine unrelated loads, the work again. W169_CSV: the table; W169_LOADS: the loads.
const csv = ENV["W169_CSV"]
const LOADS = split(ENV["W169_LOADS"])
#@ load
using CSV, DataFrames
#@ _definitions
w = () -> (df = CSV.read(csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
           g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
#@ first work
Base.invokelatest(w)
#@ again
Base.invokelatest(w)
#@ nine loads
for p in LOADS; Core.eval(Main, Meta.parse("using $p")); end
#@ after the loads
Base.invokelatest(w)
#@ again after
Base.invokelatest(w)
