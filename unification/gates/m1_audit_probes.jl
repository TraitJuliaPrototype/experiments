# Gate (W-98): the audit's probes P1, P3–P8 (writeup/reviews/2026-11-06-oc-build-audit.md),
# with the answers the references intend, and the declaration's checks (compiler §4.1–§4.6).
# P2 tested Core's wrappers, which are gone (C-20 retired; Dynamic{X} is W-106's struct).
using Traits
include("util.jl")

# P1. A type value is a member only by an entry for Type{S} (compiler §4.10, C-19).
@trait PX1
struct PS1 end
@implement PX1 PS1
@assert PS1() isa PX1
@assert !(PS1 isa PX1)
@assert !(Type{PS1} <: PX1)
p1(::PX1) = :bounded
p1(::Any) = :fallback
@assert p1(PS1) === :fallback
@assert p1(PS1()) === :bounded

# P3. A member pattern with more than eight type parameters (C-21).
@trait PX3
struct P9{A,B,C,D,E,F,G,H,I} end
@implement PX3 P9{A,B,C,D,E,F,G,H,I}
@assert P9{1,2,3,4,5,6,7,8,9} <: PX3

# P4. isa(x, T) and typeof(x) <: T agree, transitively (C-22).
@trait PA4
@trait PB4
struct PS4 end
@implement PA4 PB4
@implement PB4 PS4
@assert PS4() isa PA4
@assert PS4 <: PA4
@assert PB4 <: PA4

# P5. A cycle among sets is refused, whichever entry leads back (C-23).
@trait PA5
@trait PC5
@trait PD5
@implement PD5 PC5
@implement PA5 PC5
let refused = try
        @eval @implement PC5 PA5
        false
    catch
        true
    end
    @assert refused "a cycle through a set's second entry is refused"
end

# P6. A builtin function's type is never a member (C-24).
@trait PX6
let refused = try
        @eval @implement PX6 typeof(getfield)
        false
    catch
        true
    end
    @assert refused
end

# P7. A membership of an abstract type reaches its subtypes through the supertype chain.
@trait PX7
abstract type PAbs7 end
struct PS7 <: PAbs7 end
@implement PX7 PAbs7
@assert PAbs7 <: PX7
@assert PS7 <: PX7
@assert PS7() isa PX7

# P8. Parameters are invariant; X{<:T} and X{>:T} as for any type (C-26).
@trait PX8{T}
struct PS8 end
@implement PX8{Int} PS8
@assert PS8 <: PX8{Int}
@assert !(PS8 <: PX8{Real})
@assert PS8 <: PX8{<:Real}
@assert !(PS8 <: PX8{<:AbstractString})
@assert PS8 <: PX8{>:Int}
@assert PS8() isa PX8{<:Integer}
p8(::PX8{<:Integer}) = :bounded
p8(::Any) = :fallback
@assert p8(PS8()) === :bounded
@assert typeintersect(PS8, PX8{<:Real}) == PS8

# One instance per member (compiler §4.6): a second instance is refused; the same one is
# a redeclaration, which ends the old entry where the new one begins (§4.3).
let refused = try
        @eval @implement PX8{String} PS8
        false
    catch
        true
    end
    @assert refused "a second instance of the set is refused"
end
e1 = only(filter(e -> e.set === PX8.body.name, collect(PS8.name.memberships)))
e2 = @implement PX8{Int} PS8
@assert e1.max_world == e2.min_world - 1 "the old entry ends where the new one begins"
@assert PS8 <: PX8{Int}

# A set is open from its declaration (compiler §4.1): opening a published type is refused.
abstract type Published9 end
let refused = try
        ccall(:jl_set_open_set, Cvoid, (Any,), Published9)
        false
    catch
        true
    end
    @assert refused
end
@assert !Traits.isopen(Published9)

# A set's supertype is Any or a set.
let refused = try
        @eval @trait BadSuper9 <: Integer
        false
    catch
        true
    end
    @assert refused
end

# The declaring code continues in the new world (Expr(:latestworld)); the runtime does
# not move the task's world (C-25).
@trait PX10
struct PS10 end
let w0 = curworld()                                # one top-level statement: one world
    Traits.declare_membership(PS10, PX10, @__MODULE__)   # no latestworld here
    @assert curworld() == w0 "the runtime leaves the task's world"
    @assert !(PS10() isa PX10) "so this statement does not see the membership yet"
    @assert Base.invokelatest(() -> PS10() isa PX10)
end
@assert PS10() isa PX10 "the next statement does"

println("m1_audit_probes: OK")
