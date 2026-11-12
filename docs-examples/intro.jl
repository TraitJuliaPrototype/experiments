# The worked example of writeup/intro/traits-for-julia.md, with checks of the results the page states.
# Run from TraitWorld-unified/ on the unified build (see README.md):
#   JULIA_PKG_OFFLINE=true nice -n 19 ../julia-unified/julia --project=. --startup-file=no ../experiments/docs-examples/intro.jl
include(joinpath(@__DIR__, "common.jl"))
using TraitWorld

# --- the library ------------------------------------------------------------------------------

module Columns
using TraitWorld
@trait_module
export ColTable, ncols, col, colmean, meandiff, colmap, Shelf, shelf, add!, means

@trait ColTable begin                                  # what the library needs from a table
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end

@implement ColTable Vector{Vector{Float64}} begin      # the library's own membership
    ncols(t) = length(t)
    col(t, i) = t[i]
end

colmean(t::ColTable, i::Int) = (c = col(t, i); sum(c) / length(c))
meandiff(a::ColTable, b::ColTable, i::Int) = colmean(a, i) - colmean(b, i)

# a function argument with a declared signature, Float64 -> Float64
function colmap(f::Callable{Tuple{Float64}, Float64}, t::ColTable, i::Int)
    c = col(t, i)
    out = similar(c)
    for k in eachindex(c)
        out[k] = f(c[k])
    end
    return out
end

# tables of any member types, kept together
struct Shelf
    tables::Vector{ColTable}
end
shelf() = Shelf(ColTable[])
add!(s::Shelf, t::ColTable) = (push!(s.tables, t); s)
function means(s::Shelf, i::Int)
    out = Float64[]
    for t in s.tables
        push!(out, colmean(t, i))
    end
    return out
end
end

using .Columns

# --- its user, in ordinary Julia ----------------------------------------------------------------

import .Columns: ncols, col

struct Measurements
    label::String
    data::Vector{Vector{Float64}}
end
@implement ColTable Measurements by data

struct Ramp
    base::Vector{Float64}
    n::Int
end
ncols(r::Ramp) = r.n
col(r::Ramp, i::Int) = r.base .* i
@implement ColTable Ramp

m = Measurements("run 1", [[1.0, 2.0], [3.0, 5.0]])
r = Ramp([1.0, 2.0], 2)

check("Measurements <: ColTable", Measurements <: ColTable)
check("m isa ColTable", m isa ColTable)
check("colmean(m, 1) == 1.5", colmean(m, 1) == 1.5)
check("colmean(r, 2) == 3.0", colmean(r, 2) == 3.0)
check("meandiff(m, r, 1) == 0.0", meandiff(m, r, 1) == 0.0)
check("colmap(x -> 2x, m, 2) == [6.0, 10.0]", colmap(x -> 2x, m, 2) == [6.0, 10.0])
check("colmap(compiled_for(x -> 2x), m, 2)", colmap(compiled_for(x -> 2x), m, 2) == [6.0, 10.0])
check("colmean(with_dynamic(m), 1) == 1.5", colmean(with_dynamic(m), 1) == 1.5)

s = shelf()
add!(s, m); add!(s, r)
check("means(s, 1) == [1.5, 1.5]", means(s, 1) == [1.5, 1.5])
check("the shelf holds the members' own values", s.tables[1] === m)

d = Dynamic{ColTable}(r)
check("Dynamic{ColTable}(r) isa ColTable", d isa ColTable)
check("colmean(d, 2) == 3.0", colmean(d, 2) == 3.0)
check("unwrap(d) === r", unwrap(d) === r)

# --- the mistakes -------------------------------------------------------------------------------

struct Counts; n::Int; end
ncols(c::Counts) = c.n
col(c::Counts, i::Int) = fill(i, 3)       # a Vector{Int}
e = thrown(:(@implement ColTable Counts))
check("@implement ColTable Counts raises ImplementError", e isa TraitWorld.ImplementError)
println("MESSAGE ImplementError:\n", sprint(showerror, e))
check("Counts is no member", !(Counts <: ColTable))

e = try colmap(x -> 1, m, 1); nothing catch err; err end
check("a closure returning an Int raises TypeError", e isa TypeError)
e === nothing || println("MESSAGE TypeError:\n", sprint(showerror, e))

e = thrown(:(module Broken
    using TraitWorld
    @trait_module
    using ..Columns: ColTable, col
    colsum(t::ColTable) = sum(t)      # meant: sum(col(t, 1))
    end))
check("an open method in a trait module raises TraitUseError", e isa TraitWorld.TraitUseError)
e === nothing || println("MESSAGE TraitUseError:\n", sprint(showerror, e))

e = try colmean(42, 1); nothing catch err; err end
check("colmean(42, 1) raises MethodError", e isa MethodError)

summary()
