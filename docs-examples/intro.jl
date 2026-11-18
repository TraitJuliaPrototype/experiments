# The worked example of writeup/intro/traits-for-julia.md, with checks of the results the page states.
# Run from TraitWorld/ (see README.md):
#   JULIA_PKG_OFFLINE=true nice -n 19 ../julia-next/julia --project=. --startup-file=no ../experiments/docs-examples/intro.jl
include(joinpath(@__DIR__, "common.jl"))
using TraitWorld
# The page's `compiled_for` is the library's export, the wrapper's function.
check("the library exports compiled_for, the wrapper's function",
      compiled_for(1.0) isa TraitWorld.Compiled{Float64} && !isdefined(Core, :compiled_for))

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

# tables of any member types, held together
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
# the value's type decides: a call at the prompt runs the code compiled for Measurements, as in a function
check("at the prompt, colmean(m, 1) runs the code compiled for Measurements",
      any(mi -> mi.specTypes == Tuple{typeof(colmean), Measurements, Int}, Base.specializations(only(methods(colmean)))))
println("      colmean's instances after the call: ",
        join(sort([string(mi.specTypes) for mi in Base.specializations(only(methods(colmean)))]), ", "))
check("colmean(r, 2) == 3.0", colmean(r, 2) == 3.0)
check("meandiff(m, r, 1) == 0.0", meandiff(m, r, 1) == 0.0)
check("colmap(x -> 2x, m, 2) == [6.0, 10.0]", colmap(x -> 2x, m, 2) == [6.0, 10.0])
check("colmap(compiled_for(x -> 2x), m, 2) == [6.0, 10.0]", colmap(compiled_for(x -> 2x), m, 2) == [6.0, 10.0])
check("colmean(Dynamic{ColTable}(m), 1) == 1.5", colmean(Dynamic{ColTable}(m), 1) == 1.5)
check("colmean(compiled_for(m), 1) == 1.5", colmean(compiled_for(m), 1) == 1.5)

s = shelf()
add!(s, m); add!(s, r)
check("means(s, 1) == [1.5, 1.5]", means(s, 1) == [1.5, 1.5])
check("the shelf holds the members' own values", s.tables[1] === m)

d = Dynamic{ColTable}(r)
check("Dynamic{ColTable}(r) isa ColTable", d isa ColTable)
check("colmean(d, 2) == 3.0", colmean(d, 2) == 3.0)
check("unwrap(d) === r", unwrap(d) === r)
w = compiled_for(m)
check("compiled_for(m) isa ColTable, and is not m", w isa ColTable && !(w isa Measurements) && w !== m && unwrap(w) === m)
bs = Dynamic{ColTable}[]
push!(bs, m); push!(bs, compiled_for(r))
check("a Vector{Dynamic{ColTable}} boxes each member stored", all(x -> x isa Dynamic{ColTable}, bs) && unwrap(bs[2]) === r)

# Callable: the signature is checked where the function enters; passing it on to map passes the box
e = try colmap(uppercase, m, 1); nothing catch err; err end
check("colmap(uppercase, m, 1) raises MethodError", e isa MethodError)
e = thrown(:(module Mapper
    using TraitWorld
    @trait_module
    using ..Columns: ColTable, col
    colmap2(f::Callable{Tuple{Float64}, Float64}, t::ColTable, i::Int) = map(f, col(t, i))
    end))
check("a trait module accepts a method that passes f on to map", e === nothing)
e === nothing || println("MESSAGE map:\n", msg(e))
e === nothing && check("colmap2(x -> 2x, m, 2) == [6.0, 10.0]", Base.invokelatest(Mapper.colmap2, x -> 2x, m, 2) == [6.0, 10.0])

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
check("an unbounded method in a trait module raises TraitUseError", e isa TraitWorld.TraitUseError)
e === nothing || println("MESSAGE TraitUseError:\n", sprint(showerror, e))
deviation("the TraitUseError names the method as a call, no tuple type", "open issue 235",
          () -> e isa Exception && !occursin("Tuple{", msg(e)))

e = try colmean(42, 1); nothing catch err; err end
check("colmean(42, 1) raises MethodError", e isa MethodError)

summary()
