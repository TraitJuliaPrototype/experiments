# E-238: the shape of Julia's invalidation log over the forks' imports (a look at its entries, not a measurement).
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
using CSV, DataFrames, Statistics, Dates
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
sh(x) = x isa Core.MethodInstance ? "MI " * first(sprint(show, x), 150) :
        x isa Core.CodeInstance ? "CI(" * string(x.owner) * ") " * first(sprint(show, x.def), 150) :
        x isa Method ? "M " * first(sprint(show, x), 150) : string(typeof(x), " ", first(sprint(show, x), 150))
println("length ", length(invs))
for i in 1:min(80, length(invs)); println(i, "  ", sh(invs[i])); end
tags = Dict{String,Int}(); for x in invs; x isa String && (tags[x] = get(tags, x, 0) + 1); end
println(tags)
types = Dict{Any,Int}(); for x in invs; types[typeof(x)] = get(types, typeof(x), 0) + 1; end
println(types)
