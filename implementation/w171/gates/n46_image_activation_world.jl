# Gate (compiler §4.11, §9, §4.8; E-543): an image's methods are activated with their questions about memberships
# asked in the world they begin in. Package loading runs in an older world (`_require_world_age`); a membership's
# method of a set member (`Y0 in X`, its method at `Type{<:Y0}`) meets the absence edge of `S0` only through
# `S0 in Y0`, an entry not in force in that world. So the code that folded `S0() isa X` to `false` before the image
# that declares `Y0 in X` was loaded must not keep it. Found by the set-folds report's image mode. A candidate for
# `gates/`; fails on `next` 2ddbe12394. Runs child processes on a fresh depot.
#     julia --project=experiments/implementation n46_image_activation_world.jl
const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)
pkg(name, body) = (mkpath(joinpath(PKGS, name, "src")); write(joinpath(PKGS, name, "src", "$name.jl"), body))
pkg("PkgA46", """
module PkgA46
using Traits
@trait X
@trait Y0
struct S0 end
Traits.declare_membership(S0, Y0, @__MODULE__)
q(x) = x isa X
end
""")
pkg("PkgB46", """
module PkgB46
using Traits, PkgA46
Traits.declare_membership(PkgA46.Y0, PkgA46.X, @__MODULE__)
end
""")
const IMPL = dirname(dirname(@__DIR__))
function child(code)
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = DEPOT * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([PKGS, IMPL, "@stdlib"], ":")
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(setenv(`$(Base.julia_cmd()) --startup-file=no -e $code`, env); stdout = out, stderr = err))
    return ok, String(take!(out)), String(take!(err))
end
for p in ("PkgA46", "PkgB46")
    local ok, out, err = child("using $p")
    @assert ok "precompiling $p: $err"
end
ok, out, err = child("""
    using PkgA46
    println("before ", PkgA46.q(PkgA46.S0()))
    using PkgB46
    println("after ", PkgA46.q(PkgA46.S0()), " fresh ", ccall(:jl_isa, Cint, (Any, Any), PkgA46.S0(), PkgA46.X) != 0)
""")
@assert ok "the session: $err"
@assert occursin("before false", out) "before the image: $out"
@assert occursin("after true fresh true", out) "the code compiled before the image's membership: $out"
rm(ROOT; recursive = true, force = true)
println("n46_image_activation_world: OK")
