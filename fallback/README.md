# What follows the `Dynamic` split (E-145, 2026-10-21)

The question (registry E-145, open issues item 32): an operation on a `Dynamic` value is split at the call site over the first four implementations declared, and a value of any other type takes Julia's dynamic dispatch. What should that last branch be?

The options, each emulated in plain Julia beside TraitWorld's own `Dynamic`:

| Row | What it is |
|---|---|
| `any` | plain Julia: the operation over a `Vector{Any}` (dispatch only) |
| `tw` | TraitWorld's `Dynamic` as built: split over the first four, then Julia's dispatch |
| `s4+dyn` | the same, emulated (checks the emulation against `tw`) |
| `sall` | a split over every type the mix holds (a longer split) |
| `s4+pic` | split 4, then a per-site cache of 8 (type, pointer) pairs, refilled round robin (e145 only) |
| `s4+hash` | split 4, then a table per trait from the type to a witness object (three dependent loads) |
| `s4+tab` | split 4, then a table per call signature: (type address, pointer) side by side, one probe (e145c) |
| `s4+wit` | split 4, then a witness carried in the value: `(object, witness)`, Rust's fat pointer, Swift's existential |
| `s4+witp` | the same with plain `cfunction` pointers, to price the world check (e145 only) |
| `s4+idx` | split 4, then an index carried in the value into the trait's vector of pointers (e145 only) |
| `wit`, `tab` | the witness or the table alone, no split |
| `hot+wit` | a split over the (up to 8) types the mix holds most often, then the witness: the code a recompilation with observed types would produce |

Every pointer is a `:caller_world` `cfunction` (julia-1.13 piece 18) taking the boxed object and returning a `Float64`. The world check runs on every call.

## How to run

From this directory, one job at a time (the shared lock, `nice -n 19`, a depot of its own):

    ./run.sh product --project=. e145.jl                      # one multiply on 64 types of one layout
    ./run.sh product --project=. e145b.jl                     # 64 types of eight layouts and formulas; `area` and `work`
    E145_N=131072 ./run.sh product --project=. e145b.jl       # the same over 131072 values
    ./run.sh product --project=. e145c.jl                     # the table per signature; the first pointer per type
    E145_QUICK=1 …                                            # a smoke run, three samples per row

`common.jl` (from `../hetero-idiomatic`): one row = the median time per element over BenchmarkTools' samples (up to 1000 samples or 1 s), and the median allocation.

## The build and the runs

- julia-1.13 f13117cd74 (the build in the tree, product setting, strict mode off); TraitWorld a747d4a.
- The machine was quiet: load 0.3 to 1.2 at the start and end of each log.
- One process per script and size. Logs: `logs/r1-product.log` (e145), `logs/r2-product-n1000.log` and `logs/r2-product-n131072.log` (e145b), `logs/r3-product-n1000.log` and `logs/r3-product-n131072.log` (e145c).
- The mixes are uniform over the first n types (random order, fixed seed), skewed (90 % T5, outside the split), cyclic (predictable order) and phases (two halves of different types outside the split).
- Two sizes:
  - 1000 values stay in the cache, but a branch predictor can learn a sequence repeated each sample, which flatters splits;
  - 131072 values defeat that, and add a cache miss per boxed object.

## Results (2026-10-21)

