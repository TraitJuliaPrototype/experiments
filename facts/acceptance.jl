# Acceptance checks for "wrapping by facts" (writeup/explorations/wrapping-by-facts.md).
# Each check prints PASS/FAIL with what it saw. Run in a fresh session:
#   julia --project=<env with TraitWorld> acceptance.jl
# G1: the trait world computes what plain Julia computes (or raises), under redefinitions, late
#     methods by owners, winning pirates, and calls into code written without traits.
# G2: unrelated loads invalidate no trait-world code (counted separately: acceptance_loads.jl).
using TraitWorld, Test

results = Tuple{String,Bool,String}[]
check(name, ok, detail = "") = (push!(results, (name, ok, detail)); println(ok ? "PASS  " : "FAIL  ", name, isempty(detail) ? "" : "  ($detail)"))
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)

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
    hop(x) = TraitWorld._facts_call(Hop.h, x)
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

println()
println(count(x -> x[2], results), " of ", length(results), " checks pass")
