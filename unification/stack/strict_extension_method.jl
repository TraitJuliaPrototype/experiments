# Gate (traits §12.3, T-97): a package extension counts as its parent, so its method for the parent's
# function is no pirate. Under strict mode, one that wins at a fact of code compiled by facts and names
# no type of its triggers is followed, with a warning; one that names a trigger's type gives none.
# Package PA owns `scale` and code compiled by facts that calls `scale(::Float64)`. Its extension
# PADatesExt (trigger: Dates) defines the more specific `scale(::Float64)`, and `scale(::Dates.Day)`.
# Usage: julia strict_extension_method.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuid_pa = "a1a1a1a1-0000-4000-8000-0000000003aa"
uuid_dates = Base.parsed_toml(joinpath(Sys.STDLIB, "Dates", "Project.toml"))["uuid"]
mkpath(joinpath(root, "PA", "src")); mkpath(joinpath(root, "PA", "ext"))
write(joinpath(root, "PA", "Project.toml"), """
name = "PA"
uuid = "$uuid_pa"
[deps]
TraitWorld = "$uuid_tw"
[weakdeps]
Dates = "$uuid_dates"
[extensions]
PADatesExt = "Dates"
""")
write(joinpath(root, "PA", "src", "PA.jl"), """
module PA
using TraitWorld
@trait_module
export scale, scaled
scale(x::Real) = 2.0 * x
scaled(xs::Vector{Float64}) = (s = 0.0; for x in xs; s += scale(x); end; s)
scaled([1.0, 2.0])                 # compiled into the image: code compiled by facts that calls scale(::Float64)
end
""")
write(joinpath(root, "PA", "ext", "PADatesExt.jl"), """
module PADatesExt
using PA, Dates
PA.scale(x::Float64) = 4.0 * x     # more specific than PA's own: names no type of Dates, and wins at PA's compiled call
PA.scale(d::Dates.Day) = d         # names a trigger's type
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
foreach(addstd!, twdeps); addstd!("Dates")
quoted(xs) = "[" * join(("\"$x\"" for x in sort!(collect(xs))), ", ") * "]"
depsline(ds) = isempty(ds) ? "" : "deps = $(quoted(ds))\n"
stdentries = join(("""
[[deps.$n]]
$(depsline(keys(get(stdlibs[n], "deps", Dict()))))uuid = "$(stdlibs[n]["uuid"])"
""" for n in sort!(collect(keys(stdlibs)))), "")
write(joinpath(env, "Project.toml"), "[deps]\nPA = \"$uuid_pa\"\nTraitWorld = \"$uuid_tw\"\nDates = \"$uuid_dates\"\n")
write(joinpath(env, "Manifest.toml"), """
julia_version = "$(VERSION)"
manifest_format = "2.0"

[[deps.PA]]
deps = ["TraitWorld"]
path = "$(joinpath(root, "PA"))"
uuid = "$uuid_pa"
version = "0.0.0"
weakdeps = ["Dates"]

    [deps.PA.extensions]
    PADatesExt = "Dates"

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
using TraitWorld, PA, Dates
ext = Base.get_extension(PA, :PADatesExt)
println("extension: ", ext !== nothing, "; owner: ", ext === nothing ? nothing : TraitWorld.owner(ext))
println("scaled: ", scaled([1.0, 2.0]), "; day: ", scale(Dates.Day(1)))
"""
ok, out = run_probe(probe)             # the first run precompiles
ok, out = run_probe(probe)
println("plain: ", replace(out, "\n" => " | "))
@assert ok && occursin("extension: true; owner: PA", out) "the extension loads and counts as its parent: $out"
@assert occursin("scaled: 12.0", out) "the extension's method is followed: $out"
@assert !occursin("names no type of its triggers", out) "no warning without strict mode: $out"
ok, out = run_probe(probe; strict = true)
println("strict: ", replace(out, "\n" => " | "))
@assert ok && occursin("scaled: 12.0", out) "under strict mode the extension's method is followed: $out"
@assert occursin("in the package extension PADatesExt names no type of its triggers (Dates)", out) "the warning: $out"
@assert count("names no type of its triggers", out) == 1 "one warning: the method at Dates.Day names a trigger: $out"
@assert !occursin("PirateError", out) "no pirate: $out"
println("strict_extension_method: OK")
