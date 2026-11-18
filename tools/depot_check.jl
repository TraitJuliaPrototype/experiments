# For each Manifest.toml named on stdin: the registry packages (by git-tree-sha1) with no installation in the depot.
# Usage, from the workspace root after `source env.sh`:
#     find <trees> -maxdepth 6 -name Manifest.toml | julia-next/julia --startup-file=no experiments/tools/depot_check.jl
using TOML
depots = filter(isdir, [joinpath(d, "packages") for d in DEPOT_PATH])
missing_by_manifest = Dict{String,Vector{String}}()
allmissing = Set{String}()
nman = 0
for mf in eachline(stdin)
    isfile(mf) || continue
    global nman += 1
    m = try TOML.parsefile(mf) catch; continue end
    deps = get(m, "deps", Dict())
    for (name, entries) in deps
        entries isa Vector || continue
        for e in entries
            sha = get(e, "git-tree-sha1", nothing); uuid = get(e, "uuid", nothing)
            (sha === nothing || uuid === nothing) && continue
            haskey(e, "path") && continue
            slug = Base.version_slug(Base.UUID(uuid), Base.SHA1(sha))
            found = any(isdir(joinpath(d, name, slug)) for d in depots)
            if !found
                push!(get!(missing_by_manifest, mf, String[]), "$name $(get(e, "version", "?"))")
                push!(allmissing, "$name $(get(e, "version", "?")) $slug")
            end
        end
    end
end
println("manifests read: ", nman, "; with a missing package: ", length(missing_by_manifest), "; distinct missing installations: ", length(allmissing))
for (mf, v) in sort(collect(missing_by_manifest); by = first)
    println(rpad(length(v), 4), mf, "  e.g. ", join(first(sort(v), 4), ", "))
end
