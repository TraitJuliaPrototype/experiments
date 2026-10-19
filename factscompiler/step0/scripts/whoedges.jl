# Which code holds edges at abstract signatures in the facts image, and how was it compiled?
const csv = ARGS[1]
using CSV, DataFrames, Statistics
w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); nothing)
Base.invokelatest(w)
for (f, tt) in ((DataFrames.get_stats, Tuple{AbstractVector, Vector{Symbol}}), (isapprox, Tuple{Integer, Integer}),
                (Base.rtoldefault, Tuple{Integer, Integer, Int64}), (Statistics.quantile!, Tuple{AbstractVector, Float64}))
    for m in methods(f), mi in Base.specializations(m)
        mi isa Core.MethodInstance && mi.specTypes == Tuple{typeof(f), tt.parameters...} || continue
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            println(mi.specTypes, "\n   owner=", repr(ci.owner), " world ", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
                    " edges=", length(ci.edges), " flags: facts-method=", m.facts, " module facts=", ccall(:jl_get_module_facts, Int32, (Any,), m.module))
            for e in ci.edges[1:min(end, 6)]; println("     edge: ", e isa Core.MethodInstance ? e.specTypes : e isa Core.CodeInstance ? "CI " * string(e.def.specTypes) : e); end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
println("code_typed get_stats:")
ct = code_typed(DataFrames.get_stats, (AbstractVector, Vector{Symbol}))[1].first
for (i, st) in enumerate(ct.code); s = string(st); (occursin("quantile", s) || occursin("invoke", s)) && println("  ", i, "  ", first(s, 200)); end
