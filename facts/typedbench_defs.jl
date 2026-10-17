using TraitWorld
@trait_module module Columns
using TraitWorld
export ColTable, ncols, col, colmean, total
@trait ColTable begin
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end
@implement ColTable Vector{Vector{Float64}} begin
    ncols(t) = length(t)
    col(t, i) = t[i]
end
colmean(t::ColTable, i::Int) = (c = col(t, i); sum(c) / length(c))
total(t::ColTable, len::Int) = (s = 0.0; for i in 1:ncols(t), j in 1:len; s += col(t, i)[j]; end; s)
end
using .Columns
struct Meas; label::String; data::Vector{Vector{Float64}}; end
@implement ColTable Meas
mutable struct MeasM; label::String; data::Vector{Vector{Float64}}; end
@implement ColTable MeasM
v = [[1.0, 2.0], [3.0, 5.0]]
