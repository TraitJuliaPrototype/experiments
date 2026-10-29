# E-257 (U2): do the kept forms collapse without a cost?

The question (registry row E-257; exploration `writeup/explorations/abstract-types-as-traits.md` §5.2 and §10): is a container of raw members and `Dynamic{X}` wrappers (`Vector{X}` under the model; `Vector{Any}` is the closest today's build has), read by a loop that branches on `isa Dynamic` and then runs the split, as cheap as `Vector{Kept{X}}`?

## How to run

From this directory, exclusive (it is a timing):

    ../../tools/jl --name w83u4 ../../../julia-1.13/julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
    JULIA_DEPOT_PATH=~/.julia/agent-depots/w83u4:~/.julia: ../../tools/jl --exclusive ../../../julia-1.13/julia --startup-file=no --project=. u2.jl > logs/run2-product.log
    JULIA_DEPOT_PATH=~/.julia/agent-depots/w83u4:~/.julia: ../../tools/jl --exclusive ../../../julia-1.13/julia -J ../../../julia-1.13/usr/lib/julia/facts/sys.so --startup-file=no --project=. u2.jl > logs/run2-all.log
    U2_TYPED=1 …  u2.jl      # code_typed of the two collapse loops only

- **E-164's setup, reused:** the shapes and traits of `../../hetero-idiomatic/shapes_defs.jl` (`S2`, `S4`, `S8`: exactly 2, 4, 8 implementations), its measurement (`common.jl`: median time per element over BenchmarkTools' samples, up to 2000 or 2 s, and the median allocation), 1000 elements cycling the n types. E-164 has no `Vector{Kept{S}}` loop; its copy row (`total_n` over `Vector{Dynamic{S}}`) is measured again here, and the `Kept` loop is new, on the same items.
- **The items:** element i has type `P(mod1(i, n))`; it is wrapped in every second run of n elements, so each type is half raw, half wrapped. The `Kept` vector holds the same: raw as `Compiled`, wrapped as `Dynamic`.
- **The loops,** in a trait module (compiled by facts in both settings), written as the lowering writes an operation on a held value (`Compiler.split_call` over the held object, `TraitWorld/src/trait.jl`):
  - `kloop`: `Vector{Kept{S}}`, `op(k)` (the split on the object);
  - `dloop`: `Vector{Dynamic{S}}`, `op(d)`;
  - `cloop` (the collapse): `Vector{Any}`, `x isa Dynamic{S} ? op(x) : <the split on x>`, the split written out at the call;
  - `cloopw`: the same, a raw member wrapped on read by `@dynamic_of` (what `DynamicItems` does);
  - and today's spellings at the bound: `total_n(amix)` (the mixed `Vector{Any}` crossing) and `total_n(kmix)`.

## The build

julia-1.13 00dcc9994c, TraitWorld 33dd55e (main), strict mode off; product setting and the test bed `all`. Idiomatic trait code (a trait module's loops over its own trait's values). `jl --exclusive`, one process per setting per run, two runs. Load average (1 min) at the runs' starts: 3.6 (run1 product), 1.6, 1.5, 1.5.

## Results (2026-10-29; ns per element, medians; no row allocates per element)

The mixed containers (half raw or `Compiled`, half `Dynamic`):

| n | setting | `Vector{Kept{S}}` run1 / run2 | `Vector{Any}`, `isa` + split run1 / run2 | ratio | `isa` + `@dynamic_of` | `total_n(amix)` (crossing, today) | `total_n(kmix)` |
|---|---|---|---|---|---|---|---|
| 2 | product | 1.24 / 1.14 | 1.45 / 1.62 | 1.17 / 1.42 | 1.62 / 1.91 | 2.73 / 2.37 | 1.20 / 1.16 |
| 2 | `all` | 1.15 / 1.12 | 1.74 / 1.38 | 1.51 / 1.23 | 1.91 / 1.54 | 2.71 / 2.46 | 1.50 / 1.45 |
| 4 | product | 1.57 / 1.20 | 1.99 / 1.88 | 1.27 / 1.57 | 2.33 / 2.07 | 2.51 / 2.59 | 1.37 / 1.29 |
| 4 | `all` | 1.56 / 1.54 | 1.80 / 1.93 | 1.15 / 1.25 | 2.08 / 2.18 | 3.05 / 2.97 | 1.33 / 1.24 |
| 8 | product | 5.26 / 5.18 | 5.95 / 5.52 | 1.13 / 1.07 | 7.92 / 8.19 | 8.95 / 8.39 | 5.20 / 4.95 |
| 8 | `all` | 5.02 / 4.95 | 5.61 / 5.45 | 1.12 / 1.10 | 8.19 / 7.63 | 8.52 / 7.94 | 4.92 / 4.84 |

One attribute only (run2; product / `all`):

| n | `Kept`, all `Compiled` | `Kept`, all `Dynamic` | `Vector{Any}`, all raw | `Vector{Any}`, all `Dynamic` | `Vector{Dynamic{S}}` (`dloop`) | E-164's copy row (`total_n`), today | E-164 night1 (26a407d988) |
|---|---|---|---|---|---|---|---|
| 2 | 1.14 / 1.12 | 1.15 / 1.13 | 1.10 / 1.29 | 1.46 / 1.51 | 1.14 / 1.12 | 0.96 / 0.94 | 0.97 / 1.03 |
| 4 | 1.19 / 1.66 | 1.20 / 1.66 | 1.12 / 1.57 | 2.16 / 1.76 | 1.67 / 1.65 | 1.21 / 1.31 | 1.37 / 1.43 |
| 8 | 5.12 / 4.97 | 5.07 / 4.97 | 4.81 / 4.92 | 5.69 / 5.08 | 4.86 / 4.49 | 4.93 / 4.65 | 4.81 / 4.65 |

- **No allocation per element** in any loop. The union form's boxing (alternatives: 3,248 against 48 bytes) does not recur: a raw member is already boxed by the container, and the wrapper is kept as it is.
- **Raw members cost what `Kept` costs, or less** (1.10–1.57 against 1.12–1.66 ns at n ≤ 4).
- **The cost is the wrapper inside `Vector{Any}`:** box, then `Dynamic`, then the object: two loads where `Kept`, stored inline, has one. All `Dynamic` in `Vector{Any}`: 1.46–2.16 ns against 1.13–1.66 for `Kept`.
- **Mixed, n = 2 and 4:** 15–57 % above `Kept` (+0.2 to +0.7 ns), above 20 % in 6 of the 8 cells. **n = 8:** 7–13 % (the split's table dominates).
- **The split must be written out at the call** (`logs/dev-product-split-as-function.log`): with the split in a helper function taking the `Any`-typed member, the call is a run-time site of facts code, 127–234 ns and 32 B per element (`code_typed`: `splitraw(…)::Any`). Under the model the item is typed `X`, an abstract type, so an operation on it must become the compiler's split, as `split_call` is today, and not a method call at `X`.

## Answer

**By the row's criterion, the wrapper stays in storage: level 1 keeps `Kept{X}`.** There is no allocation per element. But the mixed `Vector{Any}` loop is above 20 % for n = 2 and 4 in six of eight cells (two runs, both settings). It is within 20 % only at n = 8.

The excess is small in absolute terms (+0.2 to +0.7 ns per element). It comes from the wrapped items, not from the raw ones: a raw member read from the container and split costs what a `Kept` item costs. A collapse would cost nothing where values are mostly `Compiled`, and a few tenths of a nanosecond per `Dynamic` item.
