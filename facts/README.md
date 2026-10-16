# Evidence for "wrapping by facts" (session 23, 2026-10-16)

Design: `writeup/explorations/wrapping-by-facts.md` in the design repository. Stock Julia 1.13.2, niced, serialized through the session's Julia lock.

## E3: is stock invalidation exact at concrete signatures? (`e3_exact.jl`)

A caller `g(x::Float64) = f(x) + 1` holds the fact "`f` at `Tuple{Float64}` selects `f(::Real)`". Each case defines one new method:

| new method | changes plain Julia's result | invalidated |
|---|---|---|
| `f(::Number)` (less specific) | no | no |
| `f(::Int8)` (does not apply) | no | no |
| `f(::String)` (does not apply) | no | no |
| `f(::Float64)` | yes | yes |
| `f(::AbstractFloat)` | yes | yes |
| `f(::Union{Float64,Int8})` | yes | yes |
| `h(::Real, ::Any)` against `h(::Real, ::Real)` (loses) | no | no |
| `h(::Float64, ::Any)` and `h(::Any, ::Float64)` (ambiguous) | yes (error) | yes |
| `h(::Float64, ::Real)` | yes | yes |

**Result:** exact in all nine cases. A definition invalidates code at a concrete signature if and only if it wins there or makes the call ambiguous. Rule P needs no runtime predicate.

## E1 and E2: the demonstrators' closure, with CSV, DataFrames and CairoMakie loaded first (`e12_closure.jl`)

**Setup:**
- run TraitDifferentialEquations (Tsit5 with a callback, Rodas5) and TraitMakie (lines, scatter, save);
- collect every CodeInstance reachable through edges from the trait modules' code (ODECore, PlotCore and their conformance methods);
- classify the edges as concrete facts (a MethodInstance at a concrete signature) or abstract facts (match sets at non-concrete signatures, or MethodInstances at abstract signatures).

**Closure:** 3,533 CodeInstances; 3,043 concrete facts; 207 abstract facts (6%).

**E2:**
- Pirates from outside Julia that dispatch currently selects at a concrete fact: **0**.
- The stack brings OffsetArrays' 12 pirates of Base, plus StatsBase's and Durations'. None of them wins at any signature the demonstrators' code uses.

**E1:**
- **Where the abstract facts sit:** 42 methods hold them, and 6 of those were sampled at all over 30 runs of the work (94,426 samples).
- **The only one with a measurable share** is TraitWorld's declared-call path (`@call`, Cairo), at 1,500 samples (1.6%): an `invokelatest` result passed to `_wrap_result`. Under the facts design Cairo calls become ordinary direct calls, so this site disappears.
- **The other five** are TraitWorld machinery building `Dynamic` values (`_carries`, `_decode_traits`, the `Dynamic` constructors): 2 samples each, cold.
- **The remaining abstract facts were never sampled.** They are TraitWorld machinery (entries at `Any`, `Dynamic` operations, `_rep`/`_loadpart` on the object held as `Any`) and reflection or printing paths in Base (`_uniontypes`, `print` of types, `collect` of type variables).

## E0 (earlier): what invalidated ODECore (`../review-s23/invalidation_chains.jl`)

With CSV, DataFrames and CairoMakie loaded after TraitDifferentialEquations, the two chains that reached ODECore started at abstract edges:
- `TraitWorld._show_key(::IOBuffer, ::Any)`, the machinery's printing;
- `promote_type(::Type{Int64}, ::Type)`.

No chain started at a concrete fact.

## Reading

- **E3** confirms rule P on stock Julia: no runtime predicate is needed for exactness.
- **E2** finds no winning pirates in this stack, so following plain Julia (the core, without the strict mode) costs nothing here.
- **E1** finds abstract sites only in cold or machinery paths. The demonstrators' hot loops are concrete facts.

Limits:
- **Two small libraries, one stack of packages.** E2 should be repeated with larger trait-world code (more of Base used) and other stacks.
- **"Hot" here means sampled time in the demonstrators' workloads,** not per-element loops in general.
- **Under R, the abstract sites of the machinery would be dynamic calls.** The entries already are dynamic for untyped callers, so this changes little.
