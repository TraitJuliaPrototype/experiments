# Acceptance checks for "wrapping by facts" (writeup/explorations/wrapping-by-facts.md), ported to
# the facts mode in Julia's compiler (parts B and C, session 29): code compiled "under the policy"
# is code reached from a module compiled by facts (`FactsCall.call`), and the policy's CodeInstance
# is the compiler's `:facts` one. The original, for TraitWorld's own policy: acceptance.jl.
# Each check prints PASS/FAIL with what it saw. Run in a fresh session:
#   julia --project=<env with TraitWorld> acceptance.jl
# G1: the trait world computes what plain Julia computes (or raises), under redefinitions, late
#     methods by owners, winning pirates, and calls into code written without traits.
# G2: unrelated loads invalidate no trait-world code (G2.1 here; across package loads: g2all.jl).
using TraitWorld, Test

results = Tuple{String,Bool,String}[]
check(name, ok, detail = "") = (push!(results, (name, ok, detail)); println(ok ? "PASS  " : "FAIL  ", name, isempty(detail) ? "" : "  ($detail)"))
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)

# a call compiled by facts: the callee and everything it calls, under the owner `:facts`
toplevel(quote
    module FactsCall
    Base.Experimental.@compiler_options facts=true
    call(f::F, args::Vararg{Any,N}) where {F,N} = f(args...)
    "The `:facts` CodeInstance for `sig`, compiled now (the compiler's request for that owner)."
    function ci(@nospecialize(sig))
        w = Base.get_world_counter()
        mi = ccall(:jl_method_lookup_by_tt, Any, (Any, Csize_t, Any), sig, w, nothing)
        return Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, :facts)
    end
    end
end)

toplevel(quote
    @trait_module module AccLib
    using TraitWorld
    using LinearAlgebra: lu, det          # a standard library
    using Printf: @sprintf
    export Tab, nc, colv, cmean, cdet, cfmt, Rec, rlen, rtotal, Num, nval, nsum
    @trait Tab begin
        nc(t::Tab)::Int
        colv(t::Tab, i::Int)::Vector{Float64}
    end
    @implement Tab Vector{Vector{Float64}} begin
        nc(t) = length(t)
        colv(t, i) = t[i]
    end
    cmean(t::Tab, i::Int) = (c = colv(t, i); sum(c) / length(c))
    cdet(t::Tab) = det(reduce(hcat, [colv(t, i) for i in 1:nc(t)]))     # Base + LinearAlgebra
    cfmt(t::Tab) = @sprintf("%.3f", cmean(t, 1))                          # Printf

    # a record-like trait with a default over an existing Base function
    @trait Rec begin
        @const data::Vector{Float64}
        rlen(r::Rec)::Int = length(r.data)
    end
    rtotal(r::Rec) = rlen(r) * 1.0 + sum(r.data)
    end
end)
using .AccLib

# --- G1.1: the owner of the implementing type redefines its own method (review F1) -------------
toplevel(quote
    import .AccLib: nc, colv
    struct Ramp; base::Vector{Float64}; n::Int; end
    nc(r::Ramp) = r.n
    colv(r::Ramp, i::Int) = r.base .* i
    @implement AccLib.Tab Ramp
end)
r = Ramp([1.0, 3.0], 2)
v0 = AccLib.cmean(r, 2)
toplevel(:(colv(r::Ramp, i::Int) = r.base .* (10i)))
v1 = AccLib.cmean(r, 2)
check("G1.1 redefinition by the implementing type's owner is followed", v0 == 4.0 && v1 == 40.0, "before $v0, after $v1, plain 4.0 then 40.0")

# --- G1.2: a helper of the user's implementation is redefined ----------------------------------
toplevel(quote
    struct Ramp2; base::Vector{Float64}; n::Int; end
    scale2(i) = i
    nc(r::Ramp2) = r.n
    colv(r::Ramp2, i::Int) = r.base .* scale2(i)
    @implement AccLib.Tab Ramp2
end)
r2 = Ramp2([1.0, 3.0], 2)
a = AccLib.cmean(r2, 2); toplevel(:(scale2(i) = 100i)); b = AccLib.cmean(r2, 2)
check("G1.2 redefinition of a helper the implementation calls is followed", a == 4.0 && b == 400.0, "before $a, after $b")

