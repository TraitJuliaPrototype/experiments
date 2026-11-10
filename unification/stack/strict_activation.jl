# Gate (traits §12.3, T-98; compiler §5.4, §9; E-349): under strict mode an image's membership that meets
# an ambiguity with code loaded earlier is reported by strict mode after the load, at error level, in
# place of the runtime's warning. Package SA owns a type and a function. SB and SC each declare a trait,
# a method of SA's function at it and the type's membership: each image is consistent alone; the second
# to load makes the two methods ambiguous at the type.
#  1. Without strict mode: the runtime's warning at the second load.
#  2. Under strict mode: no warning; strict mode's error-level report names the function, and the
#     library's list holds one message. Either load order.
# Usage: julia strict_activation.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuids = Dict("SA" => "a1a1a1a1-0000-4000-8000-0000000001aa", "SB" => "b2b2b2b2-0000-4000-8000-0000000001bb",
             "SC" => "c3c3c3c3-0000-4000-8000-0000000001cc")
srcs = Dict(
"SA" => """
module SA
export S, fs
struct S end
function fs end
end
""",
"SB" => """
module SB
using TraitWorld, SA
@trait YS
SA.fs(::YS) = :y
@implement YS SA.S
end
""",
"SC" => """
module SC
using TraitWorld, SA
@trait ZS
SA.fs(::ZS) = :z
@implement ZS SA.S
end
""")
deps = Dict("SA" => String[], "SB" => ["SA", "TraitWorld"], "SC" => ["SA", "TraitWorld"])
uuidof(n) = n == "TraitWorld" ? uuid_tw : uuids[n]
for (n, src) in srcs
    mkpath(joinpath(root, n, "src"))
    write(joinpath(root, n, "Project.toml"), "name = \"$n\"\nuuid = \"$(uuids[n])\"\n[deps]\n" *
          join(("$d = \"$(uuidof(d))\"\n" for d in deps[n]), ""))
    write(joinpath(root, n, "src", "$n.jl"), src)
end
env = joinpath(root, "env")
mkpath(env)
# TraitWorld's dependencies are stdlibs; the manifest lists them and, transitively, theirs
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
depsline(ds) = isempty(ds) ? "" : "deps = $(quoted(ds))\n"     # an empty list would parse as Vector{Any}
stdentries = join(("""
[[deps.$n]]
$(depsline(keys(get(stdlibs[n], "deps", Dict()))))uuid = "$(stdlibs[n]["uuid"])"
""" for n in sort!(collect(keys(stdlibs)))), "")
write(joinpath(env, "Project.toml"), "[deps]\n" * join(("$n = \"$(uuidof(n))\"\n" for n in sort!(collect(keys(srcs)))), "") *
      "TraitWorld = \"$uuid_tw\"\n")
pkgentries = join(("""
[[deps.$n]]
$(depsline(deps[n]))path = "$(joinpath(root, n))"
uuid = "$(uuids[n])"
version = "0.0.0"
""" for n in sort!(collect(keys(srcs)))), "")
write(joinpath(env, "Manifest.toml"), """
julia_version = "$(VERSION)"
manifest_format = "2.0"
$pkgentries[[deps.TraitWorld]]
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
for p in ("SB", "SC")
    local ok, out = run_probe("using $p")
    @assert ok "precompiling $p: $out"
end
probe(a, b) = """
using TraitWorld
using $a
using $b
using SA
println("call: ", try string(fs(S())) catch e; e isa MethodError ? "ambiguous" : "wrong" end)
println("listed: ", isdefined(TraitWorld, :_LOAD_AMBIGUITIES) ? length(TraitWorld._LOAD_AMBIGUITIES) : -1)
"""
for (a, b) in (("SB", "SC"), ("SC", "SB"))
    local ok, out = run_probe(probe(a, b))
    println("plain $a, $b: ", replace(out, "\n" => " | "))
    @assert ok && occursin("call: ambiguous", out) "the ambiguity is real ($a, $b): $out"
    @assert occursin("WARNING: method fs", out) && occursin("listed: 0", out) "without strict mode, the runtime's warning ($a, $b)"
    ok, out = run_probe(probe(a, b); strict = true)
    println("strict $a, $b: ", replace(out, "\n" => " | "))
    @assert ok && occursin("call: ambiguous", out) "the ambiguity is real under strict mode ($a, $b): $out"
    @assert !occursin("WARNING: method fs", out) "under strict mode, no runtime warning ($a, $b)"
    @assert occursin("Error: strict mode: a package image's membership makes methods ambiguous", out) &&
            occursin("method fs", out) && occursin("listed: 1", out) "strict mode's report ($a, $b): $out"
end
println("strict_activation: OK")
