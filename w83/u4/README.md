# E-256 (U4): is an untyped function a `Dynamic` over `Any`?

The question (registry row E-256; exploration `writeup/explorations/abstract-types-as-traits.md` §3 rule 5 and §10): does `f(@nospecialize x)` behave as a `Dynamic{X}` position does: compiled once, every operation on `x` a run-time site, its result `Any` against the declared result?

## How to run

From this directory (one Julia job per line; timings exclusive):

    ../../tools/jl --name w83u4 ../../../julia-1.13/julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
    U4_TIME=0 ../../tools/jl --name w83u4 ../../../julia-1.13/julia --startup-file=no --project=. u4.jl > logs/census-product.log
    U4_TIME=0 ../../tools/jl --name w83u4 ../../../julia-1.13/julia -J ../../../julia-1.13/usr/lib/julia/facts/sys.so --startup-file=no --project=. u4.jl > logs/census-all.log
    JULIA_DEPOT_PATH=~/.julia/agent-depots/w83u4:~/.julia: ../../tools/jl --exclusive ../../../julia-1.13/julia [-J …/facts/sys.so] --startup-file=no --project=. u4.jl > logs/run2-<setting>.log
    ../../tools/jl --name w83u4 ../../../julia-1.13/julia [-J …/facts/sys.so] --startup-file=no nospec_probe.jl

- `u4.jl`: twelve types `P1`–`P12`; a plain twin `parea` (12 methods) and `qarea` (2 methods); a trait `Sh` with one operation `area(s::Sh)::Float64`, implemented by all twelve.
  - Untyped forms: `fu4(@nospecialize x) = parea(x) + 1.0` and `fu2` (over `qarea`) in `Main`; `tu4`, `tu2`, `tua` (over `area`) the same in the trait module, so compiled by facts in both settings.
  - Bounded forms: `gd(x::Dynamic{Sh}) = area(x) + 1.0` (an annotation), `gb(x::Sh)` called with values that carry `Dynamic`.
  - **Census:** every method's specializations and their CodeInstances before and after each call; the new ones listed with their owner (plain or facts). Each kind of caller gets types not seen before: top-level calls `P1`–`P4`, typed callers `P5`–`P8`, callers that do not know the type (`v::Vector{Any}`) `P9`–`P12`.
  - `code_typed` of each form under the compiler that compiles it in the setting.
  - **Timings:** a loop over 1000 values cycling `P1`–`P4` (or `P1`–`P2`), one call per value; BenchmarkTools, median time and median allocation per call over up to 2000 samples or 2 s.
- `nospec_probe.jl`: whether a typed caller makes `f(@nospecialize x)` specialize, inlined and `@noinline`.

## The build

julia-1.13 00dcc9994c, TraitWorld 33dd55e (main), strict mode off. Product setting and the test bed `all` (`-J julia-1.13/usr/lib/julia/facts/sys.so`). Code defined in the script, not loaded from a package image. Census runs in a slot (`jl --name w83u4`); timings `jl --exclusive`, one process per setting per run, two runs. Load average (1 min) at the runs' starts: 1.3–2.9.

## Results (2026-10-29)

### CodeInstances

| Form | caller | the function's own CodeInstances | new CodeInstances per new argument type (product / all) |
|---|---|---|---|
| `fu4(@nospecialize x)`, `Main` | does not know the type (top level, `v::Vector{Any}`) | one, `fu4(::Any)` (plain in product, facts under `all`) | 2 / 1: the callee `parea(::P)` (and `getproperty` in product) |
| `tu4`, `tua` (`@nospecialize`), trait module | does not know the type | one, `tu4(::Any)`, facts in both | 1 / 0: the callee (`area` on a raw `P` is already compiled) |
| `fu4`, `tu4` | **knows the type** (`cu4(x) = fu4(x)`, `x::P5`) | **one per argument type**: `fu4(::P5)` … `fu4(::P8)`, both settings | 3–4 / 2–3 |
| `gd(x::Dynamic{Sh})` | any | one worker, `gd(::Sh at Dynamic)`, facts in both | 45 / 32 (see below) |

- **`@nospecialize` is not erasure for inference** (`nospec_probe.jl`): a caller that knows `x`'s type infers `f(@nospecialize x)` at that type, one CodeInstance per type. Inlined where small (the typed caller's code then has no call left, result `Float64`). `@noinline`: the native call is `invoke big(::Any)`, but the caller's result is the per-type inferred `Float64`. Same in both settings.
- **A `Dynamic{Sh}` worker is compiled once**, whatever the held type. Its operation is the split with the declared result: `area(x)` is a table call (`jl_split_table_ptr`, twelve implementations) typed `Float64`.
- **Per new held type**, a `Dynamic` value at the bound compiles 45 (product) / 32 (`all`) CodeInstances:
  - the view of `Sh` for the held type and the split table's target (facts, 25–38);
  - the entry's assembly at the held object's type: `_enter_keyed`, `_enter_erased`, `_erase`, the erased `View`'s constructor, two `indexed_iterate` (6; plain owner in product). The entry calls `_enter_keyed(p, held)` with the held object at its run-time type (lowering §8.2, `_enter_held`), so this is also a dispatch at every call.