# --- G1.3: a default over an existing function overtaken by the type's owner (lesson 4) --------
toplevel(quote
    struct Bag; data::Vector{Float64}; end
    @implement AccLib.Rec Bag
end)
bg = Bag([1.0, 2.0])
t0 = AccLib.rtotal(bg)
ok13 = try
    toplevel(:(Base.length(b::Bag) = 100))          # Bag's owner adds a method plain Julia's `length(::Bag)` would call
    t1 = AccLib.rtotal(bg)
    # the trait's default calls length(r.data), not length(r): plain Julia keeps the default; nothing must change
    (t0 == 5.0 && t1 == 5.0, "before $t0, after $t1 (default reads the field: unchanged is right)")
catch e
    (false, "raised $(typeof(e))")
end
check("G1.3 an unrelated method of the conforming type leaves a field default alone", ok13...)

# --- G1.4: a pirate that wins at a concrete signature the trait code uses -----------------------
toplevel(quote
    struct Small; v::Vector{Float64}; end
    nc(s::Small) = 1
    colv(s::Small, i::Int) = s.v
    @implement AccLib.Tab Small
end)
sm = Small([1.0, 2.0, 3.0])
p0 = AccLib.cmean(sm, 1)
toplevel(quote
    module Pirate
    Base.sum(v::Vector{Float64}) = -1.0          # owns neither `sum` nor `Vector{Float64}`: a pirate that wins
    end
end)
p1 = try AccLib.cmean(sm, 1) catch e; sprint(showerror, e)[1:min(end, 90)] end
plain = sum([1.0, 2.0, 3.0]) / 3
check("G1.4 a winning pirate is followed as plain Julia follows it", p0 == 2.0 && p1 == plain, "before $p0, after $p1, plain now $plain")
toplevel(:(Base.delete_method(only(methods(Base.sum, Tuple{Vector{Float64}})))))

# --- G1.5: calls into code written without traits work, and compute plain Julia's values -------
m = [[2.0, 0.0], [0.0, 3.0]]
d = try AccLib.cdet(m) catch e; sprint(showerror, e)[1:min(end, 90)] end
f = try AccLib.cfmt(m) catch e; sprint(showerror, e)[1:min(end, 90)] end
check("G1.5 calls into Base, LinearAlgebra and Printf from trait code", d == 6.0 && f == "1.000", "det $d, fmt $(repr(f))")

# --- G1.6: a more specific method at the call signature, added later (review of 2026-10-17) ---
# The entry's hop to the worker, tested on the policy's call itself: the callee gains a method more
# specific at the call's signature. (A trait module's worker added later by `@eval` would not be
# rewritten to a bound, so the hop is tested directly.)
toplevel(quote
    module Hop
    h(x::Integer) = 1
    end
    hop(x) = FactsCall.call(Hop.h, x)
end)
h0 = hop(1)
toplevel(:(Hop.h(x::Int) = 2))
h1 = hop(1)
check("G1.6 a more specific method at the call signature, added later, is followed", h0 == 1 && h1 == 2 == Hop.h(1), "before $h0, after $h1, plain $(Hop.h(1))")

# --- G1.7: recursion through an entry (a worker calls its function's entry at the same types) -----
toplevel(quote
    @trait_module module AccRec
    using TraitWorld
    export Cnt, cval, depth
    @trait Cnt begin
        cval(c::Cnt)::Int
    end
    @implement Cnt Int begin
        cval(c) = c
    end
    depth(c::Cnt) = cval(c) <= 0 ? 0 : 1 + depth(cval(c) - 1)    # the entry again, with an Int
    end
end)
using .AccRec
d7 = try AccRec.depth(5) catch e; sprint(showerror, e)[1:min(end, 120)] end
check("G1.7 recursion through an entry", d7 == 5, "depth(5) = $d7")

# --- G1.8: return_type at abstract argument types (map over an abstractly typed array) -----------
toplevel(quote
    @trait_module module AccMap
    using TraitWorld, ..AccRec
    export ones_like
    ones_like(c::Cnt) = map(x -> cval(c), Integer[])        # an empty map over an abstract element type
    end
end)
using .AccMap
e8 = try AccMap.ones_like(3) catch e; sprint(showerror, e)[1:min(end, 120)] end
p8 = map(x -> 1, Integer[])
check("G1.8 return_type at abstract types (an empty map's element type)", typeof(e8) == typeof(p8), "trait $(typeof(e8)), plain $(typeof(p8))")

