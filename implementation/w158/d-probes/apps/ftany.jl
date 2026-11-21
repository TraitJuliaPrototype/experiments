# W-158, piece 2: does a closed build resolve `cn(xs[1])` at an element of `Vector{Any}` (the messages tool's case
# `cf1`)? Built with `bash ../../build_app.sh julia-next ftany.jl d-ftany <library tree>`. Run with no argument: the
# element is a member; with one: a box of it; with two: a wrapper of it.
using TraitWorld
module CLib
using TraitWorld
@trait CTab begin
    cn(t::CTab)::Int
    ccol(t::CTab, i::Int)::Vector{Float64}
end
export CTab, cn, ccol
end
using .CLib
struct CT; cols::Vector{Vector{Float64}}; end
CLib.cn(t::CT) = length(t.cols)
CLib.ccol(t::CT, i::Int) = t.cols[i]
@implement CTab CT

cf1(xs::Vector{Any}) = cn(xs[1])

function (@main)(args::Vector{String})::Cint
    t = CT([[1.0], [2.0]])
    xs = Any[t]
    length(args) == 1 && (xs[1] = Dynamic{CTab}(t))
    length(args) == 2 && (xs[1] = compiled_for(t))
    println(Core.stdout, cf1(xs))
    return 0
end
