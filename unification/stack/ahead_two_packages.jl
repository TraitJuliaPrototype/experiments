# Gate (W-114; traits §16; lowering §12): compiling ahead in a two-package session. Package TA declares
# a trait and methods at it; package TB declares a type and its membership. While TB is precompiled,
# the code TB's type needs is compiled into TB's image: in a fresh session that loads TB, calling the
# methods compiles nothing. With JULIA_TW_AHEAD=0 the same calls compile.
# Usage: julia ahead_two_packages.jl <TraitWorld-unified path>
tw = abspath(ARGS[1])
root = mktempdir()
depot = joinpath(root, "depot")
mkpath(joinpath(root, "TA", "src")); mkpath(joinpath(root, "TB", "src"))
uuid_tw = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
write(joinpath(root, "TA", "Project.toml"), """
name = "TA"
uuid = "a1a1a1a1-0000-4000-8000-00000000000a"
[deps]
TraitWorld = "$uuid_tw"
""")
write(joinpath(root, "TA", "src", "TA.jl"), """
module TA
using TraitWorld
@trait_module
export Shape, area, total, scaled
@trait Shape begin
    area(s::Shape)::Float64
end
total(s::Shape, n::Int) = n * area(s)              # fully bounded, one trait argument
scaled(s::Shape, k::Float64) = k * area(s)
end
""")
write(joinpath(root, "TB", "Project.toml"), """
name = "TB"
uuid = "b2b2b2b2-0000-4000-8000-00000000000b"
[deps]
TA = "a1a1a1a1-0000-4000-8000-00000000000a"
TraitWorld = "$uuid_tw"
""")
write(joinpath(root, "TB", "src", "TB.jl"), """
module TB
using TraitWorld, TA
export Square
struct Square; side::Float64; end
TA.area(s::Square) = s.side^2
@implement Shape Square
end
""")
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
write(joinpath(env, "Project.toml"), """
[deps]
TA = "a1a1a1a1-0000-4000-8000-00000000000a"
TB = "b2b2b2b2-0000-4000-8000-00000000000b"
TraitWorld = "$uuid_tw"
""")
write(joinpath(env, "Manifest.toml"), """
julia_version = "$(VERSION)"
manifest_format = "2.0"
[[deps.TA]]
deps = ["TraitWorld"]
path = "$(joinpath(root, "TA"))"
uuid = "a1a1a1a1-0000-4000-8000-00000000000a"
version = "0.0.0"
[[deps.TB]]
deps = ["TA", "TraitWorld"]
path = "$(joinpath(root, "TB"))"
uuid = "b2b2b2b2-0000-4000-8000-00000000000b"
version = "0.0.0"
[[deps.TraitWorld]]
$(depsline(twdeps))path = "$tw"
uuid = "$uuid_tw"
version = "0.2.0"
$stdentries""")
julia = Base.julia_cmd()
probe = """
using TraitWorld, TA, TB

has(f, T) = any(mi -> mi.specTypes == T && isdefined(mi, :cache), Base.specializations(only(methods(f))))
println("ahead: ", has(TA.total, Tuple{typeof(TA.total), TB.Square, Int}), " ",
        has(TA.scaled, Tuple{typeof(TA.scaled), TB.Square, Float64}))
for f in (TA.total, TA.scaled, TA.area), m in methods(f), mi in Base.specializations(m)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    println("spec: ", mi.specTypes, " cache: ", ci === nothing ? "-" : "flags=\$(ci.flags) max=\$(ci.max_world)")
end
println("set methods: ", length(TraitWorld.set_methods(TA.Shape)), " requests: ", TraitWorld.ahead_requests(TA.Shape, TB.Square))
println("calls: ", TA.total(TB.Square(2.0), 3), " ", TA.scaled(TB.Square(1.0), 2.0))
"""
function run_probe(ahead::String)
    d = joinpath(root, "depot-" * ahead)
    cmd = addenv(`$julia --startup-file=no --project=$env -e $probe`,
                 "JULIA_DEPOT_PATH" => d * ":", "JULIA_TW_AHEAD" => ahead)
    out = IOBuffer()
    p = run(pipeline(ignorestatus(cmd), stdout = out, stderr = out))
    s = String(take!(out))
    success(p) || println("probe (JULIA_TW_AHEAD=$ahead) failed:\n", s)
    return s
end
on = run_probe("1")
off = run_probe("0")
println("with compiling ahead:    ", replace(on, "\n" => " | "))
println("without compiling ahead: ", replace(off, "\n" => " | "))
@assert occursin("ahead: true true", on) "TB's image holds the methods at Square"
@assert occursin("ahead: false false", off) "JULIA_TW_AHEAD=0 compiles nothing ahead"
@assert occursin("calls: 12.0 2.0", on) && occursin("calls: 12.0 2.0", off)
println("ahead_two_packages: OK")
