using CSV, DataFrames, Statistics, Dates
println("ext: ", Base.get_extension(CSV, :CSVDataFramesInlineStringsExt), "  ", Base.get_extension(CSV, :CSVInlineStringsExt))
using InlineStrings
D = "/home/hellmann/Repos/julia-trait-bound/forks/data"
df = CSV.read(joinpath(D, "people.csv"), DataFrame); show(IOBuffer(), df)
function cis()
    s = Set{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && push!(s, ci)
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    s
end
s0 = cis()
@time "read String15" df3 = CSV.read(joinpath(D, "people.csv"), DataFrame; stringtype = String15)
s1 = cis()
@time "show" show(IOContext(IOBuffer(), :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), df3)
s2 = cis()
for (l, a, b) in (("read", s0, s1), ("show", s1, s2))
    n = setdiff(b, a); d = Dict{Any,Int}()
    for ci in n; k = (ci.owner, nameof(ci.def.def.module)); d[k] = get(d, k, 0) + 1; end
    println(l, ": ", length(n), " new: ", d)
    for ci in first(collect(n), 12); println("   ", repr(ci.owner), " ", first(string(ci.def.specTypes), 200)); end
end
