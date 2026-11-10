# Gate (traits §5.10, §5.11; compiler §10.1; lowering L-55): a member's check holds while it is a member,
# across packages. Package TA declares a trait, a family member and a concrete member.
#  1. The session checks the family's member Fam{Int} at its first use; then package TC, precompiled
#     before, loads a method that would serve Fam{Int}'s checked call with an Int: its image's method is
#     left inactive with a warning, and the call keeps its Float64.
#  2. Package TD redefines its own member's serving method after its `@implement`, outside the declared
#     result: its precompilation fails with ImplementError.
#  3. The case not covered (L-55): package TE loads a method at TA's concrete member Square, whose
#     membership comes from TA's image, so no record of its check is in the session: accepted. When
#     L-55's rebuild of the records at load is built, this line flips.
# Usage: julia recheck_packages.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuids = Dict("TA" => "a1a1a1a1-0000-4000-8000-0000000000aa", "TC" => "c3c3c3c3-0000-4000-8000-0000000000cc",
             "TD" => "d4d4d4d4-0000-4000-8000-0000000000dd", "TE" => "e5e5e5e5-0000-4000-8000-0000000000ee")
srcs = Dict(
"TA" => """
module TA
using TraitWorld
@trait_module
export Shape, area, via, Fam, Square
@trait Shape begin
    area(s::Shape, k::Int)::Float64
end
via(s::Shape, k::Int) = area(s, k)
struct Fam{P}; x::P; end
area(::Fam, k::Integer) = 1.0
@implement Shape Fam{P} where {P}
struct Square; side::Float64; end
area(s::Square, k::Integer) = s.side^2
@implement Shape Square
end
""",
"TC" => """
module TC
using TA
TA.area(::TA.Fam{Int}, k::Int) = 1                  # an Int where Shape declares Float64
end
""",
"TD" => """
module TD
using TraitWorld, TA
struct Tri end
TA.area(::Tri, k::Integer) = 1.0
@implement Shape Tri
TA.area(::Tri, k::Int) = 2                          # after the check, outside the declared result
end
""",
"TE" => """
module TE
using TA
TA.area(::TA.Square, k::Int) = 1                    # at a member whose membership is in TA's image
end
""")
deps = Dict("TA" => ["TraitWorld"], "TC" => ["TA"], "TD" => ["TA", "TraitWorld"], "TE" => ["TA"])
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
deps = $(quoted(deps[n]))
path = "$(joinpath(root, n))"
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
function run_probe(code::String)
    cmd = addenv(`$julia --startup-file=no --project=$env -e $code`, "JULIA_DEPOT_PATH" => depot * ":")
    out = IOBuffer()
    p = run(pipeline(ignorestatus(cmd), stdout = out, stderr = out))
    return success(p), String(take!(out))
end
# the images first: TC and TE precompile in a session with no record; TD fails
ok0, pre = run_probe("using TA, TC, TE")
println("precompile TA, TC, TE: ", ok0 ? "ok" : "FAILED\n" * pre)
ok1, out1 = run_probe("""
using TraitWorld, TA
TraitWorld.check_first_use(Fam{Int}, Shape)
println("before: ", via(Fam(1), 2))
using TC
println("after: ", via(Fam(1), 2), " ", area(Fam(1), 2))
""")
ok2, out2 = run_probe("using TD")
ok3, out3 = run_probe("""
using TA, TE
println("uncovered: ", area(Square(1.0), 2))
""")
println("1: ", replace(out1, "\n" => " | "))
println("2: ", ok2 ? "loaded" : "failed: " * first(split(split(out2, "ImplementError")[end], "\n")))
println("3: ", replace(out3, "\n" => " | "))
@assert ok0 "TA, TC and TE precompile"
@assert ok1 && occursin("before: 1.0", out1) && occursin("after: 1.0 1.0", out1) "TC's method is left inactive"
@assert occursin("a method left inactive", out1) "with a warning"
@assert !ok2 && occursin("ImplementError", out2) "TD fails to precompile with ImplementError"
@assert ok3 && occursin(r"uncovered: 1(\n|$)", out3) "the case L-55 covers: accepted (flip when the records are rebuilt at load)"
println("recheck_packages: OK")
