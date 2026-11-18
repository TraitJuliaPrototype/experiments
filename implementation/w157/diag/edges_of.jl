# W-157: the edges of the CodeInstances of the given signatures, after the forks' work (`census_lib.jl`).
#     julia --project=env_forks diag/edges_of.jl <csv>   (the signatures are below)
include(joinpath(@__DIR__, "..", "census_lib.jl"))
S = census_session(ARGS[1])
want = [Tuple{Type{Base.Broadcast.BroadcastStyle}, Base.Broadcast.DefaultArrayStyle{1}, Base.Broadcast.DefaultArrayStyle{0}}]
for ci in S.reach
    any(t -> ci.def.specTypes === t, want) || continue
    println("== ", ci.def.specTypes, " bit ", bit(ci), " rettype ", ci.rettype)
    for e in ci.edges; println("   ", typeof(e).name.name, ": ", e isa Core.CodeInstance ? (e.def.specTypes, "bit", bit(e), "rettype", e.rettype) : e); end
end
v = [ci for ci in S.reach if ci.def.specTypes === Tuple{Type{Val}, Int64}]
for ci in v; println("== Val(::Int64) CI: rettype ", ci.rettype, " edges ", ci.edges, " callers ", length(get(S.rev, ci, []))); end
