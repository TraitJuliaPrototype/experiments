# An A/B probe (W-85's worked example on the forks): the import of the forks' CSV and DataFrames, and E-214's
# groupby-sum on an integer key (10^6 rows), whose time a boxed counter in `_group_rows!` multiplied (fixed in
# forks ff89a63).
#     AFTER=ff89a63 experiments/tools/ab/ab.sh forks 009565d forks/env_forks experiments/tools/ab/examples/forks_groupby.jl
include(joinpath(ENV["AB_TOOLS"], "ABProbe.jl")); using .ABProbe
t = @elapsed using CSV, DataFrames, Random
abreport("using_CSV_DataFrames"; ms = t * 1e3)
Random.seed!(1)
df = DataFrame(i = rand(1:1000, 10^6), f = randn(10^6))
abmeasure("groupby_sum_int_key", () -> combine(groupby(df, :i), :f => sum))
