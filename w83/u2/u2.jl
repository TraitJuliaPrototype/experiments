# E-257 (U2): do the kept forms collapse without a cost?
# A `Vector{Any}` holding raw members and `Dynamic{S}` wrappers, read by a loop that branches on
# `isa Dynamic` and then runs the split, against the `Vector{Kept{S}}` loop and E-164's
# `Vector{Dynamic{S}}` copy, with the same shapes, traits and measurement as E-164's hi2
# (`../../hetero-idiomatic/shapes_defs.jl`, `common.jl`: median time per element over BenchmarkTools'
# samples, median allocation per element). 1000 elements cycling n = 2, 4, 8 types.
#
#     ../../tools/jl --exclusive ../../../julia-1.13/julia --startup-file=no --project=. u2.jl     (and -J …/facts/sys.so for `all`)
include("../../hetero-idiomatic/common.jl")
using TraitWorld
header("u2 (E-257)")
include("../../hetero-idiomatic/shapes_defs.jl")

# The loops, in a trait module (compiled by facts in both settings), written as the lowering would
# write them: an operation on a held value is `Compiler.split_call` over the held object (trait.jl);
# under the collapse, a raw member read from the container is split directly, a wrapper as today.
@trait_module module U2Core
using TraitWorld
using ..ShapeCore: S2, S4, S8, area2, area4, area8
const TW = TraitWorld
export kloop, dloop, cloop, cloopw
# The split over a raw member of unknown type: the operation's split, called with the object itself.
# Written out at the call (a macro), as the lowering writes it: in code compiled by facts a function
# taking the `Any`-typed object would be a run-time site (as TraitWorld's `@dynamic_of` notes).
macro splitraw(S, op, x)
    esc(:(TraitWorld.CC.split_call(TraitWorld._family_of($S), Float64, TraitWorld._dynop($S, $op), $x)::Float64))
end
"`Vector{Kept{S}}`: each item an inline (object, attribute) pair; the operation is the split on the object."
kloop(::Type{S}, op::F, v::Vector{Kept{S}}) where {S,F} = (s = 0.0; for k in v; s += op(k); end; s)
"`Vector{Dynamic{S}}`: E-164's copy."
dloop(::Type{S}, op::F, v::Vector{Dynamic{S}}) where {S,F} = (s = 0.0; for d in v; s += op(d); end; s)
"The collapse: `Vector{Any}` of raw members and wrappers; `isa Dynamic`, then the split."
function cloop(::Type{S}, op::F, v::Vector{Any}) where {S,F}
    s = 0.0
    for x in v
        s += x isa Dynamic{S} ? op(x) : @splitraw(S, op, x)
    end
    return s
end
"The same, a raw member wrapped on read by `@dynamic_of` (what `DynamicItems` does), then the operation."
function cloopw(::Type{S}, op::F, v::Vector{Any}) where {S,F}
    s = 0.0
    for x in v
        s += x isa Dynamic{S} ? op(x) : op(TraitWorld.@dynamic_of S x)
    end
    return s
end
end
using .U2Core

const N = 1000
const TYPES = [getfield(Main, Symbol(:P, i)) for i in 1:64]
# item i: type mod1(i, n); wrapped for every second run of n, so each type is half raw, half wrapped
wrapped(i, n) = isodd((i - 1) ÷ n)
if get(ENV, "U2_TYPED", "0") == "1"
    v = Any[P1(1.0), Dynamic{ShapeCore.S4}(P2(1.0))]
    for (f, a) in ((cloop, v), (cloopw, v))
        src, rt = only(code_typed(f, (Type{ShapeCore.S4}, typeof(ShapeCore.area4), Vector{Any}); interp = Base.Compiler.NativeInterpreter(; owner = Base.Compiler.FACTS_OWNER)))
        println("---- ", f, " => ", rt); foreach(((i, st),) -> println("  ", i, "  ", first(sprint(show, st), 200), "  ::", src.ssavaluetypes[i]), enumerate(src.code))
    end
    exit()
end
for (n, S, op, tot) in ((2, ShapeCore.S2, ShapeCore.area2, ShapeCore.total2),
                        (4, ShapeCore.S4, ShapeCore.area4, ShapeCore.total4),
                        (8, ShapeCore.S8, ShapeCore.area8, ShapeCore.total8))
    objs = [TYPES[mod1(i, n)](1.0) for i in 1:N]
    # the collapse: Vector{Any}, mixed / all raw / all wrapped
    amix = Any[wrapped(i, n) ? Dynamic{S}(objs[i]) : objs[i] for i in 1:N]
    araw = Any[objs...]
    adyn = Any[Dynamic{S}(o) for o in objs]
    # today: Vector{Kept{S}} with the same attributes (raw -> Compiled, wrapped -> Dynamic)
    kmix = Kept{S}[wrapped(i, n) ? Kept{S}(Dynamic{S}(objs[i])) : Kept{S}(objs[i]) for i in 1:N]
    kraw = Kept{S}[Kept{S}(o) for o in objs]
    kdyn = Kept{S}[Kept{S}(Dynamic{S}(o)) for o in objs]
    # E-164's copy
    dv = Dynamic{S}[Dynamic{S}(o) for o in objs]
    @assert count(k -> !getfield(k, :compiled), kmix) == count(x -> x isa Dynamic, amix) == count(i -> wrapped(i, n), 1:N)
    r = dloop(S, op, dv)
    @assert r == kloop(S, op, kmix) == cloop(S, op, amix) == cloopw(S, op, amix) == cloop(S, op, araw) == cloop(S, op, adyn) == tot(dv)
    println("-- n = $n implementations")
    @row "Σ area$n over Vector{Dynamic{S$n}} (dloop)" "dynamic" N dloop($S, $op, $dv)
    @row "Σ area$n over Vector{Dynamic{S$n}}: total$n, E-164's copy row" "dynamic" N $tot($dv)
    @row "Σ area$n over Vector{Kept{S$n}}, half Compiled half Dynamic" "kept" N kloop($S, $op, $kmix)
    @row "Σ area$n over Vector{Kept{S$n}}, all Compiled" "kept" N kloop($S, $op, $kraw)
    @row "Σ area$n over Vector{Kept{S$n}}, all Dynamic" "kept" N kloop($S, $op, $kdyn)
    @row "Σ area$n over Vector{Any}, half raw half Dynamic: isa, split" "collapse" N cloop($S, $op, $amix)
    @row "Σ area$n over Vector{Any}, all raw: isa, split" "collapse" N cloop($S, $op, $araw)
    @row "Σ area$n over Vector{Any}, all Dynamic: isa, split" "collapse" N cloop($S, $op, $adyn)
    @row "Σ area$n over Vector{Any}, half/half: isa, @dynamic_of" "collapse" N cloopw($S, $op, $amix)
    # today's spelling of the mixed Vector{Any}: the bound crosses it into DynamicItems
    try
        tot(amix) == r || println("   (total$n over the mixed Vector{Any} gives another sum)")
        @row "Σ area$n: total$n(amix), the mixed Vector{Any} crossing" "today" N $tot($amix)
    catch e
        println("   total$n(amix) refused: ", sprint(showerror, e)[1:min(end, 200)])
    end
    try
        tot(kmix) == r || println("   (total$n over Vector{Kept} gives another sum)")
        @row "Σ area$n: total$n(kmix), Vector{Kept{S$n}} at the bound" "today" N $tot($kmix)
    catch e
        println("   total$n(kmix) refused: ", sprint(showerror, e)[1:min(end, 200)])
    end
end
println("== done  load ", join(loadavg(), " "))
