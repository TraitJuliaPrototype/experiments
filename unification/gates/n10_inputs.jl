# Gate (C-32, T-103; compiler §4.6, traits §3.2): a member at several values of an input parameter.
# A set with an input `N` takes one membership per value of `N`; a second instance at a value
# already held is refused, and a set without inputs keeps one instance per member. Dispatch picks
# by the input. The inputs survive a package image: after loading, a conflicting declaration at a
# held name is still refused. Runs child processes on a fresh depot for the image.
include("util.jl")
using Traits

setinputs!(@nospecialize(T), m::UInt8) = ccall(:jl_set_input_params, Cvoid, (Any, UInt8), T, m)
refused(f) = try f(); false catch; true end

@trait HP{N, R}
setinputs!(HP, 0x01)
@trait HQ{N, R}                      # no inputs
struct S end
@implement HP{:a, Int} S
@implement HP{:b, String} S

# 1. both instances hold; a third at a held name is refused
@assert S <: HP{:a, Int} && S <: HP{:b, String}
@assert !(S <: HP{:a, String}) && !(S <: HP{:c})
@assert refused(() -> @eval(@implement HP{:a, Float64} S))
@assert S <: HP{:a, Int} && !(S <: HP{:a, Float64})
# a redeclaration of a held instance ends only that entry
@implement HP{:a, Int} S
@assert S <: HP{:a, Int} && S <: HP{:b, String}

# 2. dispatch by the input
kind(::HP{:a}) = :a
kind(::HP{:c}) = :c
@assert kind(S()) === :a

# 3. without inputs, one instance per member
@implement HQ{:a, Int} S
@assert refused(() -> @eval(@implement HQ{:b, String} S))
@assert S <: HQ{:a, Int} && !(S <: HQ{:b, String})

# 4. the mask: written once, within the parameters, only on a set
@assert refused(() -> setinputs!(HP, 0x02))
@assert refused(() -> setinputs!(HQ, 0x04))
@assert refused(() -> setinputs!(Int, 0x01))
setinputs!(HP, 0x01)                 # the same mask again is no change

# 5. an image round trip
const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)
function pkg(name, body)
    mkpath(joinpath(PKGS, name, "src"))
    write(joinpath(PKGS, name, "src", "$name.jl"), body)
end
pkg("PkgP", """
module PkgP
using Traits
@trait HP{N, R}
ccall(:jl_set_input_params, Cvoid, (Any, UInt8), HP, 0x01)
end
""")
pkg("PkgM", """
module PkgM
using Traits, PkgP
struct T end
@implement PkgP.HP{:a, Int} T
@implement PkgP.HP{:b, String} T
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
for p in ("PkgP", "PkgM")
    local ok, out, err = child("using $p")
    @assert ok "precompiling $p: $err"
end
let (ok, out, err) = child("""
    using Traits, PkgP, PkgM
    println("mask ", Base.unwrap_unionall(PkgP.HP).name.input_params)
    println("both ", PkgM.T <: PkgP.HP{:a, Int}, " ", PkgM.T <: PkgP.HP{:b, String})
    r = try @eval(@implement PkgP.HP{:a, Float64} PkgM.T); "accepted" catch; "refused" end
    println("held ", r)
    @eval @implement PkgP.HP{:c, Int} PkgM.T
    println("new ", PkgM.T <: PkgP.HP{:c, Int}, " ", PkgM.T <: PkgP.HP{:a, Int})
""")
    @assert ok "loading the images: $err"
    @assert occursin("mask 1", out) "the image keeps the inputs: $out"
    @assert occursin("both true true", out) "both instances after loading: $out"
    @assert occursin("held refused", out) "a held name stays refused after loading: $out"
    @assert occursin("new true true", out) "a new name after loading: $out"
end
rm(ROOT; recursive = true, force = true)
println("n10_inputs: OK")
