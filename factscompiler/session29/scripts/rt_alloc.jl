using TraitWorld, Profile
include("/home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/recovery/RTTrait.jl")
using .RTTrait
RTTrait.perf_raytrace(3, 8, 2)
Profile.Allocs.clear()
Profile.Allocs.@profile sample_rate=0.02 RTTrait.perf_raytrace(5, 64, 2)
r = Profile.Allocs.fetch()
d = Dict{Any,Int}()
for a in r.allocs
    fr = [string(f.func, " ", basename(string(f.file)), ":", f.line) for f in a.stacktrace if !occursin("Profile", string(f.file)) && !occursin("gc", string(f.func))]
    k = (a.type, a.size, join(first(fr, 4), " <- "))
    d[k] = get(d, k, 0) + 1
end
for (k, v) in first(sort(collect(d); by = last, rev = true), 12)
    println(v, "  ", k[1], " ", k[2], "B\n     ", k[3])
end