**e145b, `area` (one to three flops on the type's fields), ns per element, 1000 values / 131072 values:**

| Mix | `tw` (as built) | `sall` | `s4+hash` | `s4+wit` | `wit` | `hot+wit` |
|---|---|---|---|---|---|---|
| uniform 5 | 4.5 / 16.7 | 1.5 / 10.3 | 2.6 / 12.5 | 2.2 / 12.6 | 11.5 / 14.5 | 1.4 / 10.7 |
| uniform 8 | 11.8 / 31.5 | 1.7 / 13.7 | 6.6 / 18.9 | 5.1 / 19.7 | 12.7 / 17.6 | 1.7 / 15.2 |
| uniform 16 | 46.8 / 62.7 | 2.4 / 16.1 | 12.3 / 22.6 | 9.6 / 20.5 | 13.4 / 18.3 | 4.1 / 25.0 |
| uniform 64 | 77.0 / 84.2 | 3.1 / 21.0 | 22.3 / 35.7 | 15.6 / 22.4 | 14.7 / 20.8 | 12.4 / 28.8 |
| skewed 64 | 32.2 / 36.3 | 2.0 / 5.2 | 10.0 / 11.2 | 7.4 / 12.8 | 7.1 / 11.7 | 2.4 / 7.2 |
| cyclic 64 | 80.7 / 89.1 | 2.9 / 5.7 | 10.1 / 13.4 | 6.9 / 12.1 | 6.7 / 11.2 | 7.5 / 11.3 |
| phases 64 | 55.2 / 66.7 | 1.9 / 13.6 | 18.5 / 23.0 | 15.3 / 17.4 | 12.9 / 15.8 | 4.8 / 18.2 |

**e145b, `work` (a loop of eight `sqrt`), ns per element, 1000 values / 131072 values:**

| Mix | `tw` | `sall` | `s4+hash` | `s4+wit` | `wit` | `hot+wit` |
|---|---|---|---|---|---|---|
| uniform 8 | 15.7 / 33.1 | 6.6 / 17.7 | 10.2 / 22.1 | 9.1 / 23.6 | 15.4 / 21.1 | 6.6 / 21.3 |
| uniform 64 | 88.3 / 97.6 | 93.8 / 104.1 | 27.3 / 41.8 | 19.9 / 27.5 | 18.4 / 26.0 | 15.7 / 33.9 |
| skewed 64 | 36.6 / 40.8 | 35.8 / 35.9 | 12.6 / 14.5 | 12.1 / 17.5 | 10.4 / 16.1 | 7.2 / 14.9 |
| phases 64 | 57.5 / 72.5 | 60.7 / 69.2 | 20.7 / 26.7 | 18.0 / 21.0 | 16.1 / 18.8 | 8.7 / 21.4 |

- **Allocation:** `tw` and `s4+dyn` allocate 3 to 16 bytes per element (the dispatched call's boxed result). Every table and witness row allocates nothing.
- **The emulation is faithful:** `s4+dyn` is within 15 % of `tw` in every row.
- **`sall` for `work` from 16 types:** the hand-written split (542 statements at 16 types) is no longer inlined, although declared `@inline`, and its call boxes the result (16 B per element). Its speed falls to the dispatch's. This is a limit of the emulation's longer split, and a sign of what any long split meets.

**e145c, the table per call signature (one probe) against the carried witness, `area`, ns per element, 1000 / 131072 values:**

| Mix | `s4+hash` | `s4+tab` | `s4+wit` | `tab` | `wit` |
|---|---|---|---|---|---|
| uniform 8 | 7.5 / 16.9 | 5.9 / 16.4 | 5.8 / 17.4 | 14.8 / 21.1 | 12.7 / 15.4 |
| uniform 16 | 12.0 / 29.7 | 9.1 / 27.1 | 9.9 / 22.1 | 14.6 / 30.5 | 13.0 / 19.4 |
| uniform 64 | 20.5 / 43.8 | 14.6 / 35.3 | 14.9 / 23.4 | 14.8 / 35.3 | 15.0 / 21.4 |
| skewed 64 | 8.2 / 12.8 | 7.0 / 11.0 | 7.0 / 12.3 | 6.8 / 11.5 | 6.5 / 11.6 |
| cyclic 64 | 9.1 / 20.8 | 6.6 / 16.2 | 6.5 / 16.8 | 6.5 / 17.4 | 6.3 / 16.7 |

- **The table per signature equals the carried witness on data in the cache.** On 131072 values of 16 or 64 types the witness is up to 1.5× faster: its pointer comes with the value, so the indirect call need not wait for the object's header.
- **A pointer for a type met the first time:** 3.8 to 4.9 ms to make it (the callable compiled at the type, and the thunk), then 4.2 to 4.7 ms for its first call. Paid once per signature and type.

**The longer split, compile time and native code of the loop (e145b, `area`):**

| Types split | 4 | 8 | 16 | 32 | 64 |
|---|---|---|---|---|---|
| first call, ms | 8.4 | 11.5 | 15.2 | 23.0 | 40.6 |
| native code, bytes of text | 7 786 | 12 026 | 19 221 | 75 412 | 189 932 |

**e145 (one layout, one multiply)** gives the same picture. Its `sall` row folds into a table of constants (2.7 ns at 64 types), which is why e145b exists. In addition:
- the per-site cache of 8 thrashes beyond 8 types (40 ns at 64);
- plain `cfunction` pointers cost the same as `:caller_world` ones, so the world check is not measurable;
- an index carried in the value costs the same as a carried witness.

## What the numbers say, against the criteria of open issues item 32

1. **A split over the observed hot types at least 3× faster than the table and the witness?**
   - Only for `area` on data in the cache, in the skewed and phase mixes: 2.4 against 7.4 ns, 4.8 against 15.3 ns.
   - For `work`, 1.4× to 2.1×. On 131072 values, 1.0× to 1.8×, and slower than the witness at uniform 64 (28.8 against 22.4 ns).
   - Not met in general. Recompiling in the background is not justified by these numbers.
2. **The table or the witness within 1.5× of that split?**
   - Yes for `work`, and for every mix on 131072 values.
   - No for `area` on data in the cache with few types.
   - The table and the witness are equal on data in the cache, and the witness is up to 1.5× faster on large mixes.
3. **A split over all implementations at most 2 ns per element up to 16, with acceptable compile time and code size?**
   - Met only for `area` on data in the cache.
   - `work` loses inlining at 16 types.
   - The code grows to 19 KB per loop at 16 types and 190 KB at 64.
   - Not met.
4. **Today's fallback against the table:** 40 to 90 ns and an allocation per element at 16 to 64 types, against 7 to 20 ns and none. It is 3× to 6× slower, and with more than four types it dominates the cost of the loop.

What was decided from this, and the reasoning, is in `writeup/plans/2026-10-21-what-follows-the-split.md`.