# --- G1.9: plain Julia's return type changes after a redefinition; the trait code follows ---------
toplevel(quote
    module RTH
    k(x) = 1
    end
    @trait_module module AccMap2
    using TraitWorld, ..AccRec, ..RTH
    export kmap
    kmap(c::Cnt) = map(x -> RTH.k(x), Int[])        # empty: the element type is return_type's
    end
end)
using .AccMap2
r0 = eltype(AccMap2.kmap(1))
toplevel(:(RTH.k(x) = 1.5))
r1 = eltype(AccMap2.kmap(1)); p9 = eltype(map(x -> RTH.k(x), Int[]))
check("G1.9 return_type follows a redefinition", r0 == Int && r1 == p9 == Float64, "before $r0, after $r1, plain $p9")

# --- G1.10: compile-time evaluation of a callee with asserted effects over a run-time site --------
# (the adversarial hunt of 2026-10-17, FAIL 1)
toplevel(quote
    module Fold
    g(x) = 1
    Base.@assume_effects :foldable h(x::Int) = g(Base.inferencebarrier(x))
    end
    kfold() = Fold.h(1)
    wfold() = FactsCall.call(kfold)
end)
f0 = (kfold(), wfold())
toplevel(:(Fold.g(x) = 2))
f1 = (kfold(), wfold())
check("G1.10 a fold over a run-time site with asserted effects follows a redefinition", f0 == (1, 1) && f1 == (2, 2), "before $f0, after $f1 (plain, policy)")

# --- G1.11: return_type at signatures a method's compilation signature widens (FAIL 2) -----------
toplevel(quote
    module Wide
    ns(@nospecialize x) = x
    passf(f) = f
    pass(t) = t
    vaa(xs...) = xs
    end
    # (not `promote_op(pass, Type{Int})`: plain Julia gives `DataType` folded and `Type{Int64}` at run
    # time, so inference-dependent values have no single plain answer; see wrapping-by-facts.md, G1)
    kwide() = (Base.promote_op(Wide.ns, Int), Base.promote_op(Wide.passf, typeof(sin)),
               Base.promote_op(Wide.vaa, ntuple(_ -> Int, 10)...), typeof(Wide.ns.(Int[])))
end)
pw = kwide(); qw = FactsCall.call(kwide)
check("G1.11 return_type at widened compilation signatures", pw == qw, "plain $pw, policy $qw")

# --- G1.12: recursion through an entry with growing types (review C1) -----------------------------
toplevel(quote
    @trait_module module AccNest
    using TraitWorld, ..AccRec
    export nest
    nest(c::Cnt, x) = cval(c) <= 0 ? x : nest(cval(c) - 1, (x,))       # the entry again, a bigger type each level
    end
end)
using .AccNest
n12 = try AccNest.nest(3, 1) catch e; sprint(showerror, e)[1:min(end, 120)] end
check("G1.12 recursion through an entry with growing types", n12 == (((1,),),), "nest(3, 1) = $n12")

# --- G1.13: a plain redefinition changes a generic conformance's predicate (final review, 2) --------
toplevel(quote
    @trait_module module AccCaps
    using TraitWorld
    export HasLen, Idx
    @trait HasLen{R} begin
        Base.length(r::R)::Int
    end
    @trait Idx{R} <: HasLen begin
        Base.getindex(r::R, i::Int)::eltype(R)
    end
    end
    @trait_module module AccGen
    using TraitWorld, ..AccCaps
    export GT, gfirstsum
    @trait GT{R} begin
        gcol(r::R, i::Int)::Vector{Float64}
    end
    @implement GT{R} where {R: Idx, eltype(R) == Vector{Float64}} begin
        gcol(r, i) = r[i]
    end
    gfirstsum(t::GT) = sum(gcol(t, 1))
    end
    struct WrapG; v::Vector{Vector{Float64}}; end
    @implement AccCaps.HasLen{WrapG} begin length(r) = length(r.v) end
    @implement AccCaps.Idx{WrapG} begin getindex(r, i) = r.v[i] end
    Base.eltype(::Type{WrapG}) = Vector{Float64}
end)
wg = WrapG([[1.0, 2.0]])
g0 = AccGen.gfirstsum(wg)
toplevel(:(Base.eltype(::Type{WrapG}) = Vector{Int}))          # Revise-style: no @implement, no load
g1 = try AccGen.gfirstsum(wg) catch e; e end
check("G1.13 a redefinition that changes a generic conformance's predicate is followed", g0 == 3.0 && g1 isa MethodError,
      "before $g0, after $(g1 isa Exception ? typeof(g1) : g1) (a fresh session: no conformance, MethodError)")

