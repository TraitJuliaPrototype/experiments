# Gate (W-129, W-140; compiler §4.8, §5.5; traits §3.4; facts §2.2, §10): a non-membership is relied on,
# at every set, with the option `jl_set_closed_after_load` or without (`P.Y`), before the pair's declarers
# have finished loading and after, and for a type of Main. `isa` folds and the code records the pair's
# final cell; a call selects its method with no guard and no cell. A membership declared later opens
# the cell and invalidates the code that folded, and invalidates the caller whose selection it changes,
# as a method's insertion does; a task in an older world keeps the old answer. In package images: the
# code an image compiled with a negative is kept at load, and invalidated by a later membership; an
# image loaded after the membership is not kept. Runs child processes on a fresh depot.
using Traits
include("util.jl")

latest(f, T) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                               c.def.specTypes === Tuple{typeof(f), T}])
guards(ci) = Any[]                 # no guard exists (W-140)
finals(ci) = absences(ci)          # the negatives relied on: edges at Core.implements (W-141)
loaded(m) = ccall(:jl_module_is_loaded, Cint, (Any,), m) != 0

# (0) the system image's modules have loaded; Main never has
@assert loaded(Core) && loaded(Base) && !loaded(Main) "loaded: Core $(loaded(Core)), Base $(loaded(Base)), Main $(loaded(Main))"

module P
using Traits
@trait X                           # closed after load, below
@trait Y                           # open
struct S end                       # joins X late
struct S2 end                      # joins Y late
f(x) = :any
f(x::X) = :set
g(x) = :any
g(y::Y) = :set
end
ccall(:jl_set_closed_after_load, Cvoid, (Any,), P.X)
@assert ccall(:jl_is_closed_after_load, Cint, (Any,), P.X) == 1 && ccall(:jl_is_closed_after_load, Cint, (Any,), P.Y) == 1

# (1) before P has finished loading the negative is relied on too: no guard; a folded isa has its cell
callf0(s::P.S) = P.f(s)
isx0(s::P.S) = s isa P.X
@assert callf0(P.S()) === :any && isx0(P.S()) === false
ci0 = latest(callf0, P.S)
@assert isempty(guards(ci0)) && isempty(finals(ci0)) "no cell at a call before the load: $(ci0.edges)"
@assert length(finals(latest(isx0, P.S))) == 1 "the folded isa's cell before the load"
@assert !loaded(P)

# (2) once P has loaded: the same
ccall(:jl_module_set_loaded, Cvoid, (Any,), P)
@assert loaded(P)
callf(s::P.S) = P.f(s)
isx(s::P.S) = s isa P.X
@assert callf(P.S()) === :any && isx(P.S()) === false
ci = latest(callf, P.S)
@assert isempty(guards(ci)) && isempty(finals(ci)) "no guard, no cell at a call: $(ci.edges)"
cix = latest(isx, P.S)
cell = only(finals(cix))
@assert absence_member(cell) === P.S && absence_set(cell) === P.X
folded_false(c) = isdefined(c, :rettype_const) && (c.rettype_const === false ||
    (c.rettype_const isa Core.InterConditional && c.rettype_const.thentype === Union{}))
@assert folded_false(cix) "isa folded to false: $(cix.rettype)"
@assert length(finals(cix)) == 1 "the folded isa records the final cell: $(cix.edges)"
@assert absence_kept(cell, cix) "the method table keeps the dependent"

# a set declared without the option: the same
callg(s::P.S2) = P.g(s)
@assert callg(P.S2()) === :any
cig = latest(callg, P.S2)
@assert isempty(guards(cig)) && isempty(finals(cig))

# a type of Main is relied on too (W-140, stage 2), and a type with a parameter of Main
struct M end
callm(m::M) = P.f(m)
callv(v::Vector{M}) = P.f(v)
@assert callm(M()) === :any && callv(M[]) === :any
@assert isempty(guards(latest(callm, M))) && isempty(guards(latest(callv, Vector{M})))
ism(m::M) = m isa P.X
@assert ism(M()) === false && length(finals(latest(ism, M))) == 1 "a type of Main is settled"

