# E-397, the control: does the reading at the box find the mistakes the check finds? Six methods, five with a
# use outside the contract (traits §7.3, §11.2's examples), in a module that does not refuse them.
#     AGREE_ROOTS=none julia --project=../../w134/env_lib mistakes.jl
module Mist
using TraitWorld
@trait_module bounded = false
@trait ColTable begin
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end
struct Wrapped{T}; t::T; end
good(t::ColTable, i::Int) = sum(col(t, i)) / ncols(t)
spread(t::ColTable) = size(t)                 # `size` is no operation
colsum(t::ColTable) = sum(t)                  # Base's `sum` iterates
field(t::ColTable) = t.data                   # no declared field
leak(t::ColTable) = typeof(t)                 # the code depends on the type
wrap(t::ColTable) = Wrapped(t)                # stored with its type
helper(x) = length(x)
through(t::ColTable) = helper(t)              # through an unannotated function of the module
end
const EXTRA = [Mist]
include(joinpath(@__DIR__, "agree.jl"))
