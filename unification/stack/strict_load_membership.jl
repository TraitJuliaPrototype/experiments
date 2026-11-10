# Gate (traits §12.3, W-133; E-353): under strict mode, each checked call of each membership a package
# image brings is inferred after its load. A method the session held before the load, which serves the
# call with a result outside the declared one, is reported at error level: it came first, so it is not
# refused. Package LA owns a type and a helper. LB declares a trait with an
# operation (result `Int`), a method at the type that calls the helper, and the type's membership.
#  1. A session that gives the helper a method at the type (result a String) before `using LB`:
#     under strict mode the report names the operation and the member; without it nothing is said.
#  2. A session with no such method: no report under strict mode.
#  3. The other order (the method after `using LB`): printed, what strict mode does at the definition.
# Usage: julia strict_load_membership.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuids = Dict("LA" => "a1a1a1a1-0000-4000-8000-0000000002aa", "LB" => "b2b2b2b2-0000-4000-8000-0000000002bb")
srcs = Dict(
"LA" => """
module LA
export S, helper
struct S end
helper(x) = 1
end
""",
"LB" => """
module LB
using TraitWorld, LA
@trait Sz begin
    sz(x::Sz)::Int
end
sz(s::LA.S) = LA.helper(s)
@implement Sz LA.S
end
""")
deps = Dict("LA" => String[], "LB" => ["LA", "TraitWorld"])
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
let (ok, out) = run_probe("using LB")
    @assert ok "precompiling LB: $out"
end
probe(before, after) = """
using TraitWorld
using LA
$(before ? "LA.helper(::LA.S) = \"one\"" : "")
using LB
r = try
    $(after ? "@eval LA.helper(::LA.S) = \"one\"" : "")
    "defined"
catch e
    "refused: " * string(typeof(e))
end
println("definition after: ", r)
println("call: ", Base.invokelatest(LB.sz, S()))
println("listed: ", length(TraitWorld._LOAD_MEMBERSHIPS))
"""
report = "Error: strict mode: a package image's membership fails its check in this session"
let (ok, out) = run_probe(probe(true, false))
    println("plain, the method first: ", replace(out, "\n" => " | "))
    @assert ok && occursin("call: one", out) "the method serves the call: $out"
    @assert !occursin(report, out) && occursin("listed: 0", out) "without strict mode nothing is said"
end
let (ok, out) = run_probe(probe(true, false); strict = true)
    println("strict, the method first: ", replace(out, "\n" => " | "))
    @assert ok && occursin(report, out) && occursin("`sz` at S", out) && occursin("String", out) &&
            occursin("listed: 1", out) "strict mode's report: $out"
end
let (ok, out) = run_probe(probe(false, false); strict = true)
    println("strict, no method: ", replace(out, "\n" => " | "))
    @assert ok && !occursin(report, out) && occursin("listed: 0", out) && occursin("call: 1", out) "no finding without the method: $out"
end
let (ok, out) = run_probe(probe(false, true); strict = true)
    println("strict, the method after the load: ", replace(out, "\n" => " | "))
    @assert ok "the other order runs: $out"
end
println("strict_load_membership: OK")