- **The result at the caller:** the entry returns `Any` (`checked_call`) for `gd` (no declared result), also when called from trait code (`tloopd`, `tloopi`). The untyped form returns `Any` as well.

### `code_typed`

| Form | product | `all` |
|---|---|---|
| `fu4(::Any)`, `Main`, 12 methods | `parea(x)` a call, `::Any` | the same (facts) |
| `fu2(::Any)`, `Main`, 2 methods | union-split into `isa` branches with `invoke`s, result `Float64` (plain inference's guess from the method table) | `qarea(x)` a call, `::Any` |
| `tu4`, `tu2`, `tua` (trait module) | the call `::Any` | the same |
| `gd(::Sh at Dynamic)` | the split, `::Float64` | the same |

### Time per call (ns, median; B per call; `logs/run1-*`, `logs/run2-*`)

1000 values cycling 4 types (2 where named), one call per value.

| Row | product run1 / run2 | `all` run1 / run2 | B/call |
|---|---|---|---|
| `fu4(@nospecialize)` `Main`, over `Vector{Any}` | 71.9 / 73.5 | 96.4 / 97.8 | 48 |
| `tu4(@nospecialize)` trait module | 74.1 / 76.3 | 96.5 / 101.1 | 48 |
| `tua(@nospecialize)` (`area` on a raw value) | 76.3 / 78.3 | 96.3 / 99.1 | 48 |
| `gd(x::Dynamic{Sh})` from a `Main` loop over `Vector{Dynamic{Sh}}` | 80.7 / 84.3 | 83.1 / 84.2 | 80 |
| `gb(x::Sh)`, `Dynamic` values | 80.8 / 84.3 | 89.1 / 91.3 | 80 |
| trait code: `tloopd` (`gd(x)` over `Vector{Dynamic{Sh}}`) | – / 95.4 | – / 88.1 | 80 |
| trait code: `tloopi(xs::Iterable{Sh})`, `gd(x)` | – / 96.2 | – / 87.0 | 80 |
| `fu2(@nospecialize)` `Main`, 2 types | **0.91 / 0.93** | 94.1 / 94.8 | 0 / 48 |
| `tu2(@nospecialize)` trait module, 2 types | 72.5 / 73.4 | 95.1 / 97.1 | 48 |
| the operation alone: `parea(x)`, `x` from `Vector{Any}` | 47.9 / 50.3 | 50.6 / 51.4 | 32 |
| the operation alone: `area(x)`, `x::Dynamic{Sh}` | 1.29 / 0.96 | 0.93 / 1.44 | 0 |
| one call, the argument from a `Ref{Any}`: `fu4` / `gd` | 46.9 / 47.6 ; 92.5 / 105.1 | 67.8 / 68.0 ; 159.4 / 163.8 | 32 ; 64 |

## Answer

**Rule 5's reading holds where the caller does not know the argument's type**, in both settings: the untyped form has one CodeInstance, and every call on `x` in code compiled by facts is a run-time site typed `Any` (the trait module's code in both settings, everything under `all`). Against it, the `Dynamic{Sh}` position's operation is the split with the declared result: 1 ns against 50 ns and 32 B for the run-time site.

**Where the two paths diverge** (to state in facts §5 before level 3 is weighed):

1. **A caller that knows the type.** `@nospecialize` is a hint to dispatch and code generation, not erasure: inference specializes the untyped function per known argument type (one CodeInstance each, inlined where small, the caller's result typed). A `Dynamic` value hides its held type from every caller, so its worker is inferred once. "`f(@nospecialize x)` is `f(x::Dynamic{Any})`" is true only at callers that do not know `x`'s type.
2. **The entry.** An untyped function takes the value as it is. A bounded function's entry assembles the trait object from the held object at its run-time type, also for a `Dynamic` value: a dispatch per call, and CodeInstances per held type. At function granularity a `Dynamic` position costs as much as an untyped call (80–96 ns and 80 B against 72–101 ns and 48 B here), although the body costs 1 ns. Under the model, a `Dynamic{Any}` position needs no assembly, so it would match the untyped form. For `Dynamic{X}` with a contract, this cost is the current lowering's, not the model's.
3. **Plain code in the product setting** guesses the contract of `Any` from the method table (rule 6): with two methods, `fu2` is union-split, 0.9 ns, result `Float64`. The same code under facts is a run-time site, 73–97 ns. This is the difference rule 6 names, measured.
