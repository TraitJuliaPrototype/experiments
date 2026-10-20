# Heterogeneous collections as idiomatic trait code (E-134, E-143, E-144; 2026-10-20)

The loops of the review of heterogeneous collections (`writeup/reviews/2026-10-20-heterogeneous-collections.md`, scripts in `../hetero/`) written as trait code the way Rust or Swift code would be written: functions bounded by BaseTraits' collection traits (`writeup/reference/traits.md` §10.1–10.4), items `Dynamic{X}`, over a lazy view of the user's `Vector{Any}`, `Vector{AShape}` or `Dict{String,Any}`, and over a copy into `Vector{Dynamic{X}}`. Each against plain Julia (the stock idiom, in `Main`) and against interop (a trait module calling Base's generic algorithms on the user's containers, as `../hetero/hc7_product.jl` did), in the product setting and in the test bed `all`.

Rust and Swift are not installed; they are compared by shape only: `impl Iterator<Item = &dyn Shape>` and `some Sequence<any Shape>` are what `xs::Iterable{Shape}` says.

## What was built for it

- **BaseTraits**, a module of TraitWorld (`TraitWorld-basetraits/src/BaseTraits.jl`, branch `basetraits`): `HasLength`, `Iterable{T}`, `Indexable{T}`, `MutableIndexable{T}`, `Resizable`, `Keyed{K, V}`, Base's containers' conformance by Base's methods, the views `DynamicItems{X}(v)` and `DynamicValues{X}(d)`, and `retain!`. `using TraitWorld` exports them.
- **In TraitWorld** (same branch):
  - a `Dynamic` holds the user's object; the split's candidates are the implementations' types, registered in declaration order; making one registers its type once per session (a flag) instead of searching the registry (157 ns before, E-125);
  - `@dynamic_of X x`: wrapping a value of unknown type is a check split over the candidates, and the value keeps its box;
  - a trait's name in a bound's parameters means its `Dynamic` (`Iterable{Shape}`);
  - the records of `@implement` carry the declaration's line, so a session that loads a package image registers the candidates in the order the image's code was compiled for (E-130: HShapes' split is now H1–H4 in every session; it was H22, H37, H30, H18 in run r1, before this change).
- Tests: `TraitWorld-basetraits/test/basetraits.jl` (26 checks); TraitWorld's whole suite passes (424 checks, `logs/traitworld-tests-product.log`); TraitTables' and TraitCSV's suites pass against the branch (`logs/demonstrator-tests-product.log`); the reference's examples run (`reference_examples.jl`, `logs/reference-examples-product.log`).

## How to run

From this directory, one job at a time (the shared lock, `nice -n 19`; depots of their own, so nothing is precompiled into the main checkouts' caches):

    ./run.sh product --project=. hi1_cells.jl
    ./run.sh all --project=. hi2_shapes.jl
    ./runall.sh r2          # the four interop scripts of ../hetero and hi1, hi2, in both settings; logs/r2-*.log
    python3 tables.py r2 r3 # the tables below

- `hi1_cells.jl` (E-134): the `Vector{Any}` of 1000 Ints and Strings of hc1/hc7, the `Dict{String,Any}` of hc7, hc4's sums.
- `hi2_shapes.jl` (E-144): traits with exactly 2, 4, 5, 8 and 64 implementations (`shapes_defs.jl`, written by `gen_shapes.py`).
- `../hetero/hc1_filter.jl`, `hc3_dynamic.jl`, `hc4_dict.jl`, `hc7_product.jl` unchanged (E-143), on the same build. hc3 needs HShapes, which this environment has.
- `common.jl`: the setting, the load average, one row = the **median** time per element over BenchmarkTools' samples (up to 2000 samples or 2 s), and the median allocation. The `../hetero` scripts print their own numbers: BenchmarkTools **minima** (`@belapsed`), as in the review.

## The build and the runs

- julia-1.13 3b8085c222 (the round of 2026-10-20); the test bed `all` with `-J julia-1.13/usr/lib/julia/facts/sys.so`; strict mode off.
- TraitWorld: branch `basetraits` (worktree `TraitWorld-basetraits/`, from bed3782, uncommitted changes; the logs say `bed3782+changes`).
- The code is defined in the scripts (trait modules at the top level of a script, as hc7), not loaded from package images; HShapes (hc3) is loaded from its image.
- Two processes per setting: **r2** and **r3**, each row "r2 / r3". The load average is printed at the start and end of each log. Five logs of r2/r3 were taken at a load average above 2; they were run again, and the first attempts are kept as `*.loadhigh.log`. **r1** is an earlier full run, before the declaration-order change (its hc3 split over other types); kept, not used in the tables.
- `using TraitWorld` in a fresh process: 143 ms (bed3782) against 145 ms (the branch, with BaseTraits), medians of five (`logs/loadtime-product.log`).

## Results

Per element, 1000 elements. "view": over `DynamicItems{X}`/`DynamicValues{X}` of the user's container; "copy": over `Vector{Dynamic{X}}` or `Dict{String, Dynamic{X}}`; "interop": a trait module calling Base or plain code on the user's container; "plain": the same code in `Main`. Under `all`, plain code is compiled by facts too.

### hi1_cells

| Workload | Kind | Code | product, ns/elt (r2, r3) | B/elt | all, ns/elt (r2, r3) | B/elt |
|---|---|---|---|---|---|---|
| W1 filter!: keep the Ints of a Vector{Any} | plain | Base.filter!(x -> isa(x, Int), v) | 2.24 / 2.37 | 4.1 | 36.97 / 40.82 | 4.2 |
| W1 filter!: keep the Ints of a Vector{Any} | interop | Base.filter! from a trait module (hc7) | 40.76 / 43.19 | 4.2 | 40.67 / 44.37 | 4.2 |
| W1 filter!: keep the Ints of a Vector{Any} | view | retain!(isnum, ·) over DynamicItems{Cell}(v) | 3.83 / 3.27 | 0.4 | 3.74 / 3.70 | 0.4 |
| W1 filter!: keep the Ints of a Vector{Any} | copy | retain!(isnum, ·) over Vector{Dynamic{Cell}} | 1.55 / 1.61 | 0.5 | 1.68 / 1.75 | 0.5 |
| W1 filter!: keep the Ints of a Vector{Any} | view | retain!(f::Callable{…}) over the view, DynamicCall | 17.58 / 17.65 | 16.4 | 22.95 / 21.52 | 17.1 |
| W1 filter!: keep the Ints of a Vector{Any} | view | retain!(f::Callable{…}) over the view, compiled_call | 4.42 / 4.67 | 0.4 | 8.79 / 9.27 | 1.1 |
| W2 count, an operation on each element | plain | n += isa(x, Int) | 0.70 / 0.72 | 0.0 | 0.72 / 0.69 | 0.0 |
| W2 count, an operation on each element | interop | n += isa(x, Int) in a trait module (hc7) | 0.69 / 0.71 | 0.0 | 0.70 / 0.67 | 0.0 |
| W2 count, an operation on each element | view | n += isnum(c) over DynamicItems{Cell}(v) | 1.24 / 1.68 | 0.0 | 1.68 / 1.77 | 0.0 |
| W2 count, an operation on each element | copy | n += isnum(c) over Vector{Dynamic{Cell}} | 1.22 / 1.12 | 0.0 | 1.15 / 0.94 | 0.0 |
| W3 count with a caller's predicate | plain | n += f(x)::Bool, f a closure | 0.72 / 0.69 | 0.0 | 19.06 / 19.76 | 0.0 |
| W3 count with a caller's predicate | interop | f::Callable{Tuple{Any}, Bool} (hc7) | 72.24 / 71.76 | 36.0 | 76.34 / 78.47 | 36.7 |
| W3 count with a caller's predicate | view | f::Callable{Tuple{Dynamic{Cell}}, Bool} over the view | 14.97 / 14.39 | 16.1 | 19.58 / 18.74 | 16.8 |
| W3 count with a caller's predicate | view | the same, compiled_call(f) | 2.44 / 2.67 | 0.1 | 8.08 / 7.53 | 0.8 |
| W3 count with a caller's predicate | copy | Callable{…, CompiledCall} over the copy | 2.17 / 2.32 | 0.1 | 6.40 / 6.45 | 0.8 |
| W4 a Dict{String,Any}'s pairs | plain | for (k, v) in d; n += v isa Int | 2.47 / 2.41 | 0.0 | 273.18 / 262.86 | 99.9 |
| W4 a Dict{String,Any}'s pairs | interop | the same in a trait module (hc7) | 276.17 / 274.26 | 99.9 | 272.98 / 268.40 | 99.9 |
| W4 a Dict{String,Any}'s pairs | view | for (k, c) in DynamicValues{Cell}(d); n += isnum(c) | 4.08 / 5.01 | 0.0 | 5.00 / 4.72 | 0.0 |
| W4 a Dict{String,Any}'s pairs | copy | the same over a Dict{String, Dynamic{Cell}} | 2.87 / 2.55 | 0.0 | 2.85 / 2.50 | 0.0 |
| W5 keyed lookup, 1000 keys | plain | s += d[k] (isa Int, else length) | 10.18 / 11.27 | 0.0 | 10.42 / 10.48 | 0.0 |
| W5 keyed lookup, 1000 keys | interop | the same in a trait module | 11.67 / 9.95 | 0.0 | 10.52 / 10.12 | 0.0 |
| W5 keyed lookup, 1000 keys | view | s += weight(d[k]) over DynamicValues{Cell}(d) | 12.97 / 12.13 | 0.2 | 13.26 / 12.24 | 0.2 |
| W5 keyed lookup, 1000 keys | copy | the same over a Dict{String, Dynamic{Cell}} | 10.48 / 10.03 | 0.2 | 11.34 / 11.25 | 0.2 |
| W6 sums over numbers of mixed types (hc4's controls) | plain | s += x over Vector{Any} of Int | 17.34 / 16.08 | 16.0 | 18.62 / 16.67 | 16.0 |
| W6 sums over numbers of mixed types (hc4's controls) | interop | the same in a trait module | 20.20 / 20.47 | 16.0 | 21.31 / 19.72 | 16.0 |
| W6 sums over numbers of mixed types (hc4's controls) | view | s += value(x) over DynamicItems{Num}(Vector{Any}) | 1.51 / 1.58 | 0.1 | 1.62 / 1.51 | 0.1 |
| W6 sums over numbers of mixed types (hc4's controls) | plain | s += Float64(x) over Vector{Real} | 108.97 / 112.13 | 24.0 | 117.50 / 107.61 | 24.0 |
| W6 sums over numbers of mixed types (hc4's controls) | interop | the same in a trait module | 116.26 / 132.75 | 24.0 | 121.95 / 107.86 | 24.0 |
| W6 sums over numbers of mixed types (hc4's controls) | view | s += value(x) over DynamicItems{Num}(Vector{Real}) | 1.56 / 1.50 | 0.1 | 1.57 / 1.56 | 0.1 |
| W6 sums over numbers of mixed types (hc4's controls) | copy | the same over a copy, Vector{Dynamic{Num}} | 1.19 / 1.16 | 0.1 | 1.10 / 1.18 | 0.1 |
| the copy itself | copy | collect(DynamicItems{Cell}(v)): Vector{Dynamic{Cell}} | 1.95 / 1.81 | 8.1 | 1.93 / 1.79 | 8.1 |
| the copy itself | copy | Dynamic{Cell}[Dynamic{Cell}(x) for x in v], in Main | 108.26 / 102.12 | 28.0 | 135.14 / 126.56 | 35.8 |
| the copy itself | make | Dynamic{Cell}(x), x::Int known | 8.10 / 8.11 | 16.0 | 8.23 / 8.09 | 16.0 |

### hi2_shapes

| Workload | Kind | Code | product, ns/elt (r2, r3) | B/elt | all, ns/elt (r2, r3) | B/elt |
|---|---|---|---|---|---|---|
| n = 2 implementations | plain | Σ parea2(x) over Vector{AShape} | 0.97 / 0.95 | 0.0 | 34.58 / 38.87 | 32.0 |
| n = 2 implementations | interop | the same in a trait module | 40.47 / 40.56 | 32.0 | 40.68 / 41.10 | 32.0 |
| n = 2 implementations | copy | Σ area2(x) over Vector{Dynamic{S2}} | 1.01 / 0.99 | 0.1 | 1.16 / 1.07 | 0.1 |
| n = 2 implementations | view | Σ area2(x) over DynamicItems{S2}(Vector{AShape}) | 1.05 / 1.03 | 0.1 | 1.31 / 1.33 | 0.1 |
| n = 2 implementations | view | Σ area2(x) over DynamicItems{S2}(Vector{Any}) | 1.08 / 1.01 | 0.1 | 1.35 / 1.40 | 0.1 |
| n = 2 implementations | make | collect(DynamicItems{S2}(v)): the copy | 1.97 / 1.86 | 8.1 | 2.12 / 2.14 | 8.1 |
| n = 4 implementations | plain | Σ parea4(x) over Vector{AShape} | 43.13 / 38.75 | 32.0 | 36.40 / 38.07 | 32.0 |
| n = 4 implementations | interop | the same in a trait module | 49.74 / 43.81 | 32.0 | 48.02 / 42.89 | 32.0 |
| n = 4 implementations | copy | Σ area4(x) over Vector{Dynamic{S4}} | 1.25 / 1.32 | 0.1 | 1.43 / 1.61 | 0.1 |
| n = 4 implementations | view | Σ area4(x) over DynamicItems{S4}(Vector{AShape}) | 2.00 / 1.79 | 0.1 | 1.77 / 1.81 | 0.1 |
| n = 4 implementations | view | Σ area4(x) over DynamicItems{S4}(Vector{Any}) | 2.04 / 1.76 | 0.1 | 1.79 / 1.69 | 0.1 |
| n = 4 implementations | make | collect(DynamicItems{S4}(v)): the copy | 2.68 / 2.48 | 8.1 | 2.30 / 2.79 | 8.1 |
| n = 5 implementations | plain | Σ parea5(x) over Vector{AShape} | 94.93 / 81.85 | 32.0 | 74.27 / 79.20 | 32.0 |
| n = 5 implementations | interop | the same in a trait module | 73.59 / 74.17 | 32.0 | 74.56 / 83.42 | 32.0 |
| n = 5 implementations | copy | Σ area5(x) over Vector{Dynamic{S5}} | 4.98 / 5.17 | 3.3 | 5.14 / 5.05 | 3.3 |
| n = 5 implementations | view | Σ area5(x) over DynamicItems{S5}(Vector{AShape}) | 8.37 / 8.59 | 3.3 | 9.25 / 8.68 | 3.3 |
| n = 5 implementations | view | Σ area5(x) over DynamicItems{S5}(Vector{Any}) | 9.06 / 8.53 | 3.3 | 8.59 / 8.79 | 3.3 |
| n = 5 implementations | make | collect(DynamicItems{S5}(v)): the copy | 4.65 / 4.43 | 8.1 | 5.11 / 4.98 | 8.1 |
| n = 8 implementations | plain | Σ parea8(x) over Vector{AShape} | 104.16 / 96.28 | 32.0 | 84.18 / 87.08 | 32.0 |
| n = 8 implementations | interop | the same in a trait module | 116.69 / 102.97 | 32.0 | 89.85 / 93.92 | 32.0 |
| n = 8 implementations | copy | Σ area8(x) over Vector{Dynamic{S8}} | 12.08 / 11.88 | 8.1 | 13.09 / 11.70 | 8.1 |
| n = 8 implementations | view | Σ area8(x) over DynamicItems{S8}(Vector{AShape}) | 42.62 / 37.49 | 8.1 | 34.80 / 34.44 | 8.1 |
| n = 8 implementations | view | Σ area8(x) over DynamicItems{S8}(Vector{Any}) | 34.90 / 39.61 | 8.1 | 35.60 / 34.15 | 8.1 |
| n = 8 implementations | make | collect(DynamicItems{S8}(v)): the copy | 9.44 / 9.59 | 8.1 | 9.83 / 9.47 | 8.1 |
| n = 64 implementations | plain | Σ parea64(x) over Vector{AShape} | 101.74 / 98.76 | 32.0 | 105.87 / 104.32 | 32.0 |
| n = 64 implementations | interop | the same in a trait module | 114.79 / 109.00 | 32.0 | 120.43 / 111.80 | 32.0 |
| n = 64 implementations | copy | Σ area64(x) over Vector{Dynamic{S64}} | 81.96 / 80.68 | 15.0 | 83.86 / 78.35 | 15.0 |
| n = 64 implementations | view | Σ area64(x) over DynamicItems{S64}(Vector{AShape}) | 165.20 / 162.37 | 15.0 | 170.75 / 164.92 | 15.0 |
| n = 64 implementations | view | Σ area64(x) over DynamicItems{S64}(Vector{Any}) | 181.00 / 164.67 | 15.0 | 172.34 / 163.98 | 15.0 |
| n = 64 implementations | make | collect(DynamicItems{S64}(v)): the copy | 80.96 / 77.01 | 8.1 | 78.06 / 74.00 | 8.1 |
| n = 64, one type only | copy | only P1: Vector{Dynamic{S64}} | 1.55 / 1.43 | 0.1 | 1.41 / 1.34 | 0.1 |
| n = 64, one type only | view | only P1: DynamicItems{S64}(Vector{AShape}) | 1.40 / 1.40 | 0.1 | 1.43 / 1.44 | 0.1 |
| n = 64, one type only | plain | only P1: plain, 64 methods | 37.72 / 36.34 | 32.0 | 30.66 / 30.52 | 32.0 |
| n = 64, one type only | copy | only P4: Vector{Dynamic{S64}} | 1.72 / 1.62 | 0.1 | 1.68 / 1.60 | 0.1 |
| n = 64, one type only | view | only P4: DynamicItems{S64}(Vector{AShape}) | 1.60 / 1.44 | 0.1 | 1.45 / 1.49 | 0.1 |
| n = 64, one type only | plain | only P4: plain, 64 methods | 37.35 / 36.16 | 32.0 | 34.13 / 32.69 | 32.0 |
| n = 64, one type only | copy | only P5: Vector{Dynamic{S64}} | 23.52 / 23.14 | 16.1 | 20.76 / 22.10 | 16.1 |
| n = 64, one type only | view | only P5: DynamicItems{S64}(Vector{AShape}) | 40.17 / 39.85 | 16.1 | 42.98 / 36.38 | 16.1 |
| n = 64, one type only | plain | only P5: plain, 64 methods | 31.76 / 31.24 | 32.0 | 36.96 / 35.66 | 32.0 |
| n = 64, one type only | copy | only P64: Vector{Dynamic{S64}} | 24.83 / 18.48 | 16.1 | 24.47 / 24.20 | 16.1 |
| n = 64, one type only | view | only P64: DynamicItems{S64}(Vector{AShape}) | 47.04 / 45.95 | 16.1 | 36.46 / 42.58 | 16.1 |
| n = 64, one type only | plain | only P64: plain, 64 methods | 41.87 / 33.52 | 32.0 | 35.29 / 32.72 | 32.0 |


### The interop numbers again (E-143), same build

| Loop (script) | product: trait module / plain | `all`: trait module / plain | the review (E-121 to E-125) |
|---|---|---|---|
| `filter!` on `Vector{Any}` (hc7) | 38.2 / 1.2 (r2), 38.2 / 1.2 (r3) | 38.1 / 34.2, 37.4 / 32.2 | 36.8 / 1.1 (product) |
| `Callable{Tuple{Any}, Bool}` predicate (hc7) | 63.5, 60.3 (36 B) | 70.4, 67.4 | 62.5 |
| `for (k, v) in Dict{String,Any}` (hc7) | 233.5 / 2.2, 235.4 / 2.2 (100 B) | 226.3 / 225.2, 225.0 / 222.1 | 242 / 2.2 |
| `filter!` plain against `all` (hc1) | 1.2, 1.2 | 36.3, 32.7 | 1.2 / 33.2 |
| `for (k, v) in Dict{Any,Any}` (hc4) | 2.0, 2.1 | 224.5, 221.0 | 2.1 / 222.9 |
| `Dynamic` 64 types cycling / only H5 (hc3, product) | 66.7 / 18.4, 66.3 / 18.0 | 67.8 / 18.3, 67.1 / 18.5 | 65.2 / 19.5 |
| making `Dynamic{Shape}(H1(1.0))` (hc3) | 5.1 ns, 32 B; 5.0 ns | 5.2, 5.2 | 156.6 ns, 32 B |

(ns per element; hc1, hc3, hc4, hc7 report BenchmarkTools minima.)

## What the numbers say

**Where the item types are among the split's candidates (up to four implementations), idiomatic trait code recovers the tails, in both settings:**
- `filter!` on the user's `Vector{Any}`: `retain!(isnum, DynamicItems{Cell}(v))` 3.3–3.8 ns, in place, against 41–43 ns interop (38 ns in hc7) and 2.2–2.4 ns plain (product); under `all` plain is 37–41 ns and the trait code stays at 3.7.
- The `Dict{String,Any}` loop: 4–5 ns over the view, 2.5–2.9 over a copy, against 274–276 ns interop and 2.4 ns plain; under `all` plain is 263–273 ns.
- Counting with an operation per item: 1.2–1.8 ns over the view, 0.9–1.2 over the copy, against 0.7 for plain's `isa` (no call).
- Where plain Julia itself dispatches at run time, trait code is faster than plain: hc4's sums (`s += x` over `Vector{Any}`, `Float64(x)` over `Vector{Real}`) 1.5 ns against 16–17 and 109–112 ns; four shape types 1.3–2.0 ns against 39–43 ns.
- The view costs little over the copy (up to about 2×) and needs no pass and no second container; writes reach the user's vector.

**Beyond the split it does not:**
- 5 types: copy 5.0–5.2, view 8.4–9.3 ns; 8 types: copy 12–13, view 34–43 ns; 64 types: copy 78–84, view 162–181 ns, against plain 99–106 ns. The view pays two run-time sites per item outside the split (the wrapping check and the operation), each Julia's megamorphic dispatch; the copy pays one. A vector of P5 only (the fifth type, 64 declared): copy 21–24, view 36–43 ns; of P1 only: 1.3–1.6 ns.
- This is E-145's question (`writeup/open-issues.md` §2, item 32): the idiomatic rewrites have a hot site with more than four implementations; a longer split or a per-site table at the fallback would apply to both the copy and the view.

**What still costs, and why:**
- A `Callable{Tuple{Dynamic{Cell}}, Bool}` predicate in `DynamicCall` mode: 14–18 ns and 16 B per call (product; 19–23 under `all`) (the `Dynamic` argument is boxed for the pointer call); `compiled_call(f)` 2.4–4.7 ns. Against 60–72 ns for `Callable{Tuple{Any}, Bool}` (interop) and 0.7 ns for plain's inlined closure.
- Copying with `Dynamic{Cell}[Dynamic{Cell}(x) for x in v]` in plain code: 102–108 ns per element (product), because a constructor call at a run-time site is not served by Julia's per-site cache (the function is a type); `collect(DynamicItems{Cell}(v))` 1.8–2.0 ns.
- Keyed lookup: 12–13 ns over the view against 10–11 plain: the `Dict` lookup dominates.

**Lessons for writing trait code in the facts mode** (found while writing BaseTraits):
- A helper function that takes a value typed `Any` is a run-time site, even with one `@inline` method: its result is `Any`. The view writes its wrapping out at each read (`@dynamic_of`).
- Indexing a `Tuple{Any, Int}` (`vr[1]`) is a run-time site too: `getfield(vr, 1)` is not.
- Iterating a `Dict{K,Any}` builds `Pair{K,Any}` at a run-time site (hc4); `DynamicValues` iterates `keys(d)` and `values(d)` instead.
- Writing an item back into a `Vector{Any}` (`setindex!` at `Any`) is a run-time site; the view splits the store over the candidates, so each branch stores at a concrete type.
