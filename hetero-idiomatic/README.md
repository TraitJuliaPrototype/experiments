# Heterogeneous collections as idiomatic trait code (E-134, E-143, E-144; 2026-10-20)

*Written in the spelling before the language of `Compiled` and `Dynamic` (TraitWorld ≤ 5b172e1): `DynamicCall`, `CompiledCall`, `compiled_call` are now `Dynamic`, `Compiled`, `compiled_for` (`../../writeup/reference/traits.md` §6.6, §9).*

The loops of the review of heterogeneous collections (`writeup/reviews/2026-10-20-heterogeneous-collections.md`, scripts in `../hetero/`) written as trait code the way Rust or Swift code would be written: functions bounded by BaseTraits' collection traits (`writeup/reference/traits.md` §10.1–10.4), items `Dynamic{X}`, called with the user's `Vector{Any}`, `Vector{AShape}` or `Dict{String,Any}` directly (the function's entry translates the container by its bound into a view that wraps each element when it is read), with that view written out, and over a copy into `Vector{Dynamic{X}}`. Each against plain Julia (the stock idiom, in `Main`) and against interop (a trait module calling Base's generic algorithms on the user's containers, as `../hetero/hc7_product.jl` did), in the product setting and in the test bed `all`.

Rust and Swift are not installed; they are compared by shape only: `impl Iterator<Item = &dyn Shape>` and `some Sequence<any Shape>` are what `xs::Iterable{Shape}` says.

## What was built for it

- **BaseTraits**, a module of TraitWorld (`TraitWorld-basetraits/src/BaseTraits.jl`, branch `basetraits`): `HasLength`, `Iterable{T}`, `Indexable{T}`, `MutableIndexable{T}`, `Resizable`, `Keyed{K, V}`, Base's containers' conformance by Base's methods, the views `DynamicItems{X}(v)` and `DynamicValues{X}(d)`, and `retain!`. `using TraitWorld` exports them.
- **The crossing** (TraitWorld 8799aea, 9fd18db): a function bounded with dynamic items (`Iterable{Shape}`, `Indexable{Shape}`, `MutableIndexable{Shape}`, `Keyed{K, Shape}`, `Iterable{Pair{K, Shape}}`) takes the user's `AbstractVector` or `AbstractDict` as it is; its entry translates it into the view where the container does not meet the bounds as it is. Items declared `Any`, abstract, a `Union`, or a concrete type that conforms cross; a container whose item type cannot hold a conforming value is refused at the call; any other non-conforming item fails when it is read (traits reference §10.3, lowering §13.1).
- **In TraitWorld** (same branch):
  - a `Dynamic` holds the user's object; the split's candidates are the implementations' types, registered in declaration order; making one registers its type once per session (a flag) instead of searching the registry (157 ns before, E-125);
  - `@dynamic_of X x`: wrapping a value of unknown type is a check split over the candidates, and the value keeps its box;
  - a trait's name in a bound's parameters means its `Dynamic` (`Iterable{Shape}`);
  - the records of `@implement` carry the declaration's line, so a session that loads a package image registers the candidates in the order the image's code was compiled for (E-130: HShapes' split is now H1–H4 in every session; it was H22, H37, H30, H18 in run r1, before this change).
- Tests: `TraitWorld-basetraits/test/basetraits.jl` (45 checks, product and `all`: `logs/basetraits-tests-*.log`); TraitWorld's whole suite passes (443 checks, `logs/traitworld-tests-product.log`); TraitTables', TraitCSV's, TraitDifferentialEquations' and TraitMakie's suites pass against the branch (`logs/demonstrator-tests-product.log`, `logs/demo-*.full.log`); the reference's examples run (`reference_examples.jl`, 11 checks, `logs/reference-examples-product.log`).

## How to run

From this directory, one job at a time (the shared lock, `nice -n 19`; depots of their own, so nothing is precompiled into the main checkouts' caches):

    ./run.sh product --project=. hi1_cells.jl
    ./run.sh all --project=. hi2_shapes.jl
    ./runall.sh r2          # the four interop scripts of ../hetero and hi1, hi2, in both settings; logs/r2-*.log
    ./runhi.sh r6           # hi1, hi2 only, in both settings
    python3 tables.py r2 r3 # the tables below

- `hi1_cells.jl` (E-134): the `Vector{Any}` of 1000 Ints and Strings of hc1/hc7, the `Dict{String,Any}` of hc7, hc4's sums.
- `hi2_shapes.jl` (E-144): traits with exactly 2, 4, 5, 8 and 64 implementations (`shapes_defs.jl`, written by `gen_shapes.py`).
- `../hetero/hc1_filter.jl`, `hc3_dynamic.jl`, `hc4_dict.jl`, `hc7_product.jl` unchanged (E-143), on the same build. hc3 needs HShapes, which this environment has.
- `common.jl`: the setting, the load average, one row = the **median** time per element over BenchmarkTools' samples (up to 2000 samples or 2 s), and the median allocation. The `../hetero` scripts print their own numbers: BenchmarkTools **minima** (`@belapsed`), as in the review.

## The build and the runs

- julia-1.13 3b8085c222 (the round of 2026-10-20); the test bed `all` with `-J julia-1.13/usr/lib/julia/facts/sys.so`; strict mode off.
- TraitWorld: branch `basetraits` (worktree `TraitWorld-basetraits/`); each log names its commit.
- The code is defined in the scripts (trait modules at the top level of a script, as hc7), not loaded from package images; HShapes (hc3) is loaded from its image.
- Two processes per setting per build, each row "first / second". The load average is printed at the start and end of each log; logs started above 2 were run again, the first attempts kept as `*.loadhigh.log`.
- **The runs:**
  - **r6, r7** (TraitWorld 9fd18db, the crossing): the tables below. **Indicative only:** the machine was noisy with other simulations (load averages 1.3–1.9 over one minute, 2.1–2.6 over fifteen); the like-for-like comparison of the implicit crossing against the explicit view is to be run again on a quiet machine.
  - r4, r5 (8799aea, the crossing before the fix of 9fd18db: a `Dict{String,Any}` crossing under `all` cost 2.7 µs per element, because it was assembled as it is at each call and fails the `Iterable` family's check there); kept, not used.
  - r2, r3 (8863ea0, the explicit view only; and the interop scripts, E-143): the table of the interop numbers below.
  - r1: before the declaration-order change; kept, not used.
- `using TraitWorld` in a fresh process: 143 ms (bed3782) against 145 ms (the branch at 8863ea0, with BaseTraits), medians of five (`logs/loadtime-product.log`).

## Results

Per element, 1000 elements. "direct": the user's container passed as it is (it crosses); "view": over `DynamicItems{X}`/`DynamicValues{X}` of the user's container, written out; "copy": over `Vector{Dynamic{X}}` or `Dict{String, Dynamic{X}}`; "interop": a trait module calling Base or plain code on the user's container; "plain": the same code in `Main`. Under `all`, plain code is compiled by facts too.

### hi1_cells (r6, r7; indicative)

| Workload | Kind | Code | product, ns/elt (r6, r7) | B/elt | all, ns/elt (r6, r7) | B/elt |
|---|---|---|---|---|---|---|
| W1 filter!: keep the Ints of a Vector{Any} | plain | Base.filter!(x -> isa(x, Int), v) | 1.34 / 2.31 | 4.1 | 37.17 / 36.38 | 4.2 |
| W1 filter!: keep the Ints of a Vector{Any} | interop | Base.filter! from a trait module (hc7) | 38.76 / 41.68 | 4.2 | 43.33 / 41.55 | 4.2 |
| W1 filter!: keep the Ints of a Vector{Any} | view | retain!(isnum, ·) over DynamicItems{Cell}(v) | 2.77 / 2.79 | 0.4 | 2.78 / 3.34 | 0.4 |
| W1 filter!: keep the Ints of a Vector{Any} | direct | retain!(isnum, v), v the user's Vector{Any} | 2.75 / 2.88 | 0.4 | 2.73 / 3.24 | 0.4 |
| W1 filter!: keep the Ints of a Vector{Any} | copy | retain!(isnum, ·) over Vector{Dynamic{Cell}} | 1.83 / 1.79 | 0.5 | 1.50 / 1.62 | 0.5 |
| W1 filter!: keep the Ints of a Vector{Any} | view | retain!(f::Callable{…}) over the view, DynamicCall | 17.66 / 17.04 | 16.4 | 23.20 / 21.44 | 17.1 |
| W1 filter!: keep the Ints of a Vector{Any} | view | retain!(f::Callable{…}) over the view, compiled_call | 4.17 / 4.15 | 0.4 | 8.89 / 9.00 | 1.1 |
| W1 filter!: keep the Ints of a Vector{Any} | direct | retain!(compiled_call(f), v), v the user's vector | 9.35 / 4.12 | 0.4 | 8.93 / 8.79 | 1.1 |
| W2 count, an operation on each element | plain | n += isa(x, Int) | 0.65 / 0.67 | 0.0 | 0.67 / 0.67 | 0.0 |
| W2 count, an operation on each element | interop | n += isa(x, Int) in a trait module (hc7) | 0.66 / 0.66 | 0.0 | 0.68 / 0.67 | 0.0 |
| W2 count, an operation on each element | view | n += isnum(c) over DynamicItems{Cell}(v) | 1.64 / 1.68 | 0.0 | 1.59 / 1.38 | 0.1 |
| W2 count, an operation on each element | direct | n += isnum(c), countnums(v) with the user's Vector{Any} | 1.64 / 1.68 | 0.0 | 1.35 / 1.38 | 0.0 |
| W2 count, an operation on each element | copy | n += isnum(c) over Vector{Dynamic{Cell}} | 1.11 / 1.14 | 0.0 | 1.18 / 1.21 | 0.0 |
| W3 count with a caller's predicate | plain | n += f(x)::Bool, f a closure | 0.66 / 0.66 | 0.0 | 18.41 / 20.96 | 0.0 |
| W3 count with a caller's predicate | interop | f::Callable{Tuple{Any}, Bool} (hc7) | 71.43 / 71.65 | 36.0 | 77.88 / 77.42 | 36.7 |
| W3 count with a caller's predicate | view | f::Callable{Tuple{Dynamic{Cell}}, Bool} over the view | 14.55 / 15.10 | 16.1 | 19.24 / 20.38 | 16.8 |
| W3 count with a caller's predicate | view | the same, compiled_call(f) | 2.83 / 2.67 | 0.1 | 7.50 / 7.49 | 0.8 |
| W3 count with a caller's predicate | direct | the same, compiled_call(f), the user's vector | 2.66 / 2.73 | 0.1 | 7.44 / 7.34 | 0.8 |
| W3 count with a caller's predicate | copy | Callable{…, CompiledCall} over the copy | 2.20 / 2.27 | 0.1 | 6.64 / 6.68 | 0.8 |
| W4 a Dict{String,Any}'s pairs | plain | for (k, v) in d; n += v isa Int | 2.31 / 2.36 | 0.0 | 261.22 / 264.97 | 99.9 |
| W4 a Dict{String,Any}'s pairs | interop | the same in a trait module (hc7) | 263.95 / 260.45 | 99.9 | 263.14 / 265.08 | 99.9 |
| W4 a Dict{String,Any}'s pairs | view | for (k, c) in DynamicValues{Cell}(d); n += isnum(c) | 4.02 / 4.10 | 0.0 | 4.69 / 4.57 | 0.1 |
| W4 a Dict{String,Any}'s pairs | direct | the same, countvals(d) with the user's Dict{String,Any} | 4.10 / 4.04 | 0.0 | 4.59 / 4.51 | 0.0 |
| W4 a Dict{String,Any}'s pairs | copy | the same over a Dict{String, Dynamic{Cell}} | 2.51 / 2.51 | 0.0 | 2.65 / 2.50 | 0.0 |
| W5 keyed lookup, 1000 keys | plain | s += d[k] (isa Int, else length) | 10.11 / 10.26 | 0.0 | 10.58 / 10.27 | 0.0 |
| W5 keyed lookup, 1000 keys | interop | the same in a trait module | 10.14 / 10.34 | 0.0 | 10.46 / 10.15 | 0.0 |
| W5 keyed lookup, 1000 keys | view | s += weight(d[k]) over DynamicValues{Cell}(d) | 12.97 / 12.91 | 0.2 | 13.46 / 13.54 | 0.2 |
| W5 keyed lookup, 1000 keys | direct | the same, the user's Dict{String,Any} | 12.85 / 12.93 | 0.2 | 13.36 / 13.61 | 0.2 |
| W5 keyed lookup, 1000 keys | copy | the same over a Dict{String, Dynamic{Cell}} | 10.45 / 10.69 | 0.2 | 10.79 / 11.00 | 0.2 |
| W6 sums over numbers of mixed types (hc4's controls) | plain | s += x over Vector{Any} of Int | 16.79 / 17.50 | 16.0 | 17.49 / 18.43 | 16.0 |
| W6 sums over numbers of mixed types (hc4's controls) | interop | the same in a trait module | 19.58 / 20.06 | 16.0 | 19.69 / 20.68 | 16.0 |
| W6 sums over numbers of mixed types (hc4's controls) | view | s += value(x) over DynamicItems{Num}(Vector{Any}) | 1.50 / 1.51 | 0.1 | 1.57 / 1.57 | 0.1 |
| W6 sums over numbers of mixed types (hc4's controls) | direct | the same, total(v) with the user's Vector{Any} | 1.51 / 1.51 | 0.1 | 1.54 / 1.50 | 0.1 |
| W6 sums over numbers of mixed types (hc4's controls) | plain | s += Float64(x) over Vector{Real} | 101.44 / 101.47 | 24.0 | 109.59 / 105.73 | 24.0 |
| W6 sums over numbers of mixed types (hc4's controls) | interop | the same in a trait module | 106.31 / 109.17 | 24.0 | 113.44 / 110.98 | 24.0 |
| W6 sums over numbers of mixed types (hc4's controls) | view | s += value(x) over DynamicItems{Num}(Vector{Real}) | 1.46 / 1.49 | 0.1 | 1.55 / 1.51 | 0.1 |
| W6 sums over numbers of mixed types (hc4's controls) | direct | the same, total(v) with the user's Vector{Real} | 1.47 / 1.51 | 0.1 | 1.53 / 1.50 | 0.1 |
| W6 sums over numbers of mixed types (hc4's controls) | copy | the same over a copy, Vector{Dynamic{Num}} | 1.13 / 1.13 | 0.1 | 1.18 / 1.15 | 0.1 |
| the copy itself | copy | collect(DynamicItems{Cell}(v)): Vector{Dynamic{Cell}} | 1.76 / 1.83 | 8.1 | 2.08 / 1.79 | 8.1 |
| the copy itself | copy | Dynamic{Cell}[Dynamic{Cell}(x) for x in v], in Main | 103.63 / 101.00 | 28.0 | 119.47 / 117.31 | 35.8 |
| the copy itself | make | Dynamic{Cell}(x), x::Int known | 7.67 / 7.79 | 16.0 | 8.19 / 7.64 | 16.0 |

### hi2_shapes (r6, r7; indicative)

| Workload | Kind | Code | product, ns/elt (r6, r7) | B/elt | all, ns/elt (r6, r7) | B/elt |
|---|---|---|---|---|---|---|
| n = 2 implementations | plain | Σ parea2(x) over Vector{AShape} | 0.88 / 0.95 | 0.0 | 36.77 / 34.09 | 32.0 |
| n = 2 implementations | interop | the same in a trait module | 38.52 / 41.87 | 32.0 | 39.58 / 41.23 | 32.0 |
| n = 2 implementations | copy | Σ area2(x) over Vector{Dynamic{S2}} | 0.96 / 1.03 | 0.1 | 1.07 / 1.12 | 0.1 |
| n = 2 implementations | view | Σ area2(x) over DynamicItems{S2}(Vector{AShape}) | 1.01 / 1.08 | 0.1 | 1.30 / 1.34 | 0.1 |
| n = 2 implementations | view | Σ area2(x) over DynamicItems{S2}(Vector{Any}) | 1.01 / 1.09 | 0.1 | 1.27 / 1.34 | 0.1 |
| n = 2 implementations | direct | Σ area2(x), total2(v) with the user's Vector{AShape} | 1.02 / 1.09 | 0.1 | 1.25 / 1.35 | 0.1 |
| n = 2 implementations | direct | Σ area2(x), total2(v) with the user's Vector{Any} | 1.03 / 1.10 | 0.1 | 1.26 / 1.31 | 0.1 |
| n = 2 implementations | make | collect(DynamicItems{S2}(v)): the copy | 1.75 / 1.92 | 8.1 | 1.92 / 1.97 | 8.1 |
| n = 4 implementations | plain | Σ parea4(x) over Vector{AShape} | 36.56 / 39.86 | 32.0 | 36.26 / 36.78 | 32.0 |
| n = 4 implementations | interop | the same in a trait module | 43.41 / 44.17 | 32.0 | 40.44 / 43.11 | 32.0 |
| n = 4 implementations | copy | Σ area4(x) over Vector{Dynamic{S4}} | 1.21 / 1.61 | 0.1 | 1.17 / 1.25 | 0.1 |
| n = 4 implementations | view | Σ area4(x) over DynamicItems{S4}(Vector{AShape}) | 1.77 / 1.87 | 0.1 | 1.84 / 1.79 | 0.1 |
| n = 4 implementations | view | Σ area4(x) over DynamicItems{S4}(Vector{Any}) | 1.81 / 1.89 | 0.1 | 2.16 / 1.98 | 0.1 |
| n = 4 implementations | direct | Σ area4(x), total4(v) with the user's Vector{AShape} | 1.83 / 1.87 | 0.1 | 1.76 / 1.83 | 0.1 |
| n = 4 implementations | direct | Σ area4(x), total4(v) with the user's Vector{Any} | 1.77 / 1.77 | 0.1 | 2.09 / 1.95 | 0.1 |
| n = 4 implementations | make | collect(DynamicItems{S4}(v)): the copy | 2.27 / 2.53 | 8.1 | 2.78 / 2.38 | 8.1 |
| n = 5 implementations | plain | Σ parea5(x) over Vector{AShape} | 79.72 / 86.69 | 32.0 | 82.94 / 60.82 | 32.0 |
| n = 5 implementations | interop | the same in a trait module | 116.57 / 79.43 | 32.0 | 87.13 / 81.12 | 32.0 |
| n = 5 implementations | copy | Σ area5(x) over Vector{Dynamic{S5}} | 5.22 / 5.75 | 3.3 | 4.94 / 4.74 | 3.3 |
| n = 5 implementations | view | Σ area5(x) over DynamicItems{S5}(Vector{AShape}) | 8.40 / 9.01 | 3.3 | 8.65 / 8.24 | 3.3 |
| n = 5 implementations | view | Σ area5(x) over DynamicItems{S5}(Vector{Any}) | 8.48 / 8.81 | 3.3 | 9.18 / 8.78 | 3.3 |
| n = 5 implementations | direct | Σ area5(x), total5(v) with the user's Vector{AShape} | 8.44 / 9.09 | 3.3 | 8.81 / 8.24 | 3.3 |
| n = 5 implementations | direct | Σ area5(x), total5(v) with the user's Vector{Any} | 8.55 / 8.82 | 3.3 | 9.28 / 8.76 | 3.3 |
| n = 5 implementations | make | collect(DynamicItems{S5}(v)): the copy | 4.66 / 5.10 | 8.1 | 5.12 / 4.49 | 8.1 |
| n = 8 implementations | plain | Σ parea8(x) over Vector{AShape} | 85.56 / 84.27 | 32.0 | 86.66 / 86.68 | 32.0 |
| n = 8 implementations | interop | the same in a trait module | 95.36 / 92.10 | 32.0 | 94.21 / 91.65 | 32.0 |
| n = 8 implementations | copy | Σ area8(x) over Vector{Dynamic{S8}} | 12.52 / 11.79 | 8.1 | 11.87 / 12.25 | 8.1 |
| n = 8 implementations | view | Σ area8(x) over DynamicItems{S8}(Vector{AShape}) | 33.76 / 30.67 | 8.1 | 32.43 / 37.68 | 8.1 |
| n = 8 implementations | view | Σ area8(x) over DynamicItems{S8}(Vector{Any}) | 34.36 / 31.79 | 8.1 | 36.33 / 36.11 | 8.1 |
| n = 8 implementations | direct | Σ area8(x), total8(v) with the user's Vector{AShape} | 35.22 / 31.02 | 8.1 | 35.02 / 33.76 | 8.1 |
| n = 8 implementations | direct | Σ area8(x), total8(v) with the user's Vector{Any} | 32.20 / 32.06 | 8.1 | 32.96 / 38.03 | 8.1 |
| n = 8 implementations | make | collect(DynamicItems{S8}(v)): the copy | 10.07 / 9.42 | 8.1 | 9.67 / 10.19 | 8.1 |
| n = 64 implementations | plain | Σ parea64(x) over Vector{AShape} | 101.55 / 98.34 | 32.0 | 103.95 / 100.15 | 32.0 |
| n = 64 implementations | interop | the same in a trait module | 111.50 / 106.98 | 32.0 | 110.15 / 109.08 | 32.0 |
| n = 64 implementations | copy | Σ area64(x) over Vector{Dynamic{S64}} | 80.84 / 78.31 | 15.0 | 82.82 / 80.24 | 15.0 |
| n = 64 implementations | view | Σ area64(x) over DynamicItems{S64}(Vector{AShape}) | 175.79 / 160.16 | 15.0 | 165.27 / 167.85 | 15.1 |
| n = 64 implementations | view | Σ area64(x) over DynamicItems{S64}(Vector{Any}) | 166.99 / 161.46 | 15.0 | 165.62 / 169.62 | 15.1 |
| n = 64 implementations | direct | Σ area64(x), total64(v) with the user's Vector{AShape} | 165.93 / 160.07 | 15.1 | 166.74 / 167.88 | 15.1 |
| n = 64 implementations | direct | Σ area64(x), total64(v) with the user's Vector{Any} | 165.87 / 162.12 | 15.0 | 164.91 / 167.52 | 15.0 |
| n = 64 implementations | make | collect(DynamicItems{S64}(v)): the copy | 76.82 / 74.09 | 8.1 | 77.96 / 78.16 | 8.1 |
| n = 64, one type only | copy | only P1: Vector{Dynamic{S64}} | 1.41 / 1.37 | 0.1 | 1.14 / 1.17 | 0.1 |
| n = 64, one type only | view | only P1: DynamicItems{S64}(Vector{AShape}) | 1.41 / 1.37 | 0.1 | 1.45 / 1.48 | 0.1 |
| n = 64, one type only | direct | only P1: total64(v), the user's Vector{AShape} | 1.42 / 1.38 | 0.1 | 1.43 / 1.50 | 0.1 |
| n = 64, one type only | plain | only P1: plain, 64 methods | 36.38 / 34.89 | 32.0 | 32.53 / 34.91 | 32.0 |
| n = 64, one type only | copy | only P4: Vector{Dynamic{S64}} | 1.62 / 1.67 | 0.1 | 1.24 / 1.27 | 0.1 |
| n = 64, one type only | view | only P4: DynamicItems{S64}(Vector{AShape}) | 1.52 / 1.55 | 0.1 | 1.54 / 1.58 | 0.1 |
| n = 64, one type only | direct | only P4: total64(v), the user's Vector{AShape} | 1.53 / 1.56 | 0.1 | 1.52 / 1.57 | 0.1 |
| n = 64, one type only | plain | only P4: plain, 64 methods | 37.15 / 37.34 | 32.0 | 35.58 / 39.96 | 32.0 |
| n = 64, one type only | copy | only P5: Vector{Dynamic{S64}} | 21.76 / 25.42 | 16.1 | 18.07 / 22.07 | 16.1 |
| n = 64, one type only | view | only P5: DynamicItems{S64}(Vector{AShape}) | 41.32 / 41.32 | 16.1 | 38.31 / 40.33 | 16.1 |
| n = 64, one type only | direct | only P5: total64(v), the user's Vector{AShape} | 41.26 / 39.71 | 16.1 | 38.42 / 40.43 | 16.1 |
| n = 64, one type only | plain | only P5: plain, 64 methods | 37.91 / 35.79 | 32.0 | 36.29 / 36.41 | 32.0 |
| n = 64, one type only | copy | only P64: Vector{Dynamic{S64}} | 23.67 / 24.62 | 16.1 | 22.29 / 24.84 | 16.1 |
| n = 64, one type only | view | only P64: DynamicItems{S64}(Vector{AShape}) | 46.23 / 38.26 | 16.1 | 44.41 / 43.78 | 16.1 |
| n = 64, one type only | direct | only P64: total64(v), the user's Vector{AShape} | 46.30 / 38.00 | 16.1 | 44.56 / 43.58 | 16.1 |
| n = 64, one type only | plain | only P64: plain, 64 methods | 39.41 / 38.36 | 32.0 | 40.19 / 38.88 | 32.0 |

### The interop numbers again (E-143), runs r2 and r3

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

**The implicit crossing costs what the explicit view costs** (r6, r7, indicative): every "direct" row is within the run-to-run spread of its "view" row, in both settings: `retain!` 2.7–2.9 against 2.8–3.3 ns, counting 1.4–1.7 against 1.4–1.7, the `Dict{String,Any}` loop 4.0–4.6 against 4.0–4.7, keyed lookup 12.9–13.6 against 12.9–13.5, 64 types 160–168 against 160–176 ns. The decision is made once per container type and kept in a flag; the entry's work per call is the view's construction. To confirm on a quiet machine.

**Where the item types are among the split's candidates (up to four implementations), idiomatic trait code recovers the tails, in both settings** (r2, r3, through the explicit view; r6 and r7 give the same with the crossing):
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
