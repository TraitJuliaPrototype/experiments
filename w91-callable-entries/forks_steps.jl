# The forks' session (forks/scripts/session.jl) as a script, then the census.
using CSV, DataFrames, Statistics, Dates
include(joinpath(@__DIR__, "census.jl")); census_snap()
D = get(ENV, "DATA", "data"); tmp = tempname()
df = CSV.read(joinpath(D, "people.csv"), DataFrame); show(IOBuffer(), MIME"text/plain"(), df)
show(IOBuffer(), MIME"text/plain"(), describe(df))
sub = subset(select(df, :id, :city, :income), :income => ByRow(x -> !ismissing(x) && x > 5e4))
sort(df, [:city, :income], rev = [false, true])
combine(groupby(df, :city), :income => mean ∘ skipmissing => :mean_income, nrow)
transform(df, [:age, :income] => ByRow((a, i) -> coalesce(i, 0.0) / max(coalesce(a, 1), 1)) => :ratio)
innerjoin(df, CSV.read(joinpath(D, "orders.csv"), DataFrame), on = :id)
df.income_k = df.income ./ 1000
CSV.write(tmp, df)
s2 = CSV.read(joinpath(D, "sensors.csv"), DataFrame); describe(s2); sort(s2, [:tag, :s1])
combine(groupby(s2, :tag), :s1 => mean ∘ skipmissing => :m1, :s2 => maximum ∘ skipmissing => :x2, nrow)
using InlineStrings
df3 = CSV.read(joinpath(D, "people.csv"), DataFrame; stringtype = String15); describe(df3)
combine(groupby(df3, :city), :income => mean ∘ skipmissing => :mean_income, nrow)
census()
