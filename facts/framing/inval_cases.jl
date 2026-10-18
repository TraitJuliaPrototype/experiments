# Steps 1 and 3 of the framing (design.md §3.1, §3.3) as an acceptance file: which definitions
# invalidate compiled code, in plain Julia and in the facts mode. Each case compiles a caller,
# makes one definition, and checks whether the caller's CodeInstances are still valid, against
# the outcome the design states for the mode the process runs in.
#
#     julia inval_cases.jl                              # plain
#     JULIA_COMPILE_BY_FACTS=1 julia inval_cases.jl     # the facts mode (all code)
#
# Plain code only: no TraitWorld. From experiments/facts/invalidation/inval.jl (S1–S8, the
# framing review's scratch), with expectations checked, S1b (the design's own `show` example)
# and S10 (a binding changed from another module) added. S9 (a package extension) needs
# packages: s9_extension.jl.
include(joinpath(@__DIR__, "..", "..", "examples", "common.jl"))
const FACTS = facts_mode()
println("julia ", VERSION, "  facts mode: ", FACTS)

# expected[case] = (plain invalidates?, facts mode invalidates?)
const EXPECTED = Dict(
    "S1"  => (true,  false),   # an owner's method at an abstract call (one match): not fully typed
    "S1b" => (true,  false),   # Base.show(io, ::MyIrr) against a caller of show(::IOBuffer, ::AbstractIrrational)
    "S1c" => (false, false),   # the same against show(::IOBuffer, ::Any): too many matches, no edge on 1.13
    "S2"  => (true,  false),   # a new subtype under union splitting: not fully typed
    "S3"  => (true,  false),   # a return_type-dependent map over an abstract element type
    "S4"  => (true,  true),    # a stakeholder's more specific method at a concrete fact
    "S5"  => (true,  true),    # a pirate that wins at a concrete fact
    "S6"  => (false, false),   # a pirate that loses at a concrete fact (Lemma D)
    "S7"  => (true,  true),    # the owner redefines a const the code read
    "S8"  => (true,  false),   # a new type at a kind (a type passed as a value)
    "S10" => (true,  true),    # another module redefines a const of Lib10 (the bindings exception)
)
function judge(case, f, types)
    v = cis_at(f, types)
    inval = !isempty(v) && !any(ci -> ci.max_world == typemax(UInt), v)
    exp = EXPECTED[case][FACTS ? 2 : 1]
    check("$case $(FACTS ? "facts" : "plain"): invalidated = $exp", inval == exp,
          "CodeInstances $(length(v)), valid $(count(ci -> ci.max_world == typemax(UInt), v))")
end

# S1: an owned method on an owned type at a call made at an abstract signature (one match).
module Lib1; foo(x::Int) = 1; caller(v::Vector{Any}) = foo(v[1]); end
Lib1.caller(Any[1])
module Other1; struct T end; Main.Lib1.foo(::T) = 2; end           # Other1 owns T: no pirate
judge("S1", Lib1.caller, (Vector{Any},))

# S1b: the design's example (§2, problem 1): a hook on one's own type, `Base.show(io, ::MyType)`,
# against a caller at an abstract `show` signature with few matching methods.
module Lib1b; describe(io::IOBuffer, v::Vector{AbstractIrrational}) = (show(io, v[1]); nothing); end
Lib1b.describe(IOBuffer(), AbstractIrrational[pi])
module Other1b; struct MyIrr <: AbstractIrrational end; Base.show(io::IO, ::MyIrr) = print(io, "mine"); end
judge("S1b", Lib1b.describe, (IOBuffer, Vector{AbstractIrrational}))
check("S1b the hook is used by the caller", (io = IOBuffer(); Lib1b.describe(io, AbstractIrrational[Other1b.MyIrr()]); String(take!(io)) == "mine"))
# S1c: the same hook against a caller at `show(::IOBuffer, ::Any)`. On 1.13 a call with more
# matching methods than max_methods records no edge at all, so plain Julia loses nothing either:
# design.md §2's "every caller compiled at show(::IO, ::Any)-shaped signatures" holds only where
# few methods match (the abstract signature is narrow).
module Lib1c; describe(io::IOBuffer, v::Vector{Any}) = (show(io, v[1]); nothing); end
Lib1c.describe(IOBuffer(), Any[1])
module Other1c; struct MyType end; Base.show(io::IO, ::MyType) = print(io, "mine"); end
judge("S1c", Lib1c.describe, (IOBuffer, Vector{Any}))

