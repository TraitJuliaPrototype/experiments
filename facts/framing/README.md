# The framing's acceptance cases (session 29)

Steps 1–3 of `writeup/design.md` §3 as runnable files, each stating its expected outcome and
checking it (PASS / FAIL / PENDING; a pending check waits on a part not built and does not fail
the run). Helpers: `../../examples/common.jl`. Run all: `../../examples/run_all.sh` (logs in
`../../examples/logs/`). Every run: patched 1.13.2, `JULIA_TW_VIEWCACHE=0`, and
`JULIA_TW_COMPILER_FACTS=0` until parts (B)+(C) are validated (`../../examples/jl.sh`).

Julia runs stopped by the user's instruction mid-suite; every file here ran at least once except
`pirate_tiers.jl binding` in the default tier.

"Today" is session 29, julia-1.13 at 880ae49dad plus the parent's (B)+(C) work in progress,
TraitWorld c6e3f64 plus uncommitted changes, TraitWorld's own policy on.

## `inval_cases.jl`: which definitions invalidate (S1–S8, S1b, S1c, S10)

Plain code, no TraitWorld. Run plain and with `JULIA_COMPILE_BY_FACTS=1`.

| case | definition | expected plain | expected facts | today |
|---|---|---|---|---|
| S1 | an owner's method at an abstract call (one match) | invalidates | no | as expected |
| S1b | `Base.show(io, ::MyIrr)` against a caller at `show(::IOBuffer, ::AbstractIrrational)` | invalidates | no | as expected |
| S1c | the same hook against a caller at `show(::IOBuffer, ::Any)` | no | no | as expected |
| S2 | a new subtype under union splitting | invalidates | no | as expected |
| S3 | a `return_type`-dependent `map` | invalidates | no | as expected |
| S4 | a stakeholder's method at a concrete fact | invalidates | invalidates | as expected |
| S5 | a winning pirate | invalidates | invalidates | as expected |
| S6 | a losing pirate | no | no | as expected |
| S7 | the owner redefines a `const` | invalidates | invalidates | as expected |
| S8 | a new type at a kind | invalidates | no | as expected |
| S10 | another module redefines a `const` | invalidates | invalidates | as expected; strict tier pending (no rule, no hook for bindings) |

20 pass, 1 pending in both modes.

**Finding (S1c).** On 1.13 a call with more matching methods than `max_methods` records no edge
at all. So `Base.show(io, ::MyType)` does not invalidate a caller at `show(::IO, ::Any)`. It does
invalidate callers at narrow abstract signatures (S1b). `design.md` §2's sentence "every caller
compiled at `show(::IO, ::Any)`-shaped signatures" should say "at abstract signatures where few
methods match". (A first version of S1b put the call behind `sprint(show, x)`: then only
`sprint`'s own specialization at `Any` holds the edge.)

## `vararg_splat.jl`: a splat of many arguments (Julia's core.jl, issue #10981)

`vcat(xs...)` with 3,000 arguments. Julia compiles `vcat` at its widened signature
`Tuple{typeof(vcat), Int, Int, Int, Vararg{Int}}`, not concrete.
- Expected if a Vararg tail of a concrete element type is a fact signature: the same code in both modes.
- Today: plain has no run-time sites (result `Vector{Int64}`); facts mode has 10 (`eachindex`,
  `IteratorSize`, `_array_for`, …; result `Any`). Each run-time dispatch looks at the whole tuple,
  so core.jl's 2·10^6 arguments do not finish.
- **Pending on a design decision** (rule 1: is `Tuple{Vararg{T}}` with concrete `T` a fact signature?).
- To measure after the decision: time per argument at 10^3–10^5 in both modes; core.jl #10981 in facts mode.

## `s9_extension.jl`: the extension exception (S9)

XFun owns `score`; XLib's worker (in its image) calls `score(::Float64)`. XFun's extension on the
unrelated XTrig defines `score(::Float64)`.
- Expected: followed (identical to plain Julia), XLib's code invalidated, in both tiers (the
  extension counts as XFun, a stakeholder). Whether strict mode should refuse it: open (§1.10).
- Today: as expected in both tiers (1 of 23 XLib CodeInstances lost); the strict-tier rule pending.

## `pirate_tiers.jl`: a winning pirate in each order, both tiers

XLib's `wtotal` calls `XFun.weight(::Float64)`; the pirate `XFun.weight(::Float64) = 3.0`.

| order | default tier (expected: followed) | strict tier (expected) | strict today |
|---|---|---|---|
| after (package image) | followed, 1 CodeInstance lost | left inactive at load, error names method and worker | as expected |
| prompt-after | followed | `PirateError` at the definition | as expected |
| before (package image) | followed | an error at XLib's load (piece 15) | **pending**: followed silently |
| prompt-before | followed | an error at XLib's load (piece 15) | **pending**: followed silently |
| binding (S10 for trait code) | followed, code invalidated (**untested**: the run failed on a missing `using TraitWorld`, since fixed) | refused or named | **pending**: accepted silently (value followed, 1 of 19 CodeInstances lost) |

The strict message today: "strict mode refuses weight(x::Float64) @ XPirate …: it would change
what trait-world code computes at Tuple{typeof(XFun.weight), Float64} (CodeInstance for
MethodInstance for wtotal(::Vals at Vector{Float64})), and XPirate owns neither …".
It names the method, the signature and the worker, by bound and key. At the prompt the definer is "Main".

## `g1_16_dynamic_world.jl`: a `Dynamic` operation in an older world (G1.16)

Five conformances, `tsum` over `Vector{Dynamic{Shape}}`; two implementations redefined; calls
pinned to the older world; a conformance declared later.
- Expected: the older world sees the old methods (15.0), the latest the new (609.0); a later
  conformance is seen in the latest world only.
- Today: 6/6 pass (witness tables off by default). Part (D) must keep it passing.
