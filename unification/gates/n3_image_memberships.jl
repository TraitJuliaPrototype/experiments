# Gate (W-108; compiler §9): memberships in package images. A package's memberships, on its own
# types and on other modules' types, hold after its image is loaded, in either load order of two
# packages that declare them independently. An image built without a membership still dispatches
# by it once the membership is loaded: the image's code is validated after the memberships are
# activated. Runs child processes on a fresh depot.
include("util.jl")

const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)

function pkg(name, body)
    mkpath(joinpath(PKGS, name, "src"))
    write(joinpath(PKGS, name, "src", "$name.jl"), body)
end

pkg("PkgA", """
module PkgA
using Traits
@trait Shape
describe(s::Shape) = "shape"
describe(x) = "other"
end
""")
pkg("PkgB", """
module PkgB
using Traits, PkgA
struct Sq end
@implement PkgA.Shape Sq                  # on its own type
@implement PkgA.Shape Vector{Int}         # on Core's type
end
""")
pkg("PkgC", """
module PkgC
using Traits, PkgA
struct Circ end
@implement PkgA.Shape Circ
@implement PkgA.Shape Vector{Float64}
end
""")
pkg("PkgD", """
module PkgD
using PkgA
f(v::Vector{Int}) = PkgA.describe(v)     # compiled without PkgB's membership
precompile(f, (Vector{Int},))
@assert f([1]) == "other"
end
""")

const UNIF = dirname(@__DIR__)
const JULIA = Base.julia_cmd()

function child(code)
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = DEPOT * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([PKGS, UNIF, "@stdlib"], ":")
    cmd = setenv(`$JULIA --startup-file=no -e $code`, env)
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(cmd; stdout = out, stderr = err))
    return ok, String(take!(out)), String(take!(err))
end

# 1. precompile all four, each in a session of its own, then load B, C in both orders
for p in ("PkgA", "PkgB", "PkgC", "PkgD")
    local ok, out, err = child("using $p")
    @assert ok "precompiling $p: $err"
end
check = """
    using PkgA
    println("B ", PkgB.Sq() isa PkgA.Shape, " ", [1] isa PkgA.Shape, " ", PkgA.describe([1]), " ", PkgA.describe(PkgB.Sq()))
    println("C ", PkgC.Circ() isa PkgA.Shape, " ", [1.0] isa PkgA.Shape, " ", PkgA.describe([1.0]))
    println("N ", Int8[1] isa PkgA.Shape)
"""
for order in (("PkgB", "PkgC"), ("PkgC", "PkgB"))
    local ok, out, err = child("using $(order[1]); using $(order[2]); " * check)
    @assert ok "loading $(order): $err"
    @assert occursin("B true true shape shape", out) "B's memberships after loading $(order): $out"
    @assert occursin("C true true shape", out) "C's memberships after loading $(order): $out"
    @assert occursin("N false", out) "no other member: $out"
end

# 2. a call made before the membership is loaded, and after (the caches lowered at activation)
let (ok, out, err) = child("""
    using PkgA
    println("before ", PkgA.describe([1]))
    using PkgB
    println("after ", PkgA.describe([1]))
""")
    @assert ok "load in two steps: $err"
    @assert occursin("before other", out) && occursin("after shape", out) "dispatch follows the loaded membership: $out"
end

# 3. an image built without the membership: D's code is validated after B's memberships are active
for order in (("PkgB", "PkgD"), ("PkgD", "PkgB"))
    local ok, out, err = child("using $(order[1]); using $(order[2]); println(\"D \", PkgD.f([1]))")
    @assert ok "loading $(order): $err"
    @assert occursin("D shape", out) "PkgD's image dispatches by the membership loaded with it, $(order): $out"
end

rm(ROOT; recursive = true, force = true)
println("n3_image_memberships: OK")
