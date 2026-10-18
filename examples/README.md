# Examples that stress-test the design (session 29)

Small runnable cases for the claims of `writeup/design.md` that had no example (the review
`writeup/reviews/2026-10-18-examples-and-demonstrators.md`, section 4). Each file states the
outcome the design predicts and checks it: PASS, FAIL, or PENDING (waits on a part not built;
does not fail the run). Written to TraitWorld's language only: no view caches, witness tables,
system image, `FactsInterp` switches or `sealed_call`. No timing: each file ends with a
"to measure after (D)" list, not run.

The framing's acceptance cases (S1–S10, the vararg splat, the pirate tiers, G1.16) are in
`../facts/framing/` (README there).

**Running.**
- `jl.sh` runs one Julia process under the shared lock, niced, with `JULIA_TW_VIEWCACHE=0` and
  `JULIA_TW_COMPILER_FACTS=0` (drop the latter once parts (B)+(C) are validated).
- `run_all.sh [filter]` runs everything, logs in `logs/`, one summary line per run.
- First, once: `Pkg.resolve()` in `env/` (HShapes was added to its Manifest by hand).
- `common.jl`: `check`, `pending`, `summary`, and CodeInstance counts by module (`valid_cis`,
  `nlost`) through Julia's reflection.
- `pkgs/`: XFun, XTrig, XLib, XPirate (S9 and the pirate tiers), GShapes, GGeom (the glue
  extension), CoreP, ImplP (a split-core pair), HShapes (64 conformances and a plain twin).

**Status.** Julia runs were stopped by the user's instruction mid-suite (the lock is needed for the
compiler work). "Tested" below means run once on the patched 1.13.2 of session 29 with TraitWorld's
own policy; "untested" files have never run and may need small fixes.

## strict/dual_pirate.jl: strict mode on a real pirate (`+(::Dual)`), both orders

TraitDifferentialEquations' gradient; the pirate `+` on its duals, counting its calls. Uses TDE's `scripts/env`.
- Expected: default tier followed in both orders; strict, after: `PirateError` at the definition,
  naming `+` and the solver's code, the pirate never runs; strict, before: an error at the
  solver's load (piece 15), pending.
- Tested (before the last tightening): default after 4/4, default before 2/2, strict after 6/6,
  strict before 2 pass + 1 pending (followed silently, 2,192 calls).
- **Untested since tightened:** two checks added to "strict, after" on what the message names.
  Expected today: **FAIL**. The message names `Base.afoldl(::typeof(+), ::Dual…, ::Dual…)`, a Base
  function compiled under the facts owner, not the solver's worker. It is 1,400 characters: the
  dual type, about 110 characters, is printed six times. Its hint suggests `delegate!(Core => Impl)`,
  which does not fit a pirate that is no split-core implementation.

## strict/split_core.jl: a split-core pair with and without the delegate

- `nodelegate`: CoreP owns `P2` and `norm1`; ImplP (an image) defines `CoreP.norm1(::P2)`, which wins
  at a fact of trait code. Expected: left inactive at ImplP's load with an error naming it, values
  unchanged in trait and plain code; ImplP's next definition there a `PirateError`.
- `delegate`: the same with ("CoreP", "ImplP") on the curated delegate list. Expected: accepted, followed.
- `staticarrays`: trait code over `SVector` from StaticArraysCore (a `MethodError` without
  StaticArrays: no `size`), then `using StaticArrays`. Expected: accepted (curated pair), then
  the plain value.
- **Untested** (the first run failed on a missing `using TraitWorld`, now fixed).
- Risk to watch, from reading `TraitWorld/src`: the curated delegates are registered *after* a
  package loads (`_on_package_load` → `_strict_known_delegates!`), but an image's methods are
  checked *during* its activation (`_on_image_methods` → `_strict_image_refusals`). If so, the
  `delegate` and `staticarrays` cases fail: StaticArrays' gap-filling methods would be refused at its
  first load under strict mode. `delegate!(Core => Impl)` cannot help, as it takes both modules,
  so it can only be called once the implementation is loaded.

## extension/glue.jl: a glue extension that declares conformances

GShapes' extension on GGeom declares `Shape` for GGeom's `Circle` and `Square`, with a workload.
- Expected: loading GGeom invalidates none of GShapes' code. The conformances work. The extension's
  image holds code for the pair (checked by reflection; pending on (B) if absent).
- **Untested.** Two orders: `shapes-first`, `geom-first`.
- S9 (`../facts/framing/s9_extension.jl`) is the contrast. There, an extension adds a method at a
  fact and invalidates (tested).

## heterogeneous/collections.jl: `Vector{Dynamic{Shape}}` with 2, 4, 16, 64 conformances

HShapes: 64 conformances in its image, and a plain twin (`PShape` with 64 subtypes); 64 more of
each at the prompt.
- Expected: `total` equals plain for every n, image and prompt and mixed; one compiled `total`
  whatever n; 64 prompt conformances invalidate none of HShapes' trait code; the call-site split
  pending on (D).
- **Untested.**
- To measure after (D): per-element time for n = 2…128 against `ptotal`; CodeInstances and image
  bytes per conformance (the "explosion" volume); the first call after prompt conformances.

## errors/definition_errors.jl: errors at definition against deep traces

A small Euler integrator as a trait library (`Mini`) and its plain twin. Five mistakes: a missing
operation, a wrong result type, wrong argument types, a library reading an undeclared field, a
`Float64` cache in a complex model.
- Expected: 1 and 3 at `@implement`, naming the operation and the trait; 2 at `@implement` or the
  first call, naming `Nothing` (plain: silent); 4 at the library's definition (plain: at the first
  call with a type that lacks the field); 5 at run time in both, with no more frames in the trait form.
- **Untested.** Not TraitDifferentialEquations' route A: the solvers agent writes that one.

## warnings/teach.jl: warnings that teach (concrete mode on badly written code)

Six flawed workers under `@warn_on_abstract`, each beside its fixed twin: an abstract field, a
`Dict{Symbol,Any}` read in a loop, a non-const global, a boxed capture, a variable whose type
changes, a type passed as a value.
- Expected: each flawed worker warns at its first call, naming the line and the root cause. Each
  twin is silent. The fix named, and run-time sites per worker, are the fully-typed certificate:
  pending where missing.
- **Untested.**
- Expected today, from reading `concrete.jl`: root causes named (fields, globals, boxes, changing
  types). No fix named in the warning: only `AbstractTypeError` says "Fix the root causes". Case f
  (a kind) is likely silent, since a `DataType` argument is no abstract *value*. It is still a
  run-time site under the facts rule: the certificate must cover it.

## redefinition/prompt.jl: struct redefinition and conformance redeclaration

- Expected: 1, a redefined conforming struct: old values keep the old type and conformance; the
  new type needs its own `@implement`, and before it a `TraitBoundError` naming the bound. 2, a
  conformance redeclared with an override: refused with a message that says why (restart), the old
  conformance in force. 2b, an override as a plain method after the conformance: an
  `ImplementError` naming the operation and a fix. 3, a redefined implementation method is
  followed. 4, redeclaration built like struct redefinition: pending.
- **Untested.**
