# W-160: the compiler for one way to erase (D-1, D-3)

The third wave of [the plan](../../../writeup/plans/2026-11-15-next-iteration.md) (§6), on `julia-next` (branch `next`) with TraitWorld `unified`:
- (a) a positive membership decided where the type is known: `new`'s field test, a store's value test, a `typeassert` (GT-19's fix);
- (b) the forwarders made where a method is defined, by the library's expansion hook (in place of `@erasing`);
- (c) the definition-time check read from the method's instance at the box in Julia's cache, and the membership walk keeping that instance;
- (d) principled ways of making the design fast: taken where a rule of the design lets the compiler do less, measured otherwise.

Current numbers: [the evidence](../../../writeup/design/evidence.md#one-way-to-erase-the-compilers-part-w-160-e-436-to-e-444). The registry rows: E-436 to E-444.

## How to run

Every script: `source experiments/unification/w160/env.sh` first (W-160's depot stacked before the shared one; `$JN` is `julia-next`, `$JU` `julia-unified`).

| | What | Run |
|---|---|---|
| `suites.sh` | Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` tests and the library's suite | `bash suites.sh julia-next <label> [tests] [library]` |
| `ports.sh` | the ODE port's suite and NetworkDynamics' test subset | `bash ports.sh <label>` |
| `box/run.sh` | E-436: E-407's box variants, head against the baseline's attribute, with the IR | `bash box/run.sh <label> [runs]` |
| `calls/run.sh` | E-437: E-402's calls, head (`calls.jl`) against the baseline (E-374's script) | `bash calls/run.sh` |
| `nd/run.sh` | E-438: NetworkDynamics' workload and E-313's probe, head against the tag; `nd/summarize.py` tabulates | `bash nd/run.sh <label> [runs]` (precompile `nd/env_head` and `nd/env_base` first) |
| `late/late.jl` | E-439, E-444: what a late load ends after upstream CSV's and DataFrames' work | `$JN --project=late/env_head late/late.jl $TW_ROOT/experiments/interfaces/App/data/sample.csv` (`$JU`, `env_base` for the baseline) |
| `check/mistakes.jl` | E-440: E-401's mistakes, read at the box | `$JN --project=$TW_ROOT/TraitWorld-unified check/mistakes.jl` |
| `check/edit.jl`, `check/edit_table.jl` | E-440: an edit's cost and what it infers, the check cached or apart | `$JN --project=$TW_ROOT/TraitWorld-unified check/edit.jl cache\|apart 5` |
| `check/kept_own.jl` | E-444's gate: the walk replays a method at a bound the signature sets at its own signature | `$JN --project=$TW_ROOT/experiments/unification check/kept_own.jl` |
| `check/new_fold.jl` | E-436's check: the fold at `new` records its edge, a non-member is still refused | `$JN --project=$TW_ROOT/TraitWorld-unified check/new_fold.jl` |
| `check/stores.jl` | E-441: whether a store into storage typed by the trait queries the membership when it runs | as above |
| `check/callable_path.jl` | E-442: a call through `Dynamic{Callable{A, S}}`, part by part | as above |
| `check/erased_op.jl` | E-443: an operation on a value known only by its trait | as above |

`scratch/` holds the debugging scripts of the work, and `scratch/lift-open-parameters.diff`, the prototype of open issue 204's proposal (not kept: traits §7.8 excludes it).

## Results, 2026-11-15

`julia-next` 75a7f1795b (the final build) with TraitWorld `unified` 9c0912b, TraitDifferentialEquations `unified` b5747a0, NetworkDynamics `unified` 6d311a3 (local; ndport cad389d), TraitMakie at `wt/w160-tm` (c862914; the logs of E-438 name TraitMakie-unified's head by mistake); the baseline `julia-unified` 7b374f39ce with TraitWorld-base e11c7cc and the tag's ports. Product setting, strict mode off, one thread; load 2 to 8 of 128. Earlier builds where a row says so.

**E-436, the box made by the forwarder** (10^7 calls, the minimum of 7, two processes; ns a call, bytes a call; `box/logs/e444-*`):

| | head | baseline |
|---|---|---|
| the attribute (compiled once, the object passed) | — | 7.26–7.27, 16 |
| `:new` generated per member type | 9.13, 16 | |
| `:new` by `@eval` | 9.13–9.14, 16 | |
| a member by its definition | 8.91–8.92, 16 | |
| the forwarder compiled once, not inlined | 11.09, 16 | |
| the forwarder inlined into a typed caller | 8.82, 16 | |
| `jl_new_struct` (the prototype's box) | 26.6–26.9, 32 | |
| a box held | 4.57, 0 | |

No `ijl_isa` or `ijl_subtype` in any IR (`box/logs/e444/`). On 8b1ec88a56 with the flag (`box/logs/e436c-*`): 9.12–9.51 ns. Before the change (E-407): 105 ns by `:new`.

**E-437, E-402's calls** (`calls/logs/`, ns a call, two processes each):

| Row | head | baseline |
|---|---|---|
| 3: a plain member to a method of a trait that erases by default | 8.28–8.40 | 7.19–7.32 |
| 3: a box held | 7.14–7.15 | — |
| 3: `compiled_for`; plain | 2.38; 2.38 | 2.38; 2.38 |
| 4: an element of a `Vector{Shape}` | 3.02 | 2.86–2.87 |
| 5: a field `::Dynamic{Shape}` | 5.56 | 5.56 |
| 6: a `Callable` argument, the default (boxed); `compiled_for(f)` | 23.9–24.5; 0.79 | 274.8–278.1 (`with_dynamic`); 1.34 |
| 1, 2: at a known type | 0.79 | 0.79 |

On 5b1900641f with TraitWorld d537141, before the `Callable` box's call at its own parameters: row 3 8.16–8.17 against 7.34–7.41; row 6 152 ns.

**E-438, NetworkDynamics' workload** (a warm-up and runs; `nd/logs/`):

| | head | baseline |
|---|---|---|
| the session (s) | 42.9 (final); 42.8–43.4 (5b1900641f) | 43.7–43.9; 43.5–44.3 |
| the first pass (s) | 19.71–19.74; 19.77–19.93 | 19.63–19.66; 19.65–19.91 |
| the steady state, `again` d (ms) | 199.8–205.8; 173.2–202.7 | 197.6–207.1; 197.7–208.8 |
| new equations, `changed` b–e (ms) | 567–572 (a full GC of 99–100 ms in step d; 468–472 without it); 465–568 | 510–519; 509–544 |
| `graphtype` (s) | 7.84–7.87; 7.86–7.93 | 8.27–8.30; 8.25–8.39 |
| E-313's probe of step d (ms) | 168–194; 173–192 | 200–226; 199–223 |

The digests equal the baseline's in every run.

**E-439 and E-444, a late load** (`late/logs/e444-*-{2,3}.log`, the same hour):

| | head (final) | baseline |
|---|---|---|
| `using TraitWorld`: plain instances ended | 224 of 120,002 | 217 of 121,250 |
| `using TraitDifferentialEquations`: plain instances ended | 767 of 121,916 | 757 of 123,147 |
| its log entries | 2,248 | 2,253 |
| `jl_method_table_disable` entries (the walk's conservative path) | 0 | 0 |
| instances at a box ended; valid after the load | 0; 656 | 0; 513 |

On 5b1900641f (`late/logs/e439-head-b.log`): 14 `jl_method_table_disable` entries at the ODE port's load, at TraitIndexing's methods at the kept forms, 2,454 log entries. Every group of ended instances is a plain method's insertion (ForwardDiff's, BaseTraits'); the head's and the baseline's groups differ only in plain code, and the baseline varies by 16 between runs at different hours (201 at 15:06, 217 at 15:33).

**E-440, the check read from Julia's cache** (`logs/e440-*`):
- E-401's mistakes: the same faults at the same lines, the same messages (`logs/e440-mistakes-head.log` against `../w151/logs/e401-mistakes.log`).
- An edit (`check/edit.jl`, a method of four lines; `check/edit_table.jl`, TraitTables' `summarize` with its callees), the median of 5 edits after a warm-up, two processes:

  | | cached | apart |
  |---|---|---|
  | `edit.jl`: the definition; a box's first call (ms) | 4.2–4.4; 15.3 | 3.6; 15.2–15.7 |
  | `edit_table.jl`: the definition; a box's first call (ms) | 4.5–4.6; 10.4 | 4.1; 10.4 |
  | the method's instance at the box inferred | once, at the definition | at the check (apart) and at the call |

- The library's suite caught a first version that read the instance a box's call runs where that is the attribute's instance at the trait (a trait without the default, `test/attribute.jl`): such a method is read apart.

**E-441** (`logs/e441-*`; the head on 8b1ec88a56 with the statement flag, the baseline `julia-unified`): a store of a known member into a `Vector{Shape}` (`v[i] = c`, `push!`), into a field `::Shape`, a struct made with such a field, and `Dynamic{Shape}(c)` query the membership when they run on the baseline, 91–99 ns a store; on the head none does: a store into the vector 0.44 ns, into the field 0.17 ns. A `typeassert` and `convert(Shape, c)` query on neither. Without the flag, the head queried at the stores too (88 ns).

**E-442** (`logs/e442-*`): a call through `Dynamic{Callable{Tuple{Float64}, Float64}}` 167 ns before, 23.9 ns after the box's call at its own parameters; the object called directly 23.7 ns, a function held as `Any` 22.2 ns; `isa Callable{A, S}` when it runs 717–750 ns (compiler C-116: subtyping reads the methods).

**E-443** (`logs/e443-*`): an operation on a box of the first member 5.56 ns, of the sixth (through the table's pointer) 9.14 ns, at a known type 0.79 ns, Julia's dynamic call 18.4 ns; the sixth member's first call 22 ms in a fresh process.

**E-444's gates**: `check/kept_own.jl` fails before (the callers at the other members ended, 4 of 4) and passes after; the walk's gates `m[12]_*` (30) and `n*` (34) pass before and after (`logs/e444-gates-*.log`; the `m3_*` gates need packages this project lacks, as before).

**The suites on the final build** (`logs/e444-summary.log`, `logs/e444b-summary.log`): Julia's four test files pass; the library's suite, 90 testsets; the ODE port's, 35; NetworkDynamics' subset as on W-151's build (diffusion 108 passed, 1 failed, 1 error, 24 broken; inhomogeneous 39 passed, 1 error, 12 broken).