# --- G1.14: a task in an older world sees that world's conformances (final review, 2) --------------
toplevel(quote
    struct Late; v::Vector{Vector{Float64}}; end
    AccLib.nc(r::Late) = length(r.v)
    AccLib.colv(r::Late, i::Int) = r.v[i]
end)
w0 = Base.get_world_counter()
toplevel(:(@implement AccLib.Tab Late))
lt = Late([[1.0, 3.0]])
o_old = try Base.invoke_in_world(w0, AccLib.cmean, lt, 1) catch e; e end
o_new = AccLib.cmean(lt, 1)
check("G1.14 a call in an older world does not see a later conformance", o_old isa Exception && o_new == 2.0,
      "old world: $(o_old isa Exception ? typeof(o_old) : o_old), latest: $o_new")

# --- G1.15: a bare edge to a cycle partner, with native code of the same instances (review 3a) ------
toplevel(quote
    module Cyc
    h(x::Int) = 1
    f(n::Int) = n <= 0 ? h(n) : g(n - 1)
    g(n::Int) = n <= 0 ? h(n) : f(n - 1)
    end
    cyc() = Cyc.f(5)
    wcyc() = FactsCall.call(cyc)
end)
c0 = (cyc(), wcyc(), Cyc.g(4))
toplevel(:(Cyc.h(x::Int) = 2))
c1 = (cyc(), wcyc(), Cyc.g(4))
check("G1.15 a cycle's callee redefined deep inside", c0 == (1, 1, 1) && c1 == (2, 2, 2), "before $c0, after $c1 (plain, policy, native partner)")

# --- G2.1: a trait function of a package called on type values; another module extends it ---------
# (review of 2026-10-17, R1: kind-typed facts only for closures)
toplevel(quote
    module Pk
    trt(::Type{T}) where {T} = false
    trt(::Type{Int}) = true
    end
    kt(v::Vector{DataType}) = count(T -> Pk.trt(T), v)
end)
cikt = FactsCall.ci(Tuple{typeof(kt), Vector{DataType}})
r0 = FactsCall.call(kt, DataType[Int, Float64])
toplevel(quote
    module Qk
    struct QT end
    Main.Pk.trt(::Type{QT}) = true
    end
end)
r1 = FactsCall.call(kt, DataType[Int, Float64, Qk.QT]); p1 = kt(DataType[Int, Float64, Qk.QT])
check("G2.1 an unrelated module extending a function called on type values invalidates nothing", cikt.max_world == typemax(UInt) && r0 == 1 && r1 == p1 == 2,
      "still valid: $(cikt.max_world == typemax(UInt)), results $r0, $r1 (plain $p1)")

# --- G1.17: a call site split over dynamic values' candidates (part D) takes a later conformance -----
# (the wrong-code bug of session 29: the split dropped its last check and its fallback)
toplevel(quote
    @trait_module module AccDyn
    using TraitWorld
    export Shp, sarea, stotal
    @trait Shp{R} begin
        sarea(r::R)::Float64
    end
    struct Sq; a::Float64; end
    struct Ci; r::Float64; end
    @implement Shp{Sq} begin sarea(s) = s.a^2 end
    @implement Shp{Ci} begin sarea(c) = 3.0 * c.r^2 end
    function stotal(v::Vector{Dynamic{Shp}})
        s = 0.0
        for d in v
            s += sarea(d)
        end
        return s
    end
    end
end)
dv = Dynamic{AccDyn.Shp}[Dynamic{AccDyn.Shp}(AccDyn.Sq(2.0)), Dynamic{AccDyn.Shp}(AccDyn.Ci(1.0))]
t0 = AccDyn.stotal(dv)
fcis() = [ci for m in methods(AccDyn.stotal) for mi in Base.specializations(m) if mi isa Core.MethodInstance
          for ci in (let out = Any[]; c = isdefined(mi, :cache) ? mi.cache : nothing; while c !== nothing; push!(out, c); c = isdefined(c, :next) ? c.next : nothing; end; out end)
          if ci.owner === :facts]
