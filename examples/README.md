# Examples that stress-test the design (session 29)

Small runnable cases for the claims of `writeup/design.md` that had no example (the review
`writeup/reviews/2026-10-18-examples-and-demonstrators.md`, section 4). Each file states the
outcome the design predicts and checks it: PASS, FAIL, or PENDING (waits on a part not built
or a decision; does not fail the run). Written to TraitWorld's language only: no view caches, witness tables,
system image, `FactsInterp` switches or `sealed_call`. No timing: each file ends with a
"to measure" list, not run.

The framing's acceptance cases (S1–S10, the vararg splat, the pirate tiers, G1.16) are in
`../facts/framing/` (README there).

**Running.**
- `jl.sh` runs one Julia process under the shared lock, niced. It still sets `JULIA_TW_VIEWCACHE=0`
  and `JULIA_TW_COMPILER_FACTS=0`; nothing reads them any more (view caches and TraitWorld's own
  policy are deleted).
- `run_all.sh [filter]` runs everything, logs in `logs/`, one summary line per run.
- First, once: `Pkg.resolve()` in `env/` (HShapes was added to its Manifest by hand).
- `common.jl`: `check`, `pending`, `summary`, and CodeInstance counts by module (`valid_cis`,
  `nlost`) through Julia's reflection.
- `pkgs/`: XFun, XTrig, XLib, XPirate (S9 and the pirate tiers), GShapes, GGeom (the glue
  extension), CoreP, ImplP (a split-core pair), HShapes (64 conformances and a plain twin).

**Status.** Every file has run. The logs in `logs/` are from the run of 2026-10-21 (julia-1.13
711484a23e, TraitWorld 8d29f20, the product setting, not `all`): no file has a failing check, after
two stale examples were brought to the current design (`pkgs/ErasedP` in the spelling of
`Dynamic{Callable}`; `ahead/check.jl` expecting no entry method per type). The checks still pending
are listed with each file, with what they wait on.

## strict/dual_pirate.jl: strict mode on a real pirate (`+(::Dual)`), both orders

TraitDifferentialEquations' gradient; the pirate `+` on its duals, counting its calls. Uses TDE's `scripts/env`.
- Expected: default tier followed in both orders; strict, after: `PirateError` at the definition,
  naming `+` and the solver's code, the pirate never runs; strict, before: an error at the
  solver's load (piece 15), pending.
- Run of 2026-10-20 (`logs/dual-*.log`): default after 4/4, default before 2/2, strict after 8/8,
  strict before 2 pass + 1 pending.
- Strict, after: the message names `+` and the solver's code
  (`TraitDifferentialEquations.ODECore.tsit5_step!`), not a Base function under it. It is 565
  characters (the dual type is shortened), and it says how to proceed (`TraitWorld.strict!(false)`,
  or define the method where a type it is for is owned).
- **Pending:** strict, before. It waits on piece 15 (image validation reports the winning method).
  Today the pirate is followed silently (2,192 calls).

## strict/split_core.jl: a split-core pair with and without the delegate

- `nodelegate`: CoreP owns `P2` and `norm1`; ImplP (an image) defines `CoreP.norm1(::P2)`, which wins
  at a fact of trait code. Expected: left inactive at ImplP's load with an error naming it, values
  unchanged in trait and plain code; ImplP's next definition there a `PirateError`.
- `delegate`: the same with ("CoreP", "ImplP") on the curated delegate list. Expected: accepted, followed.
- `staticarrays`: trait code over `SVector` from StaticArraysCore (a `MethodError` without
  StaticArrays: no `size`), then `using StaticArrays`. Expected: accepted (curated pair), then
  the plain value.
- Run of 2026-10-20 (`logs/split-*.log`): `nodelegate` 6/6, `delegate` 5/5, `staticarrays` 3/3.
  ImplP's winning method is left inactive at its load, with an error naming `norm1(P2)` and
  `Main.PLib.n1`.
- The risk read from `TraitWorld/src` in session 29 (curated delegates registered after the image
  check, so StaticArrays refused at its first load under strict mode) did not happen: loading
  StaticArrays leaves nothing inactive.

## extension/glue.jl: a glue extension that declares conformances

GShapes' extension on GGeom declares `Shape` for GGeom's `Circle` and `Square`, with a workload.
- Expected: loading GGeom invalidates none of GShapes' code. The conformances work. The extension's
  image holds code for the pair (checked by reflection; pending on (B) if absent).