# (3) a late membership opens the final cell and invalidates its dependents, and the caller
w_before = curworld()
e = @implement P.X P.S
@assert !isempty(methods(Core.implements, Tuple{Type{P.X}, Type{P.S}})) "the membership has its method"
@assert ci.max_world == e.min_world - 1 && cix.max_world == e.min_world - 1 "its dependents invalidated"
@assert callf(P.S()) === :set && isx(P.S()) === true
@assert Base.invoke_in_world(w_before, callf, P.S()) === :any "an older world keeps the old answer"
@assert Base.invoke_in_world(w_before, isx, P.S()) === false

# the same for the set declared without the option: its late membership invalidates the code that
# relied on its absence, as a method definition does
e2 = @implement P.Y P.S2
@assert cig.max_world == e2.min_world - 1 && callg(P.S2()) === :set

# (4) package images
const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)
function pkg(name, body)
    mkpath(joinpath(PKGS, name, "src"))
    write(joinpath(PKGS, name, "src", "$name.jl"), body)
end
pkg("PkgX", """
module PkgX
using Traits
@trait X
ccall(:jl_set_closed_after_load, Cvoid, (Any,), X)
struct S end
f(x) = :any
f(x::X) = :set
end
""")
pkg("PkgY", """
module PkgY
using PkgX
h(s::PkgX.S) = PkgX.f(s)
isx(s::PkgX.S) = s isa PkgX.X
precompile(h, (PkgX.S,)); precompile(isx, (PkgX.S,))
end
""")
pkg("PkgZ", """
module PkgZ
using Traits, PkgX
@implement PkgX.X PkgX.S
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
for p in ("PkgX", "PkgY", "PkgZ")
    local ok, out, err = child("using $p")
    @assert ok "precompiling $p: $err"
end
probe = """
    function finals(ci)
        es = ci.edges; out = Any[]
        for i in 1:length(es)-1
            s = es[i]
            (es[i+1] === Core.methodtable && s isa Type) || continue
            u = Base.unwrap_unionall(s)
            u isa DataType && u <: Tuple && length(u.parameters) == 3 && u.parameters[1] === typeof(Core.implements) && push!(out, s)
        end
        return out
    end
    function kept(sig, ci)
        be = Core.methodtable.backedges
        for k in 2:2:length(be)
            isassigned(be, k) || continue
            v = be[k]
            v isa Vector || continue
            for i in 1:2:length(v)-1
                v[i+1] === ci && v[i] == sig && return true
            end
        end
        return false
    end
    function imgci(f)
        mi = only(Base.specializations(only(methods(f))))
        ci = mi.cache
        return ci
    end
"""
# PkgY's image code: kept at load; a late membership invalidates it
let (ok, out, err) = child(probe * """
    using PkgX, PkgY
    println("loaded ", ccall(:jl_module_is_loaded, Cint, (Any,), PkgX))
    ci = imgci(PkgY.h); cix = imgci(PkgY.isx)
    println("image ", ci.max_world == typemax(UInt), " ", cix.max_world == typemax(UInt), " ", length(finals(cix)), " ", PkgY.h(PkgX.S()), " ", PkgY.isx(PkgX.S()))
    println("kept ", imgci(PkgY.h) === ci, " ", kept(only(finals(cix)), cix))
    using PkgZ
    println("late ", ci.max_world < typemax(UInt), " ", cix.max_world < typemax(UInt), " ", PkgY.h(PkgX.S()), " ", PkgY.isx(PkgX.S()))
""")
    @assert ok "image, then a late membership: $err"
    @assert occursin("loaded 1", out) "PkgX loaded: $out"
    @assert occursin("image true true 1 any false", out) "PkgY's image code, the folded isa with its final cell: $out"
    @assert occursin("kept true true", out) "the image code kept, the cell's dependent: $out"
    @assert occursin("late true true set true", out) "a late membership invalidates the image code: $out"
end
# PkgZ's membership loaded first: PkgY's image code is not kept
let (ok, out, err) = child(probe * """
    using PkgX, PkgZ, PkgY
    println("after ", PkgY.h(PkgX.S()), " ", PkgY.isx(PkgX.S()))
""")
    @assert ok "the membership first: $err"
    @assert occursin("after set true", out) "an image loaded after the membership: $out"
end

rm(ROOT; recursive = true, force = true)
println("n18_closed_after_load: OK")
