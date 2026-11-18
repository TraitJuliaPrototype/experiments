# E-347's tool: Julia's ambiguity reflection over the trait modules of the active environment
# (TraitWorld with BaseTraits, and every package that depends on it). A tie between a set's method
# and a method at `Any`, or between two sets' methods at a common member, is found here before any
# membership meets it (compiler §5.4). Usage: julia --project=<env> e347_detect.jl
using Pkg, Test
deps = Pkg.dependencies()
tw = only(u for (u, i) in deps if i.name == "TraitWorld")
function uses_tw(u, seen = Set{Base.UUID}())
    u == tw && return true
    u in seen && return false
    push!(seen, u)
    return any(v -> uses_tw(v, seen), values(deps[u].dependencies))
end
ids = sort([Base.PkgId(u, i.name) for (u, i) in deps if uses_tw(u)], by = x -> x.name)
proj = Pkg.project()
proj.name !== nothing && proj.uuid !== nothing && !any(x -> x.uuid == proj.uuid, ids) && push!(ids, Base.PkgId(proj.uuid, proj.name))
mods = Module[Base.require(id) for id in ids]
amb = Test.detect_ambiguities(mods...; recursive = true)
own(m) = any(r -> Base.moduleroot(parentmodule(m)) === r, mods)
amb = filter(p -> own(p[1]) || own(p[2]), amb)
amb = unique(p -> Set((p[1], p[2])), amb)   # a pair is listed in both orders across modules
for (a, b) in amb
    println("  ", a, "\n    ", b)
end
println("detect_ambiguities: ", length(mods), " packages (", join((m -> nameof(m)).(mods), ", "), "): ", length(amb), " ambiguities")
