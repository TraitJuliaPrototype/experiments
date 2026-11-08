# Gate for compiler C-35 (§4.6, §9): one instance per member through package images. Two packages,
# each consistent alone, declare one concrete member at two instances of a set. Loaded together, the
# second image's membership is refused with a warning, in either load order: the member is in the set
# at the first instance only. Runs child processes on a fresh depot.
include("util.jl")

const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)
function pkg(name, body)
    mkpath(joinpath(PKGS, name, "src"))
    write(joinpath(PKGS, name, "src", "$name.jl"), body)
end
pkg("BoxA", """
module BoxA
using Traits
@trait Box{T}
end
""")
pkg("BoxB", """
module BoxB
using Traits, BoxA
@implement BoxA.Box{Int} Vector{UInt8}
end
""")
pkg("BoxC", """
module BoxC
using Traits, BoxA
@implement BoxA.Box{String} Vector{UInt8}
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

for p in ("BoxA", "BoxB", "BoxC")
    local ok, out, err = child("using $p")
    @assert ok "precompiling $p: $err"
end
for (first_, second, kept, refused) in (("BoxB", "BoxC", "Int", "String"), ("BoxC", "BoxB", "String", "Int"))
    local ok, out, err = child("""
        using $first_; using $second
        using BoxA
        println("kept ", UInt8[1] isa BoxA.Box{$kept}, " refused ", UInt8[1] isa BoxA.Box{$refused})
    """)
    @assert ok "loading $first_ then $second: $err"
    @assert occursin("kept true refused false", out) "one instance, the first image's ($first_, $second): $out"
    @assert occursin("is refused", err) "the refusal is said ($first_, $second): $err"
end
println("n12_image_instances: OK")
