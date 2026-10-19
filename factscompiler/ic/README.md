# Inline caches at dynamic call sites (`writeup/plans/2026-10-19-inline-caches-plan.md`)

## Stage 0: where a dynamic call's time goes (`sites.jl`, rough timings, 2026-10-19)

| site | plain | `all`, before | `all`, stage 1 |
|---|---|---|---|
| `ar(x)`, one type, result asserted | 13.2 ns | 13.0 ns | 14.7 ns |
| `ar(x)`, four types, result asserted | 16.3 ns | 16.8 ns | 16.6 ns |
| `ar(x)`, four types, result untyped | 32.9 ns | 32.7 ns | 35.1 ns |
| `push!(::Vector{Any}, x)` | 1.7 ns (inlined) | 69.3 ns | **14.0 ns** |

- A dispatch to an ordinary method costs the same plain and under facts (13–17 ns): the facts mode's own dispatch adds nothing.
- The tail is the call to a method whose cache entry is not a leaf signature (Base's `push!(a::Vector{Any}, @nospecialize x)`). Julia's per-call-site cache (`call_cache` in `gf.c`) holds leaf signatures only, so every such call did a full lookup in the method cache.

## Stage 1: exact-type entries in the per-call-site cache (`src/gf.c`, `call_cache_exact`)

- **When a call's cache entry is not a leaf signature,** the site gets an entry for the exact argument types, mapping to the same method instance.
- **The entry is valid** from the cache entry's first world up to the latest world at that moment. A later world misses and looks up again, so the copy never outlives the entry it copies; invalidation lowers that entry's `max_world`.
- **Matching** is by exact types only (`sig_match_fast`). Calls with a type as an argument are skipped.
- **A C-only change:** the libraries rebuild in about 10 s.

**Results:**
- `push!` on `Vector{Any}` under `all`: 69.3 → 14.0 ns.
- The quick BaseBenchmarks subset (148 benchmarks), against the run of the morning:
  - under `all`, geomean 0.93: `collection` 0.60, with some benchmarks up to 20× faster; `problem` 0.83;
  - plain, 0.99.
- The `all`/plain geomean of the subset is 1.85 (it was 1.97). The remaining tails: `filter!` on `Vector{Any}` 27×, on `IdDict` 21×, and the `sumrange_view` family (an inlining question, not dispatch).
- One `sort` outlier (33 ms) was a single noisy sample: rerun alone it measured 110–2,816 ns, against 658. The quick subset's short budget gives single samples for some benchmarks.
- Acceptance G1.22: a site cached for a `@nospecialize` method, then a redefinition. The older world sees the old method, the latest the new one.
