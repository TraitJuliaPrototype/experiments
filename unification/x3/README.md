# E-269 (X3): what do methods at an open set on Base's hottest functions cost plain code?

The work plan's §8, X3, W-99's gate. Registry row: `writeup/record/experiments.md` E-269.

## How to run

```sh
source env.sh
experiments/unification/x3/run.sh <session>           # everything below, one process at a time
X3_MEMBERS=<k> julia-unified/julia --startup-file=no experiments/unification/x3/x3.jl <label>
julia compare.jl x3/results/<control> x3/results/<other>   # the quick subset's ratios
```

- `install.jl`: with k > 0, a set `OpenColl` with methods for `Base.getindex(::OpenColl, ::Int)`, `Base.iterate(::OpenColl[, ::Int])` and `Base.length(::OpenColl)`, and k members. On the unified build the set is open and the members join by memberships; on vanilla it is a plain abstract type and the members are its declared subtypes (the closed-world equivalent).
- `x3.jl`: ns per query or call, the median of 7 rounds:
  - method matching (what inference and a dispatch miss do): `Base._methods_by_ftype` for `getindex`, `iterate` and `length` at 50 concrete container types (25 `Vector{T}`, 25 two-element tuples);
  - dynamic dispatch, steady state: `length(c)` and `getindex(c, 1)` over the 50 containers held as `Any`;
  - a member's dynamic call (k > 0).
- `bench_quick.jl`: the quick BaseBenchmarks subset (`factscompiler/step0/quick.txt`, 148 benchmarks) with `install.jl`'s methods in place; results in `results/<label>/`.
- `run.sh`: x3.jl at k = 0, 1, 10, 100 on both builds, two runs each; the quick subset on vanilla (k = 0) and the unified build (k = 0 and 100), two runs each.

Outputs: `out/<label>.txt`, `results/<label>/`, `logs/`.

## Results

Three sessions, two runs each: `s1` on the stack before E-269's fixes, `s2` after the first round, `s3` on the final top. ns per query or call (`out/`); the quick subset as geometric means of time ratios (`results/`, `compare.jl`). Load 2–9 of 128.

| Question | vanilla | `s1`: before | `s3`: final top 3ad297247e (tag `measured-3ad297247e`) |
|---|---|---|---|
| match `getindex` at 50 container types, k = 0 / k ≥ 1 | 14,780–14,950 | 14,810 / 15,690–15,860 | 14,960–15,050 / 15,280–15,400 (+3–4 %) |
| match `iterate`, k = 0 / k ≥ 1 | 5,660–5,730 | 5,690 / 6,780–6,800 | 5,710–5,750 / 6,020–6,100 (+6–7 %) |
| match `length`, k = 0 / k ≥ 1 | 1,290–1,330 | 1,230 / 2,055–2,070 | 1,250–1,280 / 1,530–1,540 (+17–18 %) |
| dynamic `length(c)` over 50 containers | 136.5–138.2 | 170–172 | 133–138 |
| dynamic `getindex(c, 1)` over 50 containers | 164.4–167.4 | 194–196 | 167–168 |
| a member's dynamic `length`, 10 / 50 members | 116–117 / 151–153 | 121–123 / — | — / 141 |
| the quick subset (148), against vanilla | 0.975–0.980 between two vanilla runs | 0.990–1.024 | 1.005 (k = 100), 1.010 (k = 0) |

## What it means

- **The criterion** (more than about 3 % on the microbenchmark or 2 % on the subset: BaseTraits' operations off Base's functions, or the typename index extended) **failed in `s1` on two counts:**
  - method matching at a function with a method at an open set cost a non-member 7–60 %, flat in the number of members: intersecting a concrete non-member with a set skipped `obviously_disjoint` (349 against 30 ns), and the typemap computed the world range of the memberships the query reads (945 ns) for every query;
  - with no method at a set at all, dynamic calls over 50 container types cost 24 % more: the stack's exact-type call-cache entries (since dropped, PE-20).
- **The fixes** (mine, under the user's rule for gates): a concrete type no entry of whose chain can reach a set is obviously disjoint from it; the world range only where a membership can narrow it; the exact-type entries out of the stack.
- **What remains:** method matching +3–18 % at a function with a method at an open set, on inference and dispatch misses only: one visit of the linear list per query. Steady-state dispatch is unaffected, a member's call faster. The typemap's index for methods at sets is PE-21; BaseTraits' operations stay on Base's functions.
- **The subset** shows no effect beyond its noise.
- `out/test*.txt` and `out/s1-*`, `out/s2-*` are the earlier builds' runs, kept as the record of the fixes.