held = fcis()
toplevel(quote
    module AccDyn2
    using TraitWorld, ..AccDyn
    import ..AccDyn: sarea
    struct Tri; b::Float64; end
    @implement AccDyn.Shp{Tri} begin sarea(t) = t.b / 2 end
    end
end)
push!(dv, Dynamic{AccDyn.Shp}(AccDyn2.Tri(4.0)))
t1 = AccDyn.stotal(dv)
check("G1.17 a dynamic value of a later conformance at a split call site", t0 == 7.0 && t1 == 9.0 && !isempty(held) && all(ci -> ci.max_world == typemax(UInt), held),
      "before $t0, after $t1 (9.0), facts code still valid: $(all(ci -> ci.max_world == typemax(UInt), held))")

# --- G1.18: an operation on a Dynamic value whose type inference knows (the implementation review of
# 2026-10-19, finding 1: the call was inlined with dynamic_call's own arguments) ------------------
toplevel(quote
    @trait_module module AccDynK
    using TraitWorld
    export KCol, kdata
    @trait KCol{R} begin
        kdata(r::R)::Vector{Float64}
    end
    struct KA; v::Vector{Float64}; end
    struct KB; w::Vector{Float64}; end
    @implement KCol{KA} begin kdata(a) = a.v end
    @implement KCol{KB} begin kdata(b) = b.w end
    const KD = Dynamic{KCol}(KA([1.0, 2.0]))
    kconst() = sum(kdata(KD))                                   # a constant Dynamic, an operation that is not folded
    klocal() = (d = Dynamic{KCol}(KB([3.0])); sum(kdata(d)))     # made and used in one body
    karg(d::Dynamic{KCol}) = sum(kdata(d))
    end
end)
g18 = (try (AccDynK.kconst(), AccDynK.klocal(), AccDynK.karg(AccDynK.KD)) catch e; sprint(showerror, e)[1:min(end, 120)] end)
check("G1.18 an operation on a Dynamic value of a type inference knows", g18 == (3.0, 3.0, 3.0), "got $g18 (expected (3.0, 3.0, 3.0))")

# --- G1.19: a Base method asserted :foldable over a run-time site (the review, finding 2) -------
toplevel(quote
    module Fold19
    g19(x) = 1
    end
    Core.eval(Base, :(Base.@assume_effects :foldable bfold19(x::Int) = Main.Fold19.g19(Base.inferencebarrier(x))))
    k19() = Base.bfold19(1)
    w19() = FactsCall.call(k19)
end)
f190 = (k19(), w19())
toplevel(:(Fold19.g19(x) = 2))
f191 = (k19(), w19())
check("G1.19 a Base method's assertion over a run-time site does not fold a dispatch no edge records", f190 == (1, 1) && f191 == (2, 2),
      "before $f190, after $f191 (plain, facts)")

# --- G1.20: a Dynamic Callable (until W-4: a Callable in DynamicCall mode), called in an older world (session 29: its `@cfunction`
# pointer runs the function in the latest world, as the witness tables did) -----------------------
toplevel(quote
    module Cw20
    using TraitWorld
    f20(x::Float64) = x + 1.0
    const D20 = Dynamic{TraitWorld.Callable{Tuple{Float64},Float64}}(f20)
    calld(x) = D20(x)
    plain(x) = f20(x)
    end
end)
Cw20.calld(1.0); Cw20.plain(1.0)
w20 = Base.get_world_counter()
toplevel(:(Cw20.f20(x::Float64) = x + 100.0))
c20 = (Base.invoke_in_world(w20, Cw20.calld, 1.0), Base.invoke_in_world(w20, Cw20.plain, 1.0), Cw20.calld(1.0))
check("G1.20 a Dynamic Callable runs in the caller's world", c20 == (2.0, 2.0, 101.0),
      "old world: Callable $(c20[1]), plain $(c20[2]); latest world: Callable $(c20[3]) (expected (2.0, 2.0, 101.0))")

