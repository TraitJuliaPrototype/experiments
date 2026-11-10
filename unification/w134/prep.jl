# W-134 (E-355): copies of the upstream packages, each with one line added that compiles its module by facts.
#     julia --project=../../../forks-unified/env_upstream prep.jl pkgs-facts
# The copies are not committed; this script makes them from the depot.
using TOML
const LINE = "\nBase.Experimental.@compiler_options facts=true bounded=false no_pirates=false dynamic=false first_seen=true   # W-134: the one line added\n"
m = TOML.parsefile(joinpath(dirname(Base.active_project()), "Manifest.toml"))["deps"]
for p in ("CSV", "DataFrames", "Tables", "Parsers", "InlineStrings", "PooledArrays", "SentinelArrays")
    id = Base.PkgId(Base.UUID(m[p][1]["uuid"]), p)
    root = dirname(dirname(Base.locate_package(id)))
    dst = joinpath(ARGS[1], p); isdir(dst) || cp(root, dst)
    run(`chmod -R u+w $dst`)
    f = joinpath(dst, "src", p * ".jl"); s = read(f, String)
    r = findfirst(Regex("^(bare)?module $p\\b.*\$", "m"), s)
    occursin("W-134", s) || write(f, s[1:last(r)] * LINE * s[nextind(s, last(r)):end])
    println(p, " ", m[p][1]["version"])
end
