# Gate (traits §12.2, §12.3; compiler §9, §10.1; W-141): a pirate's membership in a package image behaves
# as a pirate's method under strict mode. Package PA owns a trait, two types and code compiled by facts
# that folds "T is not a Named". PB and PC own neither and declare T, and U, members.
#  1. Without strict mode: both memberships hold after the load, and PA's code answers with them.
#  2. Under strict mode: PB's membership would change PA's code compiled by facts. It is refused at the
#     load, with an error-level report: T is no member, the code keeps its answer, the membership has no
#     method in force. PC's membership changes no such code and holds.
# Usage: julia strict_pirate_membership.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuids = Dict("PA" => "a1a1a1a1-0000-4000-8000-0000000002aa", "PB" => "b2b2b2b2-0000-4000-8000-0000000002bb",
             "PC" => "c3c3c3c3-0000-4000-8000-0000000002cc")
srcs = Dict(
"PA" => """
module PA
using TraitWorld
@trait_module
export Named, T, U, isnamed
@trait Named begin
    name_of(x::Named)::String
end
struct T end
struct U end
name_of(::T) = "t"
name_of(::U) = "u"
isnamed(x) = x isa Named
end
""",
"PB" => """
module PB
using TraitWorld, PA
@implement PA.Named PA.T
end
""",
"PC" => """
module PC
using TraitWorld, PA
@implement PA.Named PA.U
end
""")
deps = Dict("PA" => ["TraitWorld"], "PB" => ["PA", "TraitWorld"], "PC" => ["PA", "TraitWorld"])
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
for p in ("PB", "PC")
    local ok, out = run_probe("using $p")
    @assert ok "precompiling $p: $out"
end
probe = """
using TraitWorld, PA
println("before: ", isnamed(T()))
using PC
using PB
impl(S) = length(methods(Core.implements, Tuple{Type{Named}, Type{S}}))
println("members: ", T <: Named, " ", U <: Named, "; answers: ", isnamed(T()), " ", isnamed(U()),
        "; methods: ", impl(T), " ", impl(U))
"""
ok, out = run_probe(probe)
println("plain: ", replace(out, "\n" => " | "))
@assert ok && occursin("before: false", out) "PA's code folds the negative at T: $out"
@assert occursin("members: true true; answers: true true; methods: 1 1", out) "without strict mode both memberships hold: $out"
@assert !occursin("PirateError", out) "without strict mode nothing is refused: $out"
ok, out = run_probe(probe; strict = true)
println("strict: ", replace(out, "\n" => " | "))
@assert ok && occursin("before: false", out) "PA's code folds the negative at T under strict mode: $out"
@assert occursin("PirateError: strict mode refuses the membership of `T` in `Named`", out) &&
        occursin("the image's membership is refused", out) "strict mode's report of PB's membership: $out"
@assert occursin("members: false true; answers: false true; methods: 0 1", out) "PB's membership refused, PC's holds: $out"
println("strict_pirate_membership: OK")