- Run of 2026-10-20, both orders (`logs/extension-glue*.log`): `shapes-first` 7/7 (0 of 25 of
  GShapes' CodeInstances lost), `geom-first` 5/5. The extension's image holds 5 CodeInstances for
  the pair before the first call.
- S9 (`../facts/framing/s9_extension.jl`) is the contrast. There, an extension adds a method at a
  fact and invalidates.

## heterogeneous/collections.jl: `Vector{Dynamic{Shape}}` with 2, 4, 16, 64 conformances

HShapes: 64 conformances in its image, and a plain twin (`PShape` with 64 subtypes); 64 more of
each at the prompt.
- Expected: `total` equals plain for every n, image and prompt and mixed; one compiled `total`
  whatever n; 64 prompt conformances invalidate none of HShapes' trait code.
- Run of 2026-10-20 (`logs/heterogeneous.log`): 12 pass, 1 pending. 0 of 647 of HShapes' trait
  CodeInstances lost to 64 prompt conformances.
- **Pending:** the check that `area(d)` in `total` is split over the declared implementations.
  Part (D), the call-site split, is built (`writeup/state.md`); what is missing is a check that
  reads the split from `total`'s compiled code. The split covers the first four registered
  implementations; the others reach the fallback (`writeup/reference/compiler.md` §4.2).
- To measure (not run here): per-element time for n = 2…128 against `ptotal`; CodeInstances and
  image bytes per implementation (the "explosion" volume); the first call after prompt
  implementations. The current numbers for a sum over `Dynamic{Shape}` with 2 and 4 types are in
  `writeup/design/evidence.md`.

## errors/definition_errors.jl: errors at definition against deep traces

A small Euler integrator as a trait library (`Mini`) and its plain twin. Five mistakes: a missing
operation, a wrong result type, wrong argument types, a library reading an undeclared field, a
`Float64` cache in a complex model.
- Expected: 1 and 3 at `@implement`, naming the operation and the trait; 2 at `@implement` or the
  first call, naming `Nothing` (plain: silent); 4 at the library's definition (plain: at the first
  call with a type that lacks the field); 5 at run time in both, with no more frames in the trait form.
- Run of 2026-10-20 (`logs/errors.log`): 8/8. Mistakes 1 and 3 are caught at `@implement`, naming
  `rhs!` and its declared signature; 2 at `@implement`; 4 at the library's entry; 5 at run time in
  both, with one frame more in the trait form (22 against 21).
- Not TraitDifferentialEquations' route A: the solvers agent writes that one.

## warnings/teach.jl: warnings that teach (concrete mode on badly written code)

Six flawed workers under `@warn_on_abstract`, each beside its fixed twin: an abstract field, a
`Dict{Symbol,Any}` read in a loop, a non-const global, a boxed capture, a variable whose type
changes, a type passed as a value.
- Expected: each flawed worker warns at its first call, naming the line and the root cause. Each
  twin is silent. The fix named, and run-time sites per worker, are the fully-typed certificate:
  pending where missing.
- Run of 2026-10-20 (`logs/warnings.log`): 37 pass, 1 pending. Cases a, b, c, d and f warn at the
  first call, naming the line, the root cause and a fix; each twin is silent. The certificate
  reports the fixed workers fully typed and lists the flawed workers' run-time sites.
- **Pending:** case e (a variable whose type changes) is silent. It waits on a design decision:
  a variable of a small `Union` is fully typed, since the union's splits are facts; whether
  concrete mode should warn about it (`writeup/open-issues.md` §1.18).

## redefinition/prompt.jl: struct redefinition and conformance redeclaration

- Expected: 1, a redefined conforming struct: old values keep the old type and conformance; the
  new type needs its own `@implement`, and before it a `TraitBoundError` naming the bound. 2, a
  conformance redeclared with an override: refused with a message that says why (restart), the old
  conformance in force. 2b, an override as a plain method after the conformance: an
  `ImplementError` naming the operation and a fix. 3, a redefined implementation method is
  followed.
- Run of 2026-10-20 (`logs/redefinition.log`): 15 pass, 1 pending.
- **Pending:** 4, a redeclaration built like struct redefinition. Redeclaration is Planned
  (`writeup/reference/traits.md` §5.10); today a second declaration is refused in every form.

## imageptr/: values kept in a package image

- `check.jl`: a `Dynamic{Callable}` kept as a constant in a package image (`pkgs/ErasedP`), called in a new session: its pointer is made again, not called (`_PtrCell`).
- `split_table.jl` (2026-10-21): a split's table kept in a package image. HShapes' `total` is compiled in its workload over 64 implementations, so the table of its split's last branch is filled while the image is built (julia-1.13 711484a23e, compiler §4.3). Expected: in a new session the table counts as empty, fills again, and gives the right sum; the session makes no table of its own for the signature (the image's code is the one that runs); once filled, a call allocates nothing.
- Run of 2026-10-21 (`logs/imageptr-split.log`): 3 pass.

## threads/split_tables.jl: the tables under threads

Several threads meet 24 implementations for the first time at the same call sites: a split beyond its four (its table's misses race to add entries) and `compiled_for` from an untyped caller (the table of declared implementations). Expected: every sum right, and each split table holding every type beyond the split once. Run with `-t 4`.
