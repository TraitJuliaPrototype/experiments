# E-270 (X4): what `jl_subtype` costs with many entries on a common chain

The work plan's §8, X4, W-98's gate. Registry row: `writeup/record/experiments.md` E-270.

## How to run

```sh
source env.sh
JULIA_NUM_THREADS=1 nice -n 5 julia-vanilla/julia --startup-file=no experiments/unification/x4/x4.jl run1-vanilla
JULIA_NUM_THREADS=1 nice -n 5 julia-unified/julia --startup-file=no experiments/unification/x4/x4.jl run1-unified
```

`x4.jl` declares sets as `@trait` does (opened before their bindings are published).
- On the unified build, k sets each hold an entry for `AbstractVector{T} where T`: BaseTraits' families on `AbstractVector`, k = 0, 1, 10, 50. On vanilla the same sets are plain abstract types, so every question there is an unrelated pair.
- A set-in-set chain of depth 3: `M ∈ C1 ∈ C2 ∈ C3`.
- Each question is asked through `ccall(:jl_subtype)` or `ccall(:jl_isa)`, so nothing folds.
- Per call: ns, the median of 7 rounds of 200,000 calls.
- On the unified build, each question is asked with the pruning by reachability on and off (`jl_set_membership_prune`).

Outputs: `out/<run>-<tree>.txt`. Answers checked separately (`Vector{Int} <: Fam1`, `M <: C3` true; the
non-members false).

## Results (2026-11-06; vanilla 45b6d15e34, `unified` fd800b27b9 and a7ab25d01a; one thread; load 4–9 of 128)

Runs 1–3 were of the build before its last two changes. Runs 4 and 5 are of fd800b27b9 (kept on branch `w98-fd800b27b9`). Run 6 is of the restructured stack's top, a7ab25d01a: the same code, on the twelve changes useful without traits (`writeup/design/julia-changes.md` §7.1); load 3–6.

| Question | vanilla | run 1 (c3f0b4bc11 + the rework) | run 3 (+ the fast path) | runs 4, 5 (+ the memo) | run 6 (a7ab25d01a) |
|---|---|---|---|---|---|
| `Vector{Int} <: Unrel`, a non-member, k = 0 | 14.1 | 50.7 | 20.9 | 23.6, 23.6 | 24.5 |
| the same, k = 10 | 14.1 | 55.8 | 27.4 | 23.6, 24.4 | 24.6 |
| the same, k = 50 | 14.1–14.3 | 72.6 | 45.4 | 23.6, 24.4 | 24.1 |
| `isa([1], Unrel)`, k = 50 | 16.7 | 76.1 | 48.3 | 26.4 | 26.8 |
| `Vector{Int} <: Fam1`, a member, k = 50 | 16.4 (not a member) | 96.7 | 46.4 | 26.4, 26.7 | 26.1 |
| `M <: Unrel`, a non-member at depth 3 | 12.2 | 94.9 | 63.9 | 22.3, 22.3 | 23.2 |
| `M <: C3`, a member through three entries | 12.2 (not a member) | 276.4 | 312.6 | 171.3, 172.0 | 186.8 |
| `Vector{Int} <: Closed`, an unrelated closed type | 14.1 | 13.1–13.7 | 13.3–14.4 | 13.4–13.9 | 13.7–14.4 |

With the pruning off, the numbers of each run are within a few percent of those with it on.

## What it means

- **Against the registered criterion** (a non-member's `<:` above 2× vanilla's for an unrelated pair: pruning and memoization into W-98's gate):
  - the first build failed it at 3.6× (k = 0) to 7.8× (depth 3);
  - the fixed cost came from subtyping's fast path abstaining for every open set, and the cost per entry from the reachability walk;
  - two changes went into W-98: the fast path answers a non-member when no entry of the member's can reach the set, and reachability is memoized per world range (compiler §4.5);
  - the final build is at 1.7× (k = 0 to 50) and 1.8× (depth 3), under the criterion.
- **The pruning alone saves nothing** on this shape: the cost was the reachability walk itself, which the memo removes.
- **Members** cost 25–27 ns, about 1.6× an unrelated question in vanilla. A member through three set-in-set entries costs 171 ns: a positive answer walks the chain, and the criterion does not bound it.
- **Closed types are untouched:** an unrelated closed pair costs what it does in vanilla.