# --- G1.21: the same pointer, alternating worlds, and a function that does not exist in the older
# world: as a direct call, the older world sees its own methods (a MethodError where none exists) -
toplevel(quote
    module Cw21
    using TraitWorld
    g21(x::Float64) = x + 1.0
    const D21 = Dynamic{TraitWorld.Callable{Tuple{Float64},Float64}}(g21)
    calld(x) = D21(x)
    function h21 end
    const DH21 = Dynamic{TraitWorld.Callable{Tuple{Float64},Float64}}(h21)
    callh(x) = DH21(x)
    end
end)
w21a = Base.get_world_counter()
toplevel(:(Cw21.g21(x::Float64) = x + 100.0))
w21b = Base.get_world_counter()
alt = [isodd(i) ? Base.invoke_in_world(w21a, Cw21.calld, 1.0) : Base.invoke_in_world(w21b, Cw21.calld, 1.0) for i in 1:6]
w21c = Base.get_world_counter()
toplevel(:(Cw21.h21(x::Float64) = 3x))
early = try Base.invoke_in_world(w21c, Cw21.callh, 1.0) catch e; e isa MethodError ? :MethodError : e end
late = Cw21.callh(1.0)
check("G1.21 a Dynamic Callable's pointer in alternating worlds, and before its method exists", alt == [2.0, 101.0, 2.0, 101.0, 2.0, 101.0] && early === :MethodError && late == 3.0,
      "alternating: $alt; before the method: $early; after: $late")

# --- G1.22: a dynamic call site cached for exact argument types (inline caches, stage 1): a
# `@nospecialize` method's cache entry is no leaf signature, so the site keeps an entry of its own;
# after a redefinition the older world sees the old method, the latest the new one ---------------
toplevel(quote
    module Ic22
    k22(@nospecialize(x)) = 1
    k22(x::String) = 2                    # two methods: the call at `Any` dispatches at run time
    const V22 = Any[1.0, 2.0, 3.0]
    run22() = (s = 0; for x in V22; s += k22(x)::Int; end; s)
    end
end)
Ic22.run22(); Ic22.run22()
w22 = Base.get_world_counter()
toplevel(:(Ic22.k22(@nospecialize(x)) = 100))
c22 = (Base.invoke_in_world(w22, Ic22.run22), Ic22.run22(), Base.invoke_in_world(w22, Ic22.run22))
check("G1.22 a dynamic call site cached for exact types runs in the caller's world", c22 == (3, 300, 3),
      "old world $(c22[1]), latest $(c22[2]), old again $(c22[3]) (expected (3, 300, 3))")

