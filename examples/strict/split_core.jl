# Strict mode and a split-core package (design.md §5 rule 2, delegates): the core package owns
# the type, the implementation package defines methods of other owners' functions for it.
# Those are pirates by the letter; a delegate declaration makes the implementation a stakeholder.
#
#     JULIA_TW_STRICT=1 julia --project=../env split_core.jl CASE
#
# CASE:
#   nodelegate  CoreP/ImplP, no delegate: ImplP's `CoreP.norm1(::P2)` wins at a fact of trait code
#   delegate    the same with ("CoreP", "ImplP") on the curated list of delegates first
#   staticarrays  StaticArraysCore types in trait code, then `using StaticArrays` (a pair on
#               TraitWorld's curated list of delegates): StaticArrays fills gaps (`size`)
#
# Expected:
#   nodelegate: ImplP's winning method is left inactive at its load, with an error naming it; the
#               trait code keeps CoreP's answer, and so does plain Julia (identical or error).
#   delegate:   accepted; followed by trait code and plain code.
#   staticarrays: accepted (the curated delegate); trait code computes what plain Julia computes.
#   Without the curated entry, StaticArrays itself would be refused: the delegate list is load-bearing.
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld
case = ARGS[1]
STRICT = TraitWorld.STRICT[]
println("julia ", VERSION, "  strict: ", STRICT, "  case: ", case)
STRICT || @warn "run with JULIA_TW_STRICT=1: this example is about the strict tier"
logs = IOBuffer()
quiet(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.SimpleLogger(logs))
if case in ("nodelegate", "delegate")
    using CoreP
    toplevel(quote
        @trait_module module PLib
        using TraitWorld
        import CoreP
        export PS, n1
        @trait PS{R} begin
            ps(r::R)::Vector{CoreP.P2}
        end
        @implement PS{Vector{CoreP.P2}} begin
            ps(r) = r
        end
        n1(p::PS) = (s = 0.0; for q in ps(p); s += CoreP.norm1(q); end; s)
        end
    end)
    v = [CoreP.P2(1.0, -2.0), CoreP.P2(-3.0, 4.0)]
    check("$case before: n1 = 10.0", Base.invokelatest(Main.PLib.n1, v) == 10.0)
    # `TraitWorld.delegate!(CoreP => ImplP)` takes both modules, so it cannot be declared before
    # ImplP loads; the curated list (data, by package name) can, and is what the design keeps.
    case == "delegate" && push!(TraitWorld.KNOWN_DELEGATES, ("CoreP", "ImplP"))
    r = outcome(() -> quiet(() -> (@eval using ImplP; nothing)))
    msg = String(take!(logs))
    w = Base.invokelatest(Main.PLib.n1, v); p = Base.invokelatest(() -> sum(CoreP.norm1, v))
    check("$case loading ImplP raises nothing", r === nothing, r === nothing ? "" : sprint(showerror, r))
    check("$case trait code identical to plain Julia", w == p, "trait $w, plain $p")
    # a further definition by ImplP (Revise-style) at the same fact
    r2 = outcome(() -> (Core.eval(Main.ImplP, :(CoreP.norm1(p::P2) = 2.0 * (abs(p.x) + abs(p.y))));
                        nothing))
    w2 = Base.invokelatest(Main.PLib.n1, v); p2 = Base.invokelatest(() -> sum(CoreP.norm1, v))
    if case == "nodelegate"
        check("nodelegate ImplP's winning method left inactive at load, with an error naming it",
              occursin("norm1", msg) && occursin("inactive", msg), first(msg, 400))
        check("nodelegate ImplP's next definition at the fact is refused (PirateError)", r2 isa TraitWorld.PirateError,
              r2 === nothing ? "accepted" : string(typeof(r2)))
        check("nodelegate values unchanged, trait and plain", w2 == p2 == 10.0, "trait $w2, plain $p2")
    else
        check("delegate ImplP's next definition is accepted", r2 === nothing, r2 === nothing ? "" : sprint(showerror, r2))
        check("delegate followed by trait and plain code", w2 == p2 == 20.0, "trait $w2, plain $p2")
    end
elseif case == "staticarrays"
    using StaticArraysCore
    toplevel(quote
        @trait_module module SLib
        using TraitWorld
        using StaticArraysCore: SVector
        export SP, npts
        @trait SP{R} begin
            sp(r::R)::Vector{SVector{2,Float64}}
        end
        @implement SP{Vector{SVector{2,Float64}}} begin
            sp(r) = r
        end
        npts(p::SP) = (n = 0; for q in sp(p); n += length(q); end; n)
        end
    end)
    v = [SVector{2,Float64}((1.0, 2.0)), SVector{2,Float64}((3.0, 4.0))]
    e0 = outcome(() -> Base.invokelatest(Main.SLib.npts, v))
    check("staticarrays before: a MethodError (no `size` for SArray without StaticArrays), as in plain Julia", e0 isa MethodError,
          e0 isa Exception ? first(sprint(showerror, e0), 120) : "got $e0")
    r = outcome(() -> quiet(() -> (@eval using StaticArrays; nothing)))
    msg = String(take!(logs))
    check("staticarrays loading StaticArrays raises nothing and leaves nothing inactive", r === nothing && !occursin("inactive", msg), first(msg, 300))
    n = outcome(() -> Base.invokelatest(Main.SLib.npts, v))
    check("staticarrays trait code now computes plain Julia's value", n == 4, "got $n")
end
summary()
