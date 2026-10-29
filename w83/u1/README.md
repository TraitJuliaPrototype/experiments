# U1 (E-258): how much generic code is fully bounded as written?

The exploration's rule 4 (`writeup/explorations/abstract-types-as-traits.md` §3, §10) classifies each function once, at its definition: **fully bounded** if its body reaches each bounded argument only through the set's contract, **open** otherwise. This experiment takes generic code as it is written today, changes only the annotations to bounds, and runs TraitWorld's definition checker at archetypes.

**Would change the plan** (registry row E-258): above a third fully bounded, or open only for a few named operations (`similar`, `axes`): level 3 buys sharing for existing code, and the contracts to write are short. Below: level 3 is a simplification of the language only.

## Answer

**Below a third, and open for a long tail of operations, not a few.** Level 3 is a simplification of the language; it buys little sharing for existing code.

- With the existing traits (variant A): **4 of 74** fully bounded (5%).
- With each abstract type's documented interface added to the contract, `similar` and `axes` included (variant B): **13 of 74** (18%).
- Counting a function that returns its bounded argument as fully bounded (rule 4 allows it; today's checker does not): **20 of 74** (27%).
- The open functions reach about 50 distinct functions. The largest groups: a call into another generic function with the value (31 functions), an adaptor that wraps the value (`zip`, `enumerate`, a generator, `view`, broadcasting, a conversion `Vector{Float64}(x)`: 18), returning the argument (11), `eltype(x)` (5).
- Adding Base's documented array interface to the contract (`similar` and `axes` among it) turns one Base function from open to fully bounded: `zero`, through `similar(x, T)`.

What is fully bounded: code already written against a narrow contract. NetworkDynamics' core loop over component dynamics (`_vertex!`, `_edge!`) is fully bounded as written in both variants. Makie's point loops (`_points`, `_matrix`, `extrema_nan`, `_crange`) and Graphs' self-loop counts are fully bounded once the abstract type's documented interface is in the contract. DataFrames' column code is open in every case.

## How to run

```
experiments/w83/u1/run.sh <log name>      # e.g. run5; one Julia job through experiments/tools/jl, about 30 s after loading
python3 experiments/w83/u1/categorize.py B   # the categories below, from logs/results-B.tsv
```

`run.sh` stacks `forks/env_forks` (DataFrames, Tables, TraitWorld) and `ndport/env_r2plot` (TraitMakie, MakieCompat, Graphs on the ports) on the load path. It sets `JULIA_TW_DEFCHECK=0`, so that the trait modules' own ends do not check; `run.jl` runs the check per function itself.

## Method

- **Samples** (`samples/*.jl`; a line `## id | function | source | original signature` registers one). Each body is the source's, unchanged except:
  - the annotation of each argument that is a vector, column, frame, graph or component is a placeholder for the bound;
  - non-exported internals are qualified (`Base.checked_length`), the function's own name gets the prefix `u_`, and its calls keep the original functions;
  - an element type parameter is the bound's fixed item type, written out (`Float64`, `Point2d`, `Int`): a bound with an open parameter is not checked at archetypes;
  - a callable struct's method is a function taking the struct first, a keyword argument is positional, and a recipe's `map!` closure is a named function (keyword workers and closures are not checked at archetypes);
  - NetworkDynamics' helpers that take no graph and no dynamics are stubs (`NDStubs` in `run.jl`); the component traits are copied from the ports.
- **The check:** for each method with a bounded position, `TraitWorld.archetype_sig` and `TraitWorld.worker_problems`, what `definition_problems` and `check_definitions` run at a trait module's end. Fully bounded: no problem. Open: each problem names what the body reaches.
- **`kwcall`** in a reached list is a keyword call with the value (`fillfirst!(…; rev = …)` in DataFrames' `Aggregate{typeof(first)}`).
- **Two variants of the bounds** (`VARIANTS` in `run.jl`):
  - **A, the existing traits.** Base: BaseTraits' `(Indexable{Float64}, Iterable{Float64})` for a vector read, `MutableIndexable` for one written, `Resizable` added for one resized, `Iterable` for an iterable. DataFrames: `Column{T}` for a column (Tables' `ColumnCore`), `TableSource` for a frame. MakieCompat: `Positions`, `Sample`, `ColorSpec` (TraitMakie's `PlotCore`). NetworkDynamics: `GraphInterface{Int}` (Graphs on the ports), `VertexDynamics`, `EdgeDynamics`.
  - **B, A plus the abstract type's documented interface as a contract**: the exploration's reading of level 3, where the abstract type is the set. `ArrayOps{T}` (`run.jl`): `size`, `axes`, `firstindex`, `lastindex`, `eachindex`, `IndexStyle`, `similar(a)`, `similar(a, S)`, `similar(a, S, n)`, added with BaseTraits' traits to every vector, column and data vector. `GraphOps{V}`: Graphs' required methods `vertices`, `edges`, `outneighbors`, `inneighbors`, `has_vertex`, `edgetype`. `TableSource` and the component traits are unchanged.
- **Two corrections to the checker's coverage**, made in `run.jl` and marked in the log:
  - BaseTraits declares `@trait MutableIndexable{T} <: Indexable`, so the supertrait's item type is open in every bound. `archetype_sig` then defers each function bounded by `MutableIndexable{Float64}` to its first call. `run.jl` ties the supertrait's parameter to the subtrait's and builds the archetype as `archetype_tobj` does. Marked `[MutableIndexable's supertrait parameter tied]`.
  - A call that infers as `Union{}` ends inference: the rest of the body is not checked. `run.jl` lists every such call with a trait object among its arguments (`[inference stops …]`), so the reached list of those functions is a lower bound. One kind is not reported by the checker at all (see Findings 2). `run.jl` adds it as a reach.

### How the samples were chosen (the sample's bias)

- **Base, 25** from `base/abstractarray.jl`. The functions in file order with an `AbstractVector`/`AbstractArray` argument whose meaning is reading or writing items (`first(v, n)`, `copy!`, `copyto!`, `get`, `isequal`, `cmp`, `==`, `map!`, `map`, `push!`, `_keepat!`, `circshift!`, `foreach`, …). Skipped: the array interface's own primitives (`size`, `axes`, `eachindex`, `getindex` machinery, `similar`), pointer and stride code, concatenation machinery, varargs. Bias towards open: these functions are Base's generic layer itself, written against Base's full array API.
- **DataFrames, 20** from the forks' plain layer (`forks/DataFrames`, not the trait module `ColumnKernels`). Column functions with an `AbstractVector` column (fast aggregates, `fillfirst!`, `_findall`, joins' `compose_joined_rcol!`, `repeat_lengths!`, `_cycle_permute!`, `similar_outer`, `check_aggregate`). Frame functions with an `AbstractDataFrame` whose meaning is reading names, columns or rows (`==`, `isequal`, `isempty`, `size`, `ncol`, `completecases`). Skipped: constructors, `select`/`transform` machinery, functions taking only index vectors.
- **MakieCompat, 17**: every function in `MakieCompat.jl`, `upstream/band.jl`, `upstream/stairs.jl` and TraitMakie's old-API layer (`TraitMakie.jl`) whose argument is a data vector: points, numbers or colours. Bias towards bounded: small functions that read a vector.
- **NetworkDynamics, 12.** NetworkDynamics' plain code takes a graph in few places, and the dynamics only in the core loop. Five from NetworkDynamics: the feed-forward check (upstream form), `_prune_blocks!`, the index manager's graph lines, `_vertex!`, `_edge!`. Seven of Graphs' generic functions over `AbstractGraph` that NetworkDynamics' graph code calls: `degree`, `degree_histogram`, `has_self_loops`, `num_self_loops`, `noallocextreme`, `is_connected`, `common_neighbors`.

## Results (2026-10-29)

julia-1.13 00dcc9994c, TraitWorld 33dd55e, forks 943b065, TraitMakie c0d5c36, Graphs-p4 54632125, NetworkDynamics-ports dfc6663 (bodies copied). One run (a check, not a measurement); load average 3.8. Log `logs/run5.log`; per sample `logs/results-A.tsv`, `logs/results-B.tsv`. `logs/dev/` holds four earlier runs of the driver while its coverage was being corrected; they are not results.

| sample | n | A: fully bounded | B: fully bounded | B, returning the argument allowed |
|---|---|---|---|---|
| Base `abstractarray.jl` | 25 | 2 | 3 | 7 |
| DataFrames (forks) | 20 | 0 | 0 | 3 |
| MakieCompat | 17 | 0 | 5 | 5 |
| NetworkDynamics + Graphs | 12 (5 + 7) | 2 (2 + 0) | 5 (3 + 2) | 5 |
| **all** | **74** | **4 (5%)** | **13 (18%)** | **20 (27%)** |

Fully bounded in B: Base `isempty`, `foreach`, `zero`; MakieCompat `_points`, `_matrix`, `extrema_nan`, `_one`, `_crange`; NetworkDynamics `_prune_blocks!`, `_vertex!`, `_edge!`; Graphs `has_self_loops`, `num_self_loops`. In A only `isempty`, `foreach`, `_vertex!`, `_edge!`.

Open only by returning the bounded argument, in B: Base `copyto!` (iterable and offset forms), `map!`, `push!`; DataFrames `fillfirst!`, `_cycle_permute!`, `compose_joined_rcol!`.

### What the open ones reach, ranked (number of open functions reaching it)

Variant A (the existing traits): `eachindex` 7, returning the argument 7, `firstindex` 6, `getindex` 6, `eltype` 5, `length` 5, `vertices` 4, `lastindex` 3, `setindex!` 3, `similar` 3, `size` 3, `Vector{Float64}(x)` 2, `axes` 2, `edges` 2, `enumerate` 2, `isempty` 2, `iterate` 2, `nrow` 2, then 31 functions once each. With the ports' traits, most of these are Base's names for what the port's trait calls otherwise (`length` against `nrows`/`npoints`/`nvalues`, `getindex` against `cell`/`pointx`), or Base's array API, which the port's trait leaves out.

Variant B (documented interfaces as contracts): returning the argument 11, `eltype` 5, `Vector{Float64}(x)` 4, `zip` 4, `size` 3 (a frame's), a function argument called with the value 3, `checked_length` 2, `copyto!` 2, `eachindex(a, b)` 2, `enumerate` 2, `isassigned` 2, `isempty` 2, `nrow` 2, `typeof` 2, then 40 functions once each (`cmp`, `map!`, `copymutable`, `count`, `findfirst`, `reverse!`, `deleteat!`, `nextind`, `checkbounds`, `LinearIndices`, `view`, `vcat`, `copy`, `Base.Generator`, `===`, `isa`, `BoundsError`, `groupreduce`, `connected_components!`, `outdegree`, `neighbors`, …).

By category (`categorize.py`; an open function counts in each category it reaches):

| category | A | B |
|---|---|---|
| another generic function called with the value (`copyto!`, `cmp`, `map!`, `count`, `outdegree`, a frame's `nrow`/`size`/`index`, …; in A also the interface's own `eachindex`, `firstindex`, `length`, …) | 58 | 31 |
| an adaptor that wraps the value (`zip`, `enumerate`, generators and comprehensions, `view`, broadcasting, `Vector{Float64}(x)`, `copy`, `vcat`, a struct that stores it) | 9 | 18 |
| returns the bounded argument | 7 | 11 |
| `eltype(x)` | 5 | 5 |
| identity or type of the value (`===`, `isa`, `typeof`) | 2 | 4 |
| the value passed to a function argument (`degfn(g, v)`, `f(g, i)`) | 1 | 3 |
| a contract's function at an arity the contract does not declare (`eachindex(a, b)`) | 0 | 2 |
| the value shown in an error (`BoundsError(a, …)`) | 1 | 1 |

In B, 22 open functions reach only other generic functions, and 4 more reach only those and return the argument. If every such callee were fully bounded too, these would follow: at most 35 of 74 (13 + 22), or 46 with returning allowed. But the callees in the sample are mostly open themselves: `isless` → `cmp` (open: `zip`), `copy` → `copymutable` → `copyto!` (open: `isa BitArray`, `unalias`), `groupreduce!` → `groupreduce!_helper` (open: `eltype`, `isassigned`). And the adaptors (`zip`, `enumerate`, generators) store the value in a struct parametrised by its type, so a transitive reading does not reach them.

## Findings for the design

1. **The answer to the criterion is "below".** The sharing that rule 4 buys is real only for code written against a narrow contract (the ports' kernels, NetworkDynamics' core loop, Makie's point loops). Generic Julia code as written reaches its arguments through the whole generic layer: it passes them on to other generic functions and wraps them in iterator adaptors. Base's documented interfaces as contracts do not close it. `similar` and `axes` are not the open points; the open points are the call graph and the adaptors. This favours the exploration's §8 item 3 (a simplification of the language) as the headline of level 3.
2. **A checker gap that makes "fully bounded" unsound.** A call to an operation's function at an arity the contract does not declare (`eachindex(res, x)` where the contract declares `eachindex(c)`; before `similar(a, S)` was declared, `similar(x, Float64)`) is neither reported nor resolved. `worker_problems` skips it as an operation (`_is_op` matches the function, not the signature), inference gives `Union{}`, and nothing after the call is checked. The first runs classified Base's `zero` fully bounded this way (`logs/dev/run2.log`). The same `Union{}` cut follows every call the contract does not answer: the checker reports the first reach and never sees the rest of the body (17 of A's open Base functions). The checker's classification is a lower bound on what a body reaches, and for the arity case it is wrong.
3. **BaseTraits' `MutableIndexable{T} <: Indexable` leaves the supertrait's `T` open.** Definition checking then defers every function bounded by `MutableIndexable{T}`, also with `T` fixed, to its first call (`archetype_sig` sees an open parameter). The fix in BaseTraits is `<: Indexable{T}`, if the syntax ties it; else definition checking needs to tie a supertrait's parameter that is defined by the same associated type (`eltype(Self)`).
4. **`eltype(x)` is outside every contract**, although `T = eltype(Self)` is the traits' own associated type. Five DataFrames functions reach it; two reach nothing else. Rule 4's key already contains the associated type. Answering `eltype(x)` at a trait object as a constant of the key would close these.
5. **Returning the bounded argument opens a function today.** Julia's mutating functions return their argument (`push!`, `copyto!`, `map!`). The checker refuses that ("a trait object is a handle, not a value"). Under rule 4 the key is the receiver type, so returning the value is per key and need not open the function. That would raise B from 13 to 20 of 74; still below a third.
6. **The ports' traits use other names than Base's** (`nrows`/`cell`, `npoints`/`pointx`, `nvalues`/`value`). With them alone (A), no DataFrames or MakieCompat function is fully bounded. In the unified model the abstract type's own interface is the contract (B), which is why B is the relevant reading.
