# W-97's audit of `oc-build` c3f0b4bc11: probes for suspected defects, each printing what the build does
# beside what compiler §7 intends. Not gates: they report, they do not assert.
#     julia-unified/julia --startup-file=no --project=experiments/unification experiments/unification/audit/probes.jl
using Traits
report(name, got, intended) = println(rpad(name, 58), " got ", rpad(repr(got), 8), " intended ", repr(intended), got == intended ? "" : "   <-- differs")

# P1. A type value is a member only through an entry for Type{S} (open issue 91), never because S is one.
@trait PX1
struct PS1 end
@implement PS1 PX1
report("P1 PS1() isa PX1 (the value)", PS1() isa PX1, true)
report("P1 PS1 isa PX1 (the type value)", PS1 isa PX1, false)
report("P1 Type{PS1} <: PX1", Type{PS1} <: PX1, false)
p1(::PX1) = :bounded
p1(::Any) = :fallback
report("P1 p1(PS1) dispatches with the type value", p1(PS1), :fallback)

# P2. Core.Dynamic{X} is a member of X: subtyping, intersection and dispatch agree.
@trait PX2
d2 = Core.Dynamic{PX2}(1)
report("P2 Dynamic{PX2} <: PX2", Core.Dynamic{PX2} <: PX2, true)
report("P2 d2 isa PX2", d2 isa PX2, true)
report("P2 typeintersect(Dynamic{PX2}, PX2) == Dynamic{PX2}", typeintersect(Core.Dynamic{PX2}, PX2) == Core.Dynamic{PX2}, true)
p2(::PX2) = :bounded
p2(::Any) = :fallback
report("P2 p2(Dynamic{PX2}(1))", p2(d2), :bounded)

# P3. A member pattern with more than eight type parameters.
@trait PX3
struct P9{A,B,C,D,E,F,G,H,I} end
ok3 = try
    @eval @implement P9{A,B,C,D,E,F,G,H,I} PX3
    :declared
catch err
    :refused
end
report("P3 declaring a 9-parameter family", ok3, :declared)
report("P3 P9{1,2,3,4,5,6,7,8,9} <: PX3", P9{1,2,3,4,5,6,7,8,9} <: PX3, true)

# P4. isa(x, T) and typeof(x) <: T agree, transitively.
@trait PA4
@trait PB4
struct PS4 end
@implement PB4 PA4          # the set PB4 is a member of PA4
@implement PS4 PB4          # PS4 is a member of PB4, not declared a member of PA4
# membership is transitive (the user, 2026-11-06): PS4 <: PB4 <: PA4 gives PS4 <: PA4, and isa agrees
report("P4 PS4() isa PA4", PS4() isa PA4, true)
report("P4 PS4 <: PA4 (transitive)", PS4 <: PA4, true)

# P5. A cycle of set-in-set entries is refused, whichever entry of a set leads back.
@trait PA5
@trait PC5
@trait PD5
@implement PC5 PD5          # PC5's first entry: PD5
@implement PC5 PA5          # PC5's second entry: PA5
ok5 = try
    @eval @implement PA5 PC5    # PA5 ∈ PC5 closes PA5 → PC5 → PA5
    :accepted
catch err
    :refused
end
report("P5 a cycle through a set's second entry", ok5, :refused)

# P6. Core's kinds never members: a builtin function's type.
@trait PX6
ok6 = try
    @eval @implement typeof(getfield) PX6
    :accepted
catch err
    :refused
end
report("P6 a builtin function's type as a member", ok6, :refused)

# P7. A membership of an abstract type reaches its subtypes through the supertype chain (transitivity).
@trait PX7
abstract type PAbs7 end
struct PS7 <: PAbs7 end
@implement PAbs7 PX7
report("P7 PAbs7 <: PX7 (the entry)", PAbs7 <: PX7, true)
report("P7 PS7 <: PX7 (chain, then entry)", PS7 <: PX7, true)
report("P7 PS7() isa PX7", PS7() isa PX7, true)