# --- G1.23: a site cached for every type at an `Any` position (the method cache's entry itself, a
# wildcard), then a more specific method for one type: the new world reaches it, the older does not
toplevel(quote
    module Ic23
    k23(@nospecialize(x)) = 1
    k23(x::String) = 2                     # two methods: the call at `Any` dispatches at run time
    const V23 = Any[1, 2.0, :a, 0x01, 'c', 1//2, (1,), nothing, Int32(1), 3.0f0]
    run23() = (s = 0; for x in V23; s += k23(x)::Int; end; s)
    end
end)
Ic23.run23(); Ic23.run23()
w23 = Base.get_world_counter()
toplevel(:(Ic23.k23(x::Float64) = 100))
c23 = (Base.invoke_in_world(w23, Ic23.run23), Ic23.run23(), Base.invoke_in_world(w23, Ic23.run23))
check("G1.23 a site cached for every type at an Any position sees a later, more specific method", c23 == (10, 109, 10),
      "old world $(c23[1]), latest $(c23[2]), old again $(c23[3]) (expected (10, 109, 10))")

# --- G1.24: beyond a split's candidates, the table of the call's targets (E-145): results, a
# redefinition followed in the new world and not in the old, no allocation; a plain split whose
# function has no method for a type raises as the call would
toplevel(quote
    @trait_module module AccTab
    using TraitWorld
    export TShp, tarea, ttotal
    @trait TShp begin
        tarea(s::TShp)::Float64
    end
    function ttotal(v::Vector{Dynamic{TShp}})
        s = 0.0
        for d in v
            s += tarea(d)
        end
        return s
    end
    end
end)
toplevel(quote
    struct AT1; a::Float64; end
    struct AT2; a::Float64; end
    struct AT3; a::Float64; end
    struct AT4; a::Float64; end
    struct AT5; a::Float64; end
    struct AT6; a::Float64; end
    @implement AccTab.TShp AT1 begin tarea(s) = 1.0 * s.a end
    @implement AccTab.TShp AT2 begin tarea(s) = 2.0 * s.a end
    @implement AccTab.TShp AT3 begin tarea(s) = 3.0 * s.a end
    @implement AccTab.TShp AT4 begin tarea(s) = 4.0 * s.a end
    @implement AccTab.TShp AT5 begin tarea(s) = 5.0 * s.a end
    @implement AccTab.TShp AT6 begin tarea(s) = 6.0 * s.a end
end)
v24 = Dynamic{AccTab.TShp}[Dynamic{AccTab.TShp}(T(1.0)) for T in (AT1, AT2, AT3, AT4, AT5, AT6)]
a24 = (AccTab.ttotal(v24), AccTab.ttotal(v24))
# the steady state, in one world: after a world bump each pointer looks its target up once (compiler C-3)
alloc24(v) = (AccTab.ttotal(v); @allocated AccTab.ttotal(v))
al24 = alloc24(v24)
w24 = Base.get_world_counter()
toplevel(:(AccTab.tarea(s::AT6) = 60.0 * s.a))
r24 = (AccTab.ttotal(v24), Base.invoke_in_world(w24, AccTab.ttotal, v24), AccTab.ttotal(v24))
toplevel(quote
    module Pl24
    struct K end
    g(x::Int) = 1; g(x::Float64) = 2; g(x::String) = 3; g(x::Symbol) = 4; g(x::Char) = 5
    for T in (Int, Float64, String, Symbol)
        Base.Compiler.register_dynamic_candidate!(K, T)
    end
    run(v::Vector{Any}) = (s = 0; for x in v; s += Base.Compiler.split_call(K, Int, g, x)::Int; end; s)
    end
end)
p24 = (Pl24.run(Any[1, 2.0, "a", :b, 'c', 'd']), try Pl24.run(Any[1//2]); :none catch e; nameof(typeof(e)) end)
check("G1.24 beyond a split's candidates, the table of targets: results, worlds, no allocation, a missing method", a24 == (21.0, 21.0) && al24 == 0 && r24 == (75.0, 21.0, 75.0) && p24 == (20, :MethodError),
      "total $(a24), allocated $al24 B, after the redefinition / older world / again $(r24) (expected (75.0, 21.0, 75.0)), plain split $(p24) (expected (20, :MethodError))")

# --- G1.25: `compiled_for` from a caller that does not know the type, through the table of declared
# implementations (lowering §9.3): a redefinition is followed in the new world and not in the old,
# and a type declared after the older world is not found there
toplevel(quote
    @trait_module module AccUT
    using TraitWorld
    export UTw, uval, utwice
    @trait UTw begin
        uval(u::UTw)::Float64
    end
    utwice(u::UTw) = 2 * uval(u)
    end
end)
toplevel(quote
    struct UT1; x::Float64; end
    AccUT.uval(u::UT1) = u.x
    @implement AccUT.UTw UT1
    ucall(v::Vector{Any}) = (s = 0.0; for x in v; s += AccUT.utwice(compiled_for(x))::Float64; end; s)
end)
v25 = Any[UT1(1.5)]
u0 = ucall(v25)
w25 = Base.get_world_counter()
toplevel(:(AccUT.uval(u::UT1) = 10 * u.x))
u1 = (Base.invokelatest(ucall, v25), Base.invoke_in_world(w25, ucall, v25))
toplevel(quote
    struct UT2; x::Float64; end
    AccUT.uval(u::UT2) = u.x + 1
end)
w25b = Base.get_world_counter()
toplevel(:(@implement AccUT.UTw UT2))
v25b = Any[Base.invokelatest(getglobal(Main, :UT2), 1.0)]
u2 = (Base.invokelatest(ucall, v25b), try Base.invoke_in_world(w25b, ucall, v25b); :none catch e; nameof(typeof(e)) end)
check("G1.25 compiled_for from an untyped caller through the table: worlds and a later type", u0 == 3.0 && u1 == (30.0, 3.0) && u2 == (4.0, :MethodError),
      "before $u0, after / older world $u1 (expected (30.0, 3.0)), a later type / before its declaration $u2 (expected (4.0, :MethodError))")

println()
println(count(x -> x[2], results), " of ", length(results), " checks pass")
