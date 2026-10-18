# FactsCompiler: the facts policy as a mode of Julia's compiler (stage 1)

Plan: `../../writeup/plans/2026-10-17-policy-in-compiler-plan.md`, part (A), stage 1.

`Compiler/` is a copy of `julia-1.13/Compiler` (the patched 1.13.2 tree) with the facts rules in
`src/facts.jl`, hooked into `find_method_matches`, `concrete_eval_eligible` and `return_type_tfunc`.
`env/` develops it under Compiler's own name and uuid.

    JULIA_FACTS_COMPILER=1 julia --project=env -e 'using Compiler; Compiler.activate!(; reflection = true, codegen = true); …'

`activate!` bootstraps the copy (about 23 s per session), then sets the mode from
`JULIA_FACTS_COMPILER`, so the compiler's own code stays compiled plainly. Code in the system image
and in package images was compiled plainly and is used as it is: measure with `--pkgimages=no`.

Checks so far: a single-method call at `Any` (`one_method(v[1])`, `v::Vector{Any}`) is typed
`Float64` with the mode off and `Any` with it on; a loop over 10⁶ such calls takes 0.99 ms off,
26 ms on (lesson 1.5 at its worst).

## Go/no-go measurement (plan §3), session 28

BaseBenchmarks (17 groups, 4,342 benchmarks), `scripts/bench.jl` with 0.2 s per benchmark after
tuning, one process per mode, `--pkgimages=no`; `scripts/compare.jl full0 full1` (ratio = facts on /
off, minimum times). One run per mode; ns-scale benchmarks are noisy both ways.

| group | n | geomean | max |
|---|---|---|---|
| array | 756 | 1.035 | 8.1 |
| broadcast | 27 | 1.016 | 1.6 |
| collection | 345 | 1.164 | 81.7 |
| dates | 50 | 1.003 | 1.4 |
| find | 63 | 1.090 | 1.8 |
| io | 10 | 1.318 | 3.8 |
| micro | 8 | 0.997 | 1.0 |
| misc | 42 | 0.982 | 1.1 |
| problem | 19 | 1.158 | 4.4 |
| scalar | 1363 | 0.919 | 4.3 |
| shootout | 12 | 1.075 | 1.7 |
| simd | 680 | 1.021 | 1.6 |
| sort | 135 | 1.118 | 10.3 |
| sparse | 326 | 1.007 | 3.3 |
| string | 22 | 0.987 | 1.1 |
| tuple | 50 | 1.004 | 1.1 |
| union | 434 | 1.160 | 12.0 |
| **all** | 4342 | **1.016** | |
| without scalar | 2979 | 1.064 | |
| benchmarks ≥ 1 µs | 1920 | 1.060 | |

232 benchmarks slower by more than 20%, 81 by more than 2×, 14 by more than 10×; 219 faster by
more than 20% (mostly `scalar`, ns-scale). The tails:
- **Containers of `Any`** (`collection`: `filter!`, `push!` loops, `Dict`/`IdDict` iteration on
  `Any`, 17–82×): a call with an `Any` argument (`push!(::Vector{Any}, ::Any)`) is no fact, though
  one method matches; every element goes through dynamic dispatch.
- **Abstract element types with a common result type** (`problem/raytrace` 3.5×: `intersect(j::Scene, …)`
  returns `Hit` for every method; under facts the result is `Any` and the loop turns dynamic),
  `problem/json` 4.4×, `io/serialization` 3.8×, `sort` with mixed element types 5×.
- **Small-union broadcasts** (`union/array` broadcast over `Union{Missing, Int8/Bool}`, 5–12×).
- `array/index` sums over ranges, 3 → 25 ns: to be looked at (probably a fold plain Julia makes).

Limitation (plan R4): Base's code in the system image was compiled plainly and is used as it is.

## Next steps of plan §3 (session 28)

**`return_type` step 2** (plain inference in its own cache owner, `PlainRTInterp`, merged over the
concrete splits of the signature, folded with an edge per split when every answer rests on facts):
`Union{Missing, Int8}` broadcast `x .* x` (1000 elements) 148 ns plain, 33.9 µs facts before,
**162 ns** after; `combine_eltypes` and `copy` infer exactly as plain.

**`array/index` range sums** (3 → 25 ns in the suite): harness overhead, not kernel cost. Called
directly, `perf_sumelt(1:100000)` takes 2.0 ns plain and 2.0–2.7 ns facts.

**Recovery** (`recovery/recovery.jl`, `recovery/RTTrait.jl`; best of 5 or 200 runs):

