using Pkg, TOML
m = TOML.parsefile(joinpath(ARGS[1], "Manifest.toml"))
miss = String[]; global n = 0
for (name, es) in m["deps"], e in es
    global n += 1
    haskey(e, "git-tree-sha1") || continue
    p = Pkg.Operations.find_installed(name, Base.UUID(e["uuid"]), Base.SHA1(e["git-tree-sha1"]))
    isdir(p) || push!(miss, "$name $(get(e, "version", "?"))")
end
println(n, " manifest entries; missing sources: ", length(miss)); foreach(println, sort(miss))
