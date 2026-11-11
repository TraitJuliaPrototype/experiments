# Gate (W-129, W-140 stage 1; compiler §4.8; traits §3.4; facts §2.2, §10): every set is closed after
# load, with the option `jl_set_closed_after_load` or without (`P.Y`). Once a pair's
# declarers have finished loading (the set's module and the type's), its negative is final: a call
# that a membership could change carries no guard, `isa` folds, and the code records the pair's final
# cell. A membership declared later opens the cell and invalidates that code; a task in an older world
# keeps the old answer. A type of Main is never settled. In package
# images: the code an image compiled with a final negative is kept at load, and invalidated by a later
# membership; an image loaded after the membership is not kept. Runs child processes on a fresh depot.
using Traits
include("util.jl")

latest(f, T) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                               c.def.specTypes === Tuple{typeof(f), T}])
guards(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal == 0x00]
finals(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal != 0x00]
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

# (1) before P has finished loading: the negative is not final, the call is guarded
callf0(s::P.S) = P.f(s)
@assert callf0(P.S()) === :any
ci0 = latest(callf0, P.S)
@assert length(guards(ci0)) == 1 && isempty(finals(ci0)) "guarded before the load: $(ci0.edges)"
@assert !loaded(P)

# (2) once P has loaded: no guard, a final cell; `isa` folds
ccall(:jl_module_set_loaded, Cvoid, (Any,), P)
@assert loaded(P)
callf(s::P.S) = P.f(s)
isx(s::P.S) = s isa P.X
@assert callf(P.S()) === :any && isx(P.S()) === false
ci = latest(callf, P.S)
@assert isempty(guards(ci)) && length(finals(ci)) == 1 "a final cell, no guard: $(ci.edges)"
cell = only(finals(ci))
@assert cell.member === P.S && cell.min_world == typemax(UInt)
cix = latest(isx, P.S)
folded_false(c) = isdefined(c, :rettype_const) && (c.rettype_const === false ||
    (c.rettype_const isa Core.InterConditional && c.rettype_const.thentype === Union{}))
@assert folded_false(cix) "isa folded to false: $(cix.rettype)"
@assert length(finals(cix)) == 1 "the folded isa records the final cell: $(cix.edges)"
@assert any(b -> b === ci, cell.backedges) && any(b -> b === cix, cell.backedges) "the cell keeps its dependents"

# a set declared without the option is closed after load too: a final cell, no guard
callg(s::P.S2) = P.g(s)
@assert callg(P.S2()) === :any
cig = latest(callg, P.S2)
@assert isempty(guards(cig)) && length(finals(cig)) == 1

# a type of Main is never settled; nor a type with a parameter of Main
struct M end
callm(m::M) = P.f(m)
callv(v::Vector{M}) = P.f(v)
@assert callm(M()) === :any && callv(M[]) === :any
@assert length(guards(latest(callm, M))) == 1 && isempty(finals(latest(callm, M)))
@assert length(guards(latest(callv, Vector{M}))) == 1 && isempty(finals(latest(callv, Vector{M})))

# (3) a late membership opens the final cell and invalidates its dependents
w_before = curworld()
e = @implement P.X P.S
@assert cell.min_world == e.min_world "the final cell opened at the entry's world"
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
    finals(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal != 0x00]
    function imgci(f)
        mi = only(Base.specializations(only(methods(f))))
        ci = mi.cache
        return ci
    end
"""
# PkgY's image code: kept at load, no guard, a final cell; a late membership invalidates it
let (ok, out, err) = child(probe * """
    using PkgX, PkgY
    println("loaded ", ccall(:jl_module_is_loaded, Cint, (Any,), PkgX))
    ci = imgci(PkgY.h)
    println("image ", ci.max_world == typemax(UInt), " ", length(finals(ci)), " ", PkgY.h(PkgX.S()), " ", PkgY.isx(PkgX.S()))
    println("kept ", imgci(PkgY.h) === ci, " ", any(b -> b === ci, only(finals(ci)).backedges))
    using PkgZ
    println("late ", ci.max_world < typemax(UInt), " ", PkgY.h(PkgX.S()), " ", PkgY.isx(PkgX.S()))
""")
    @assert ok "image, then a late membership: $err"
    @assert occursin("loaded 1", out) "PkgX loaded: $out"
    @assert occursin("image true 1 any false", out) "PkgY's image code with its final cell: $out"
    @assert occursin("kept true true", out) "the image code kept, the cell's dependent: $out"
    @assert occursin("late true set true", out) "a late membership invalidates the image code: $out"
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