# S2: speculation over an abstract container (union split, 2 methods); a new subtype by its owner.
module Lib2
abstract type Shape end
struct A <: Shape end; struct B <: Shape end
area(::A) = 1.0; area(::B) = 2.0
function total(v::Vector{Shape}); s = 0.0; for x in v; s += area(x); end; s; end
end
Lib2.total(Lib2.Shape[Lib2.A(), Lib2.B()])
module Other2; struct C <: Main.Lib2.Shape end; Main.Lib2.area(::C) = 3.0; end
judge("S2", Lib2.total, (Vector{Lib2.Shape},))
check("S2 the new subtype is used", Lib2.total(Lib2.Shape[Lib2.A(), Other2.C()]) == 4.0)

# S3: a result decided by inference (return_type through map over an empty abstract vector).
module Lib3; w(x::Float64) = x; f3(xs::Vector{Real}) = map(w, xs); end
t3a = typeof(Lib3.f3(Real[]))
module Other3; struct NR <: Real end; Main.Lib3.w(::NR) = "s"; end
judge("S3", Lib3.f3, (Vector{Real},))
t3b = typeof(Lib3.f3(Real[]))
# plain: Vector{Float64} before (the one method), Vector{Union{Float64,String}} or Vector{Any} after;
# the facts mode answers return_type by plain inference at run time, so the values agree with plain.
println("     S3 map(w, Real[]) :: ", t3a, " before, ", t3b, " after")

# S4: a stakeholder (the function's owner) adds a more specific method at a concrete fact.
module Lib4; bar(x::Integer) = 1; c4(x::Int) = bar(x); end
Lib4.c4(1)
Lib4.eval(:(bar(x::Int) = 2))
judge("S4", Lib4.c4, (Int,))
check("S4 the stakeholder's method is followed", Lib4.c4(1) == 2)

# S5: a pirate that wins at a concrete fact; S6: a pirate that loses there.
module Lib5; baz(x::Integer) = 1; c5(x::Int) = baz(x); end
Lib5.c5(1)
module Pirate5; Main.Lib5.baz(x::Signed) = 99; end                  # owns neither baz nor Signed
judge("S5", Lib5.c5, (Int,))
check("S5 the winning pirate is followed (rule P)", Lib5.c5(1) == 99)
module Pirate6; Main.Lib5.baz(x::Real) = 7; end                     # a pirate that loses at baz(::Int)
judge("S6", Lib5.c5, (Int,))
check("S6 the losing pirate changes nothing", Lib5.c5(1) == 99)

# S7: a binding, not a method: the owner redefines a const its code read.
module Lib7; const K = 1; g7() = K + 1; end
Lib7.g7()
Lib7.eval(:(const K = 2))
judge("S7", Lib7.g7, ())
check("S7 the new value is read", Lib7.g7() == 3)

# S8: a kind (a type passed as a value) at a call of an owned function; a new type by another owner.
module Lib8; make(::Type{Int}) = 0; c8(T::DataType) = make(T); end
Lib8.c8(Int)
module Other8; struct U end; Main.Lib8.make(::Type{U}) = 1; end
judge("S8", Lib8.c8, (DataType,))
check("S8 the new type's method is used", Lib8.c8(Other8.U) == 1)

# S10: a binding changed from another module. Julia cannot tell this from S7: a binding has no
# owner the runtime checks, and no definition hook sees it (design.md §3.2, the bindings exception).
module Lib10; const LIMIT = 10; capped(x::Int) = min(x, LIMIT); end
Lib10.capped(100)
module Intruder10; Core.eval(Main.Lib10, :(const LIMIT = 20)); end
judge("S10", Lib10.capped, (Int,))
check("S10 the new value is read", Lib10.capped(100) == 20)
pending("S10 strict tier: a binding changed by a non-owner is refused or named",
        "a rule for bindings and a hook that sees them (design.md §3.2; open-issues §1.10)",
        "nothing sees it; see strict_tiers.jl for the trait-code variant")

# Values: map over an empty container of an abstract element type agrees with plain Julia.
module V; g(x::Real) = 1.0; f2(x::Real) = g(x); end
check("values: map(f2, Real[]) is Vector{Float64} in both modes", typeof(map(V.f2, Real[])) == Vector{Float64},
      "got $(typeof(map(V.f2, Real[])))")
summary()
