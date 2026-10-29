# E-228 (W-70): what the first `plot_two` over TraitMakie compiles (the CodeInstances inferred for it, by module).
#     julia --project=experiments/x3/env experiments/x3/firstplot5.jl > experiments/x3/logs/firstplot-slice5.log
using TraitMakie
include(joinpath(@__DIR__, "data", "solutions.jl")); include(joinpath(@__DIR__, "..", "ttfx", "plotting.jl"))
a, b, c = readsolutions()
new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
t = @elapsed plot_two(a, b, tempname() * ".png")
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
cis = filter(x -> x isa Core.CodeInstance, new)
println("first plot_two ", round(t * 1e3; digits = 1), " ms; CodeInstances inferred ", length(cis), "; by module:")
mods = Dict{String,Int}()
for ci in cis
    mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
    k = mi.def isa Method ? string(mi.def.module) : string(mi.def)
    mods[k] = get(mods, k, 0) + 1
end
foreach(((k, v),) -> println("  ", v, " ", k), sort(collect(mods); by = last, rev = true))
println("outside Base and Core:")
for ci in cis
    mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
    mi.def isa Method && !(mi.def.module in (Base, Core, Base.Broadcast)) && println("  ", mi)
end
