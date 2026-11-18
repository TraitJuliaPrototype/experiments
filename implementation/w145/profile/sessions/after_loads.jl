#@ load
using CSV, DataFrames
#@ _the work
csv = ENV["CSVFILE"]
w() = (df = CSV.read(csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c); g = combine(groupby(df, names(df)[end]), c => sum); nothing)
#@ the work, first
w()
#@ nine unrelated loads
using OffsetArrays, StatsBase, Unitful, IntervalArithmetic, Distributions, Interpolations, StaticArrays, CairoMakie, REPL
#@ the work after the loads
w()
#@ the work again
w()
