# Strict mode on a real pirate (the review's example 6; TraitDifferentialEquations row 8, both
# halves): `+` on ForwardDiff's duals, defined by a module that owns neither `+` nor `Dual`.
#
#     JULIA_LOAD_PATH="<TDE>/scripts/env:@stdlib" julia dual_pirate.jl ORDER              # default tier
#     JULIA_TW_STRICT=1 JULIA_LOAD_PATH="<TDE>/scripts/env:@stdlib" julia dual_pirate.jl ORDER
#
# ORDER:
#   after   a first gradient, then `+(::D3, ::D3)` for the gradient's own dual type (D3)
#   before  `+(::Dual{T,Float64,3}, ::Dual{T,Float64,3})` for every tag, defined after ForwardDiff
#           loads and before TraitDifferentialEquations does (the pirate already there when the
#           solver's image loads: piece 15's case)
# Each pirate counts its calls and returns the value plain ForwardDiff returns.
#
# Expected (design.md §3.2, §3.5):
#   default, both orders: followed; the solver's dual code calls the pirate; the gradient is unchanged.
#   strict, after:  a PirateError at the definition, naming `+` and the solver's code; the pirate
#                   never runs, for plain code either; the gradient is unchanged.
#   strict, before: an error naming the pirate when the solver's image loads (piece 15) — pending,
#                   not built: today followed silently.
include(joinpath(@__DIR__, "..", "common.jl"))
order = ARGS[1]
import ForwardDiff
const CALLS = Ref(0)
if order == "before"
    @eval module PirateAll
    import ForwardDiff, ..CALLS
    Base.:+(a::ForwardDiff.Dual{T,Float64,3}, b::ForwardDiff.Dual{T,Float64,3}) where {T} =
        (CALLS[] += 1; ForwardDiff.Dual{T}(ForwardDiff.value(a) + ForwardDiff.value(b), ForwardDiff.partials(a) + ForwardDiff.partials(b)))
    end
end
using TraitDifferentialEquations
import TraitWorld
STRICT = TraitWorld.STRICT[]
tier = STRICT ? "strict" : "default"
println("julia ", VERSION, "  tier: ", tier, "  order: ", order)
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
loss(p) = sum(solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), p), Tsit5()).u[end])
p0 = [10.0, 28.0, 8 / 3]
# the reference: the gradient by plain ForwardDiff over the same solver (values only)
g1 = gradient(loss, copy(p0))
check("$order/$tier the first gradient is finite", all(isfinite, g1))
const Tg = ForwardDiff.Tag{TraitDifferentialEquations.Sig{Tuple{Vector{Float64}},Float64},Float64}
const D3 = ForwardDiff.Dual{Tg,Float64,3}
if order == "after"
    n_before = CALLS[]
    r = outcome(() -> (@eval module Pirate
        import ..D3, ..CALLS, ForwardDiff
        Base.:+(a::D3, b::D3) = (CALLS[] += 1; D3(ForwardDiff.value(a) + ForwardDiff.value(b), ForwardDiff.partials(a) + ForwardDiff.partials(b)))
        end; nothing))
    msg = r isa Exception ? sprint(showerror, r) : ""
    g2 = Base.invokelatest(gradient, loss, copy(p0))
    nsolver = CALLS[]; CALLS[] = 0
    a = D3(1.0, ForwardDiff.Partials((1.0, 0.0, 0.0))); Base.invokelatest(+, a, a); nplain = CALLS[]
    check("$order/$tier the gradient is unchanged", g2 == g1)
    if STRICT
        check("after/strict the definition raises a PirateError", r isa TraitWorld.PirateError, r === nothing ? "accepted" : string(typeof(r)))
        println("     message: ", msg)
        # the code named: the CodeInstance after "computes at <sig> (", which should be the solver's
        # (a function of TraitDifferentialEquations or ODECore), not a Base function it reached
        caller = (m = match(r"computes in `([\w.]+)`", msg); m === nothing ? "" : m.captures[1])
        check("after/strict the message names `+`", startswith(msg, "PirateError: strict mode refuses `+("))
        check("after/strict the message names the solver's code (not a Base function under it)",
              occursin(r"ODECore|TraitDifferentialEquations|solve_ode|^step", caller), "names `$caller`")
        check("after/strict the message is short enough to read (< 600 characters)", length(msg) < 600, "$(length(msg)) characters")
        check("after/strict the message says how to proceed", occursin("strict!(false)", msg) || occursin("delegate!", msg))
        check("after/strict the pirate never runs (solver and plain code)", nsolver == 0 && nplain == 0, "solver $nsolver, plain $nplain")
    else
        check("after/default no error at the definition", r === nothing, msg)
        check("after/default the pirate is followed by the solver and by plain code", nsolver > 0 && nplain == 1, "solver $nsolver, plain $nplain")
    end
else
    nsolver = CALLS[]
    check("before/$tier the solver's dual code calls the pirate (followed)", nsolver > 0, "$nsolver calls")
    STRICT && pending("before/strict an error names the pirate when the solver's image loads",
                      "piece 15 (image validation reports the winning method)", "followed silently ($nsolver calls)")
end
# To measure (after (B)): the recompile after the pirate in the default tier (row 8's 373 ms);
# strict mode's check time at the definition.
summary()
