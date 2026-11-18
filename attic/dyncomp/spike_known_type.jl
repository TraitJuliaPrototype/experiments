# W-4 step 3.0, the spike (implementation plan, revision 3, §5; risk R1): does `Compiler.known_type`
# fold to `true` in a typed caller, and stay `false` in an untyped one and at the prompt, for every
# shape an entry will have once its trait positions are `@nospecialize`: positional, keyword,
# vararg, a function argument, several positions? Callers: plain code, code compiled by facts,
# the prompt. Plus: does a caller split `Compiler.split_call` over a held value (as `Dynamic` holds)?
# Standalone (no TraitWorld).
#   flock /tmp/claude-1000/julia-review.lock nice -n 19 ../../julia-1.13/julia --startup-file=no spike_known_type.jl
#
# Lesson (from this spike's first version): `known_type` must be evaluated in the entry's own body.
# A helper called with the `Any`-typed value is a run-time site in code compiled by facts, compiled
# for the value's type, where it folds to `true` (the row "through a helper").
const CC = Base.Compiler
mark(b::Bool) = b ? :typed : :untyped
kt_helper(x) = CC.known_type(x)

# entry shapes: inlined boundaries, trait positions @nospecialize (as an entry will be)
@eval begin
@inline e_pos(@nospecialize(x), i::Int) = ($(Expr(:meta, :facts_boundary)); mark(CC.known_type(x)))
@inline e_kw(@nospecialize(x); k::Int = 1) = ($(Expr(:meta, :facts_boundary)); mark(CC.known_type(x)))
@inline e_kwreq(@nospecialize(x); k) = ($(Expr(:meta, :facts_boundary)); mark(CC.known_type(x)))
@inline e_va(@nospecialize(xs...)) = ($(Expr(:meta, :facts_boundary)); mark(CC.known_type(xs[1])))
@inline e_fn(@nospecialize(f), x::Float64) = ($(Expr(:meta, :facts_boundary)); mark(CC.known_type(f)))
@inline e_two(@nospecialize(x), @nospecialize(y)) = ($(Expr(:meta, :facts_boundary)); (mark(CC.known_type(x)), mark(CC.known_type(y))))
@inline e_helper(@nospecialize(x)) = ($(Expr(:meta, :facts_boundary)); mark(kt_helper(x)))
end

struct Circle; r::Float64; end

# plain callers
p_pos(c::Circle) = e_pos(c, 1)
p_kw(c::Circle) = e_kw(c; k = 2)
p_kwdef(c::Circle) = e_kw(c)
p_kwreq(c::Circle) = e_kwreq(c; k = 3)
p_va(c::Circle) = e_va(c, c)
p_fn(c::Circle) = e_fn(abs2, 1.0)
p_clo(c::Circle) = e_fn(x -> c.r * x, 1.0)
p_two(c::Circle, v::Vector{Any}) = e_two(c, v[1])
u_pos(v::Vector{Any}) = e_pos(v[1], 1)
u_kw(v::Vector{Any}) = e_kw(v[1]; k = 2)
u_va(v::Vector{Any}) = e_va(v[1])

# callers compiled by facts
module F
Base.Experimental.@compiler_options facts=true
using ..Main: e_pos, e_kw, e_va, e_fn, e_helper, Circle
f_pos(c::Circle) = e_pos(c, 1)
f_kw(c::Circle) = e_kw(c; k = 2)
f_va(c::Circle) = e_va(c)
f_fn(c::Circle) = e_fn(x -> c.r * x, 1.0)
u_pos(v::Vector{Any}) = e_pos(v[1], 1)
u_kw(v::Vector{Any}) = e_kw(v[1]; k = 2)
u_helper(v::Vector{Any}) = e_helper(v[1])
end

c = Circle(1.0); v = Any[Circle(2.0)]
results = [
  "plain typed, positional"  => (p_pos(c), :typed),
  "plain typed, keyword"     => (p_kw(c), :typed),
  "plain typed, keyword default" => (p_kwdef(c), :typed),
  "plain typed, required keyword" => (p_kwreq(c), :typed),
  "plain typed, vararg"      => (p_va(c), :typed),
  "plain typed, Base function" => (p_fn(c), :typed),
  "plain typed, closure"     => (p_clo(c), :typed),
  "plain, two positions"     => (p_two(c, v), (:typed, :untyped)),
  "plain untyped, positional" => (u_pos(v), :untyped),
  "plain untyped, keyword"   => (u_kw(v), :untyped),
  "plain untyped, vararg"    => (u_va(v), :untyped),
  "facts typed, positional"  => (F.f_pos(c), :typed),
  "facts typed, keyword"     => (F.f_kw(c), :typed),
  "facts typed, vararg"      => (F.f_va(c), :typed),
  "facts typed, closure"     => (F.f_fn(c), :typed),
  "facts untyped, positional" => (F.u_pos(v), :untyped),
  "facts untyped, keyword"   => (F.u_kw(v), :untyped),
  "facts untyped, through a helper" => (F.u_helper(v), :typed),   # the pitfall, as expected
  "prompt, positional"       => (e_pos(c, 1), :untyped),
  "prompt, keyword"          => (e_kw(c; k = 2), :untyped),
]
let bad = 0
    for (name, (got, want)) in results
        ok = got == want; ok || (bad += 1)
        println(rpad(name, 34), rpad(string(got), 22), ok ? "ok" : "EXPECTED $(want)")
    end
    println("known_type: ", length(results) - bad, " of ", length(results), " as expected")
end

# the split over a held value, in a plain caller and in a caller compiled by facts
struct Sq; s::Float64; end
area(c::Circle) = c.r^2 * pi
area(s::Sq) = s.s^2
struct Fam end
CC.register_dynamic_candidate!(Fam, Circle); CC.register_dynamic_candidate!(Fam, Sq)
struct Holder; t::Any; end                     # as Dynamic{X} holds the user's object
@inline split_area(d::Holder) = CC.split_call(Fam, Float64, area, getfield(d, :t))::Float64
g_plain(v::Vector{Holder}) = split_area(v[1])
module G
Base.Experimental.@compiler_options facts=true
using ..Main: split_area, Holder
g_facts(v::Vector{Holder}) = split_area(v[1])
end
w = [Holder(Sq(2.0))]
for (name, f) in ("plain caller" => g_plain, "facts caller" => G.g_facts)
    r = f(w)
    ci = first(code_typed(f, (Vector{Holder},)))[1]
    nisa = count(st -> st isa Expr && st.head === :call && (st.args[1] === Core.isa || st.args[1] == GlobalRef(Core, :isa)), ci.code)
    println(rpad("split_call, " * name, 34), "result ", r, ", isa branches: ", nisa, nisa >= 2 ? "  ok" : "  NOT SPLIT")
end
