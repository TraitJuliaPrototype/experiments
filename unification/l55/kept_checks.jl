# Gate (lowering §11, L-55; compiler §10.4): a package image keeps the members of patterns checked while
# it was built. Package TA declares a trait and a family member. Package TB uses Fam{Int} while it is
# precompiled: the check runs there, and TB's image keeps the answer.
#  1. A session that loads TB has the answer for (Fam{Int}, Shape) from the image: the runtime lists it,
#     the library's sync makes its records again, and no check runs at the first use.
#  2. In that session a method that would serve Fam{Int}'s checked call outside the declared result is
#     refused at its definition, before any use of Fam{Int}.
#  3. The control, without TB: the same definition is accepted (no member of the family is checked yet).
#  4. Fam{Float64}, which no image checked, is checked at its first use, as before.
# Usage: julia kept_checks.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
uuids = Dict("TA" => "a1a1a1a1-0000-4000-8000-0000000000aa", "TB" => "b2b2b2b2-0000-4000-8000-0000000000bb")
srcs = Dict(
"TA" => """
module TA
using TraitWorld
@trait_module
export Shape, area, via, Fam
@trait Shape begin
    area(s::Shape, k::Int)::Float64
end
via(s::Shape, k::Int) = area(s, k)
struct Fam{P}; x::P; end
area(::Fam, k::Integer) = 1.0
@implement Shape Fam{P} where {P}
end
""",
"TB" => """
module TB
using TA
const first = TA.via(TA.Fam(1), 2)                  # Fam{Int}'s first use, while TB is precompiled
end
""")
deps = Dict("TA" => ["TraitWorld"], "TB" => ["TA"])
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
ok0, pre = run_probe("using TA, TB")
println("precompile TA, TB: ", ok0 ? "ok" : "FAILED\n" * pre)
probe = """
using TraitWorld, TA
key = (Fam{Int}, Shape)
kept() = any(i -> (l = ccall(:jl_activated_member_checks, Any, ()); l[i] === Fam{Int}), 1:2:length(ccall(:jl_activated_member_checks, Any, ())))
thrown(ex) = try Core.eval(Main, ex); "accepted" catch e; while e isa LoadError; e = e.error; end; string(nameof(typeof(e))) end
"""
ok1, out1 = run_probe(probe * """
using TB
println("runtime lists it: ", kept(), "; library before the sync: ", haskey(TraitWorld._CHECKED, key))
println("outside the declared result: ", thrown(:(TA.area(::Fam{Int}, k::Int) = 1)))
println("library after: ", get(TraitWorld._CHECKED, key, missing) === nothing, "; Fam{Float64} checked: ", haskey(TraitWorld._CHECKED, (Fam{Float64}, Shape)))
println("use: ", via(Fam(1), 2), " ", via(Fam(1.5), 2), "; Fam{Float64} checked: ", get(TraitWorld._CHECKED, (Fam{Float64}, Shape), missing) === nothing)
""")
ok2, out2 = run_probe(probe * """
println("control, runtime lists it: ", kept())
println("control, outside the declared result: ", thrown(:(TA.area(::Fam{Int}, k::Int) = 1)))
""")
print(out1); print(out2)
pass = ok0 && ok1 && ok2 &&
    occursin("runtime lists it: true; library before the sync: false", out1) &&
    occursin("outside the declared result: ImplementError", out1) &&
    occursin("library after: true; Fam{Float64} checked: false", out1) &&
    occursin("use: 1.0 1.0; Fam{Float64} checked: true", out1) &&
    occursin("control, runtime lists it: false", out2) &&
    occursin("control, outside the declared result: accepted", out2)
rm(root; recursive = true, force = true)
println(pass ? "kept_checks: OK" : "kept_checks: FAILED")
exit(pass ? 0 : 1)
