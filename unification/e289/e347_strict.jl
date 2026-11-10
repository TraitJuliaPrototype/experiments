# E-347: every package of the active environment that depends on TraitWorld is precompiled again
# under strict mode (JULIA_TW_STRICT=1 reaches each precompile process), into the first depot.
# Counts the memberships strict mode refuses for an ambiguity and the report's warnings.
# Usage: JULIA_TW_STRICT=1 JULIA_DEPOT_PATH=<fresh depot>:<the depot> julia --project=<env> e347_strict.jl
using Pkg
deps = Pkg.dependencies()
tw = only(u for (u, i) in deps if i.name == "TraitWorld")
function uses_tw(u, seen = Set{Base.UUID}())
    u == tw && return true
    u in seen && return false
    push!(seen, u)
    return any(v -> uses_tw(v, seen), values(deps[u].dependencies))
end
ids = sort([Base.PkgId(u, i.name) for (u, i) in deps if u != tw && uses_tw(u)], by = x -> x.name)
proj = Pkg.project()
proj.name !== nothing && proj.name != "TraitWorld" && proj.uuid !== nothing && push!(ids, Base.PkgId(proj.uuid, proj.name))
refused = 0; warned = 0; failed = String[]
for id in ids
    n = id.name
    err = IOBuffer()
    ok = try
        Base.compilecache(id, err, err); true
    catch e
        print(err, sprint(showerror, e)); false
    end
    s = String(take!(err))
    r = count("strict mode refuses the membership", s); w = count(" is ambiguous for ", s)
    global refused += r; global warned += w
    ok || push!(failed, n)
    println(rpad(n, 34), ok ? "ok" : "FAILED", "  refused ", r, "  warnings ", w)
    (ok && r == 0 && w == 0) || println(s)
end
println("strict precompile: ", length(ids), " packages, ", length(failed), " failed, ", refused, " refused, ", warned, " warnings")
