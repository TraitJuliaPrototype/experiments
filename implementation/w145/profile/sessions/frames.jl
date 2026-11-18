#@ load
using CSV, DataFrames, Statistics, Dates
#@ read
D = ENV["DATA"]; _show(x) = show(IOContext(stdout, :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), x)
df = CSV.read(joinpath(D, "people.csv"), DataFrame);
#@ show
_show(df)
#@ describe
_show(describe(df))
#@ select and filter
_show(subset(select(df, :id, :city, :income), :income => ByRow(x -> !ismissing(x) && x > 5e4)))
#@ sort
_show(sort(df, [:city, :income], rev = [false, true]))
#@ groupby and combine
_show(combine(groupby(df, :city), :income => mean ∘ skipmissing => :mean_income, nrow))
#@ a user's function by row
_show(transform(df, [:age, :income] => ByRow((a, i) -> coalesce(i, 0.0) / max(coalesce(a, 1), 1)) => :ratio))
#@ join
_show(innerjoin(df, CSV.read(joinpath(D, "orders.csv"), DataFrame), on = :id))
#@ describe again
_show(describe(df))