| benchmark | variant | plain | facts |
|---|---|---|---|
| raytrace | original | 249 ms | 881 ms |
| | `::Hit` on the three `intersect` results | 251 ms | 586 ms |
| | `objs::Vector{Union{Sphere, Group}}` (a sealed set, written out) | 268 ms | **273 ms** |
| | `Scene` as a trait, `objs::Vector{Dynamic{Scene}}` | 801 ms | 776 ms |
| parse_json | original | 303 µs | 1394 µs |
| | values in a concrete wrapper (`Dynamic`'s analogue) | 303 µs | 1361 µs |
| | `local pos::Int = 1` (julia#15276's standard fix) | 152 µs | **178 µs** |

- The assertion recovers half of raytrace: plain Julia turns `intersect(j::Scene, …)` with its
  two methods into `isa` branches with direct calls; facts mode refuses that split, since the set of
  methods is open.
- The trait version costs nothing under facts (776 against 801 ms), but `Dynamic` dispatch at
  about 15–20 ns per call makes it 3× slower than plain's `isa` branches in this hot recursion.
- The trait version needed TraitWorld's functions exempted as *sealed* (`sealed_call` in
  `src/facts.jl`): the entry on a `Dynamic` calls the machinery at abstract types, which
  TraitWorld's own interpreter exempts (`_machinery_call`). The general form: a function whose
  methods only its owner may add is sealed, and calls of it at abstract types are facts.
- `parse_json` is a captured, reassigned variable (`Core.Box`): every call has an `Any`
  argument, and plain Julia still types the single-method ones. Plain Julia's own fix removes it
  under facts too.

## Witness tables for `Dynamic` (TraitWorld, session 28)

`recovery/dynmicro.jl`: sum of `area` over a vector of shapes, ns per element (`N` elements);
`JULIA_TW_WITNESS=0` is the old path (two dynamic dispatches per call).

| | N = 10⁶ | N = 1000 |
|---|---|---|
| plain `Vector{QShape}`, 2 methods (`isa` branches, inlined) | 3.8 | 0.87 |
| plain `Vector{PShape}`, 4 methods (dynamic dispatch) | 32–35 | 25.5 |
| `Vector{Dynamic{Shape}}`, old path | 23–26 | |
| `Vector{Dynamic{Shape}}`, witness tables | 14–17 | **6.6** |
| `Erased` call (a function pointer, for scale) | 4.1 | |

Trait raytrace (`recovery/RTTrait.jl`, TraitWorld's policy): 801 → 669 ms; plain original 249 ms.
About 80 million `intersect` calls per run, so 5–6 ns per call is the whole remaining gap: plain
Julia's two-method `isa` branches are inlined, a witness call cannot be. At 10⁶ values a second
pointer to chase (the boxed trait object, then the user's object) adds about 8 ns.

## Key branches at `Dynamic` call sites (TraitWorld, session 28)

A call on a `Dynamic` tests the keys known when the caller is compiled: the trait-object types of
the conformances declared so far (noted at each declaration and package load) and of values made.
Each is an exact type test, then the user's method called with the representation, inlined. Other
keys take the witness call. Definition checks now infer in their own cache owner, so they no longer
fix callers' code before conformances exist.

| | N = 10⁶ | N = 1000 |
|---|---|---|
| plain, 2 methods (`isa` branches) | 3.8 | 0.89 |
| plain, 4 methods (dynamic dispatch) | 31 | 27.6 |
| `Dynamic`, before witness tables | 23–26 | |
| `Dynamic`, witness tables | 14–17 | 6.6 |
| `Dynamic`, key branches | **10.9** | **2.05** |

Trait raytrace: 801 ms (old path), 669 (witness), **498–505 ms** (key branches) in all three
configurations (TraitWorld's policy; compiler copy with facts off or on); plain original 249 ms;
allocations equal to plain (3.7 against 3.2 MB at a small size, from 51 MB). What is left is one
call per element: Julia does not inline members of a recursion cycle into each other, and the
branches sit in a TraitWorld function on the recursion's path (plain Julia's branches sit in the
caller). In the compiler version, the inliner can split a call on a `Dynamic` at the call site, as it
splits unions.

Pitfalls met on the way:
- a generated function's expansion is cached once per signature: keys read inside one were fixed
  at the first expansion (TraitWorld's definition check). The keys now enter the signature
  (`_dyn_call_keyed`), read by `_dyn_keys_now` at compile time;
- constant propagation re-infers a callee per call site only for constant arguments, so a call
  `intersect(j, i, ray)` keeps the callee's first inference; hence keys from *declarations*, which
  exist when the call tree is compiled, not from values, which are made while it runs;
- `_dyn_keys_now` is asserted foldable: when it threw at compile time (nested inference),
  inference took the call as throwing (`Unreachable reached` at run time); it now reads registries only;
- in a recursion cycle every TraitWorld function on the path was a separate call, and the varargs
  splat into `_dispatch` boxed every argument (4.6 GB): the direct branch avoids that machinery.
