# E-180: where the parts' load goes. Loads the workload's packages, then each part of the cache in turn: the
# freshness check (`Base.isprecompiled`) and the load (`Base.require`) timed apart, with each part's entries.
#     JULIA_TW_CACHE_DIR=... julia --project=env_core cache/probe_parts.jl <cache key dir> <package> ...
using Serialization
const DIR = ARGS[1]
for p in ARGS[2:end]; Base.require(Main, Symbol(p)); end
push!(LOAD_PATH, joinpath(DIR, "parts"))
tf = tl = 0.0; n = 0
for l in eachline(joinpath(DIR, "index.txt"))
    f = split(l, '\t'); id = Base.PkgId(Base.UUID(f[2]), String(f[1]))
    deps = length(f) >= 3 ? [split(d, '=')[2] for d in split(f[3], ';'; keepempty = false)] : String[]
    all(d -> any(k -> k.name == d, keys(Base.loaded_modules)), deps) || continue
    a = @elapsed ok = Base.isprecompiled(id)
    b = @elapsed Base.require(id)
    ne = length(deserialize(joinpath(DIR, "parts", id.name, "src", "entries.jls")))
    global tf += a; global tl += b; global n += 1
    println("P ", rpad(join(deps, ","), 50), " entries ", lpad(ne, 5), "  fresh ", round(a * 1000; digits = 1), " ms  load ", round(b * 1000; digits = 1), " ms")
end
println("P total: ", n, " parts, freshness ", round(tf; digits = 3), " s, loads ", round(tl; digits = 3), " s")
