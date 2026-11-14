# Gate (traits §6.5, T-102; lowering §8): `like` and `withfields` on a forwarding member declared in a
# precompiled package. The member's `@implement … by f` defines `like`'s rebuilding of it as a method,
# which the package's image keeps; nothing is looked up when `like` runs, so both are fully typed.
# Usage: julia like_precompiled.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuid_pa = "a1a1a1a1-0000-4000-8000-0000000004aa"
mkpath(joinpath(root, "PA", "src"))
write(joinpath(root, "PA", "Project.toml"), """
name = "PA"
uuid = "$uuid_pa"
[deps]
TraitWorld = "$uuid_tw"
""")
write(joinpath(root, "PA", "src", "PA.jl"), """
module PA
using TraitWorld
@trait_module
export Cols, ncols, Named, relabel
@trait Cols begin
    ncols(t::Cols)::Int
end
ncols(v::Vector{Vector{Float64}}) = length(v)
@implement Cols Vector{Vector{Float64}}
struct Named
    name::String
    cols::Vector{Vector{Float64}}
end
@implement Cols Named by cols
relabel(t::Named) = withfields(t; name = "r")
end
""")
env = joinpath(root, "env"); mkpath(env)
twdeps = sort!(collect(keys(get(Base.parsed_toml(joinpath(tw, "Project.toml")), "deps", Dict()))))
stdlibs = Dict{String, Any}()
function addstd!(name)
    haskey(stdlibs, name) && return
    proj = Base.parsed_toml(joinpath(Sys.STDLIB, name, "Project.toml"))
    stdlibs[name] = proj
    foreach(addstd!, keys(get(proj, "deps", Dict())))
end
foreach(addstd!, twdeps)
quoted(xs) = "[" * join(("\"$x\"" for x in sort!(collect(xs))), ", ") * "]"
depsline(ds) = isempty(ds) ? "" : "deps = $(quoted(ds))\n"
stdentries = join(("""
[[deps.$n]]
$(depsline(keys(get(stdlibs[n], "deps", Dict()))))uuid = "$(stdlibs[n]["uuid"])"
""" for n in sort!(collect(keys(stdlibs)))), "")
write(joinpath(env, "Project.toml"), "[deps]\nPA = \"$uuid_pa\"\nTraitWorld = \"$uuid_tw\"\n")
write(joinpath(env, "Manifest.toml"), """
julia_version = "$(VERSION)"
manifest_format = "2.0"

[[deps.PA]]
deps = ["TraitWorld"]
path = "$(joinpath(root, "PA"))"
uuid = "$uuid_pa"
version = "0.0.0"

[[deps.TraitWorld]]
$(depsline(twdeps))path = "$tw"
uuid = "$uuid_tw"
version = "0.2.0"
$stdentries""")
julia = Base.julia_cmd()
depot = joinpath(root, "depot")
function run_probe(code::String; strict = false)
    cmd = addenv(`$julia --startup-file=no --project=$env -e $code`, "JULIA_DEPOT_PATH" => depot * ":",
                 "JULIA_TW_STRICT" => strict ? "1" : "0")
    out = IOBuffer()
    p = run(pipeline(ignorestatus(cmd), stdout = out, stderr = out))
    return success(p), String(take!(out))
end
probe = """
using TraitWorld, PA
n = Named("n", [[1.0], [2.0]])
m = like(n, [[3.0]])
println("like: ", m isa Named, " ", m.name, " ", ncols(m), "; withfields: ", relabel(n).name)
println("typed: ", isfullytyped(fully_typed(like, (Named, Vector{Vector{Float64}}))), " ", isfullytyped(fully_typed(relabel, (Named,))))
"""
ok, out = run_probe(probe)             # the first run precompiles
ok, out = run_probe(probe)
println("plain: ", replace(out, "\n" => " | "))
@assert ok && occursin("like: true n 1; withfields: r", out) "like on a member of a precompiled package: $out"
@assert occursin("typed: true true", out) "like and withfields are fully typed: $out"
ok, out = run_probe(probe; strict = true)
println("strict: ", replace(out, "\n" => " | "))
@assert ok && occursin("like: true n 1; withfields: r", out) && !occursin("PirateError", out) "under strict mode: $out"
println("like_precompiled: OK")
