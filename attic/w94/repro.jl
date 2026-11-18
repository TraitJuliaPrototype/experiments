# W-94 (open issue 126), the minimal case: package FamT declares a trait `Col` with a family implementation
# over `AbstractVector`; its workload compiles trait code that folds the member `Vector{Int}` (a FoldRecord
# edge in its image). Package SubT declares a subtrait `SubCol <: Col` and implements it for every `Vector`.
# A fresh session loads FamT, then SubT, with the compiler's validation log on, and reports, for FamT's
# image code: the log's entries by edge kind, whether each logged CodeInstance is valid after the loads
# (max_world typemax), the `verify_methods` entries (code rejected), and whether the first call compiles
# FamT's trait code again. Toy packages in a temporary directory, their images in a depot of their own.
#     julia --project=<TraitWorld> repro.jl
pkgs = mktempdir(); depot = mktempdir()
function pkg(name, src)
    mkpath(joinpath(pkgs, name, "src"))
    write(joinpath(pkgs, name, "src", name * ".jl"), src)
end
pkg("FamT", """
    module FamT
    using TraitWorld
    @trait_module begin
    export Col, nrows, cell, total
    @trait Col{T} begin
        T = eltype(Self)
        nrows(c::Col)::Int
        cell(c::Col{T}, i::Int)::T
    end
    @implement Col A where {A <: AbstractVector} begin
        nrows(c) = length(c)
        cell(c, i) = @inbounds c[firstindex(c) + i - 1]
    end
    total(c::Col) = (s = 0; for i in 1:nrows(c); s += cell(c, i); end; s)
    end
    use(v::Vector{Int}) = total(v)
    precompile(use, (Vector{Int},))
    use([1, 2, 3])
    end
    """)
pkg("SubT", """
    module SubT
    using TraitWorld, FamT
    @trait_module begin
    @trait SubCol{T} <: FamT.Col begin
        T = eltype(Self)
        bump!(c::SubCol, i::Int)::Nothing
    end
    @implement SubCol A where {A <: Vector} begin
        bump!(c, i) = (c[i] += one(eltype(c)); nothing)
    end
    bumpall!(c::SubCol) = (for i in 1:FamT.nrows(c); bump!(c, i); end; nothing)
    end
    work(v::Vector{Int}) = (bumpall!(v); v)
    precompile(work, (Vector{Int},))
    work([1, 2])
    end
    """)
tw = dirname(Base.active_project())
env = copy(ENV)
env["JULIA_LOAD_PATH"] = join([pkgs, tw, "@stdlib"], ":")
env["JULIA_DEPOT_PATH"] = join([depot, Base.DEPOT_PATH...], ":")
env["JULIA_PKG_OFFLINE"] = "true"
env["JULIA_TW_LOADREPORT"] = "1"
delete!(env, "JULIA_PROJECT")
# (`success`, not `run`: a failure must not print the environment)
success(pipeline(setenv(`$(Base.julia_cmd()) --startup-file=no -e "using FamT, SubT"`, env); stdout, stderr)) || error("building the images failed")   # both images
session = "include(\"$(joinpath(@__DIR__, "patch_verify.jl"))\")\n" * raw"""
R = Base.Compiler.ReinferUtils; const CC = Base.Compiler
R.debug_method_invalidation(true)
using FamT
nfam = length(R._jl_debug_method_invalidation[])
using SubT
log = R._jl_debug_method_invalidation[]; R.debug_method_invalidation(false)
using TraitWorld; const TW = TraitWorld
kind(e) = e isa CC.FoldRecord ? "FoldRecord" : e isa Core.Binding ? "Binding" : e isa Core.MethodInstance ? "MethodInstance" : e isa Type ? "signature" : string(typeof(e))
for (what, r) in (("FamT's load", 1:nfam), ("SubT's load", nfam+1:length(log)))
    st = Dict{String,Vector{Int}}(); nver = 0
    for i in r
        log[i] == "verify_methods" && (nver += 1)
        log[i] == "insert_backedges_callee" || continue
        e = log[i-1]; ci = log[i+1]
        s = get!(st, kind(e), [0, 0, 0]); s[1] += 1
        ci.max_world == typemax(UInt) ? (s[2] += 1) : (s[3] += 1)
        e isa CC.FoldRecord && println("  fold ", e.args[2:end], " in ", CC.get_ci_mi(ci), ": holds ", CC.fold_holds(e, Base.get_world_counter()))
    end
    println(what, ": 'insert_backedges_callee' by edge kind [logged, valid after the loads, invalid]: ", st, "; 'verify_methods' (rejected) ", nver)
end
# the fold's CodeInstance of FamT's image: still the one in the cache, nothing compiled for it again
mi = Base.method_instance(TW.conformance, (TW.As{FamT.Col}, Vector{Int}))
cis(mi) = (c = isdefined(mi, :cache) ? mi.cache : nothing; out = Any[]; while c !== nothing; push!(out, c); c = isdefined(c, :next) ? c.next : nothing; end; out)
before = cis(mi)
println("conformance(As{Col}, Vector{Int}): CodeInstances ", length(before), ", valid ", count(c -> c.max_world == typemax(UInt), before),
        ", in an image ", count(c -> ccall(:jl_object_in_image, UInt8, (Any,), c) != 0, before))
println("use: ", FamT.use([1, 2, 3]), "; work: ", SubT.work([1, 2]))
after = cis(mi)
println("after the calls: CodeInstances ", length(after), " (new ", length(after) - length(before), ")")
r(k) = (v = get(TW._LR_PARTS, (:member_at_load, k), nothing); v === nothing ? 0 : Int(v[1]))
println("member_at_load: from_record ", r(:from_record), ", already_fixed ", r(:already_fixed), ", checked again ", r(:check))
"""
success(pipeline(setenv(`$(Base.julia_cmd()) --startup-file=no -e $session`, env); stdout, stderr)) || error("the session failed")
