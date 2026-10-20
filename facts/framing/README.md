# The framing's acceptance cases (session 29)

Steps 1–3 of `writeup/design.md` §3 as runnable files, each stating its expected outcome and
checking it (PASS / FAIL / PENDING; a pending check waits on a part not built or a decision and
does not fail the run). Helpers: `../../examples/common.jl`. Run all: `../../examples/run_all.sh`
(logs in `../../examples/logs/`). Every run: patched 1.13.2, one process at a time under the lock
(`../../examples/jl.sh`).

Every file has run. "Today" below is the run of 2026-10-20 (00:45, the patched 1.13.2 of that
night; logs in `../../examples/logs/`): no check fails.

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
- Decided: a concrete `Vararg` tail is a fact signature (`writeup/reference/facts.md` §3,
  Fact signatures).
- Today (`vararg-plain.log` 3/3, `vararg-facts.log` 4/4): no run-time sites in either mode, result
  `Vector{Int64}`. (In session 29, before the decision, facts mode had 10 run-time sites and
  result `Any`.)
- To measure: time per argument at 10^3–10^5 in both modes; core.jl #10981 in facts mode.

## `s9_extension.jl`: the extension exception (S9)

XFun owns `score`; XLib's worker (in its image) calls `score(::Float64)`. XFun's extension on the
unrelated XTrig defines `score(::Float64)`.
- Expected: followed (identical to plain Julia), XLib's code invalidated, in both tiers (the
  extension counts as XFun, a stakeholder). In strict mode a warning names the method and the trait
  code it affects (decided 2026-10-20, `writeup/reference/traits.md` §12.3).
- Today (`s9-default.log`, `s9-strict.log`, 6/6 each): as expected in both tiers (2 of 28 XLib
  CodeInstances lost). The default tier is silent; strict mode warns, naming `XFunXTrigExt`, the
  signature and the trait code.

## `pirate_tiers.jl`: a winning pirate in each order, both tiers

XLib's `wtotal` calls `XFun.weight(::Float64)`; the pirate `XFun.weight(::Float64) = 3.0`.

| order | default tier (expected: followed) | strict tier (expected) | strict today |
|---|---|---|---|
| after (package image) | followed, 2 of 28 CodeInstances lost | left inactive at load, error names method and worker | as expected |
| prompt-after | followed | `PirateError` at the definition | as expected |
| before (package image) | followed | an error at XLib's load (piece 15) | **pending**: followed silently |
| prompt-before | followed | an error at XLib's load (piece 15) | **pending**: followed silently |
| binding (S10 for trait code) | followed, code invalidated (as expected: 2 of 22 lost) | refused or named | **pending**: accepted silently (value followed, 2 of 22 CodeInstances lost); waits on a rule for bindings and a hook that sees them (`writeup/open-issues.md` §1.1) |

The before orders wait on piece 15 (image validation reports the winning method).

The strict message today: "PirateError: strict mode refuses `weight(Float64)`, defined by XPirate.
It would change what trait-world code computes in `XLib.XCore.wtotal`, at the call
`Tuple{typeof(weight), Float64}`. XPirate owns neither the function nor a type in that signature
(a pirate). Turn strict mode off (`TraitWorld.strict!(false)`) …". It names the method, the
definer, the trait code and the call. At the prompt the definer is "Main".

## `g1_16_dynamic_world.jl`: a `Dynamic` operation in an older world (G1.16)

Five conformances, `tsum` over `Vector{Dynamic{Shape}}`; two implementations redefined; calls
pinned to the older world; a conformance declared later.
- Expected: the older world sees the old methods (15.0), the latest the new (609.0); a later
  conformance is seen in the latest world only.
- Today: 6/6 pass, with part (D) built (witness tables are deleted).
