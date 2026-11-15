# W-151: one way to erase, the prototype in the library (stage 1 of the next iteration)

The gate of stage 1 of [the plan](../../../writeup/plans/2026-11-15-next-iteration.md): D-1 (values carry, by type) and D-3 (bounded means fully typed at the box) as a prototype in TraitWorld, with no change to Julia, and two pieces of the ports written with it (the ODE port's front end and callbacks, NetworkDynamics' batch kernel). Registry: E-401 to E-406 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md`. The agent's session note: `session-notes/2026-11-15-agent-w151.md`.

What the prototype is (TraitWorld `unified`): the wrapper `Compiled{T}` that `TraitWorld.ByType.compiled_for(x)` returns, a member of every trait its object is in; `@erasing` at a method definition (the method at the kept forms, `Union{Dynamic{<:X}, Compiled{<:X}}`, and a forwarder that boxes a plain member, for a trait that declares `@default_dynamic`, and `Callable`); `convert` into storage typed `Dynamic{X}`; `check_at_box(m)`, the method's instance at `Dynamic{X}` read by the facts rule (D-3), which `check_definitions` and the `bounded` refusal use.

## How to run

```
source env.sh        # this directory's: the workspace's env.sh, then a depot of W-151's own stacked before the shared one
check/mistakes.jl    # E-401: $JU --project=$TW_ROOT/TraitWorld-unified check/mistakes.jl
calls/run.sh         # E-402: E-374's calls on TraitWorld-base, D-1's forms (calls/calls.jl) on the head; interleaved
nd/mkenvs.sh         # E-403's environments: env_head, env_base (TraitWorld-base, wt/w151-base/{TDE,NetworkDynamics} at the tag)
                     #   then precompile each: $JU --project=nd/env_<head|base> -e 'using Pkg; Pkg.precompile()'
nd/run.sh e403 2     # E-403: NetworkDynamics' workload, a warm-up and 2 runs each, interleaved; E-313's probe of step d
nd/summarize.py nd/logs/e403-*-[0-9].log
late/mkenvs.sh       # E-404's environments (W-134's env_lib with the ODE port), head and base
late/late.jl         # E-404: $JU --project=late/env_<head|base> late/late.jl $TW_ROOT/experiments/interfaces/App/data/sample.csv
count/annotations.jl # E-405: $JU count/annotations.jl <repo> <rev> <dir>...
check/ports.jl       # E-406: CHECK_ROOTS=… $JU --project=<env> check/ports.jl <package>...
box/variants.jl      # E-407: $JU --project=$TW_ROOT/TraitWorld-unified box/variants.jl (the forwarder's box three ways, IR to box/logs/)
box/baseline.jl      # E-407: $JU --project=$TW_ROOT/TraitWorld-base box/baseline.jl (the attribute's path, its IR)
```

The suites: TraitWorld's (`$JU --project=TraitWorld-unified TraitWorld-unified/test/runtests.jl`), the ODE port's (`Pkg.test()` in its tree), NetworkDynamics' test subset (`cd ndport; $JU -t 2 --project=$W151/nd/env_test_head scripts/r3_nd_tests.jl`). Logs in `logs/`.

## Results (2026-11-15)

Build: `julia-unified` 7b374f39ce (as it is), product setting, strict mode off, one thread unless said; load 4 to 10 of 128 (one spike to 33 during a precompile). The baseline is the tag `prototype-2026-11` of each tree (TraitWorld-base e11c7cc, TDE b730628, NetworkDynamics 6310040), run the same day beside the head: TraitWorld 6f86b4e, TDE 813808a, NetworkDynamics 946c0dc.

### E-401: D-3's control (`check/mistakes.jl`, `logs/e401-mistakes.log`; TraitWorld 362f08b)

| E-397's control | the reading at the box | the line |
|---|---|---|
| `spread(t) = size(t)` | `size(Dynamic{ColTable})` has no method | the method's |
| `colsum(t) = sum(t)` | `sum(Dynamic{ColTable})` reaches `iterate(Dynamic{ColTable})`, which has no method (through `sum → mapreduce → mapfoldl → … → _foldl_impl`) | the method's |
| `field(t) = t.data` | the field `data` is no declared field of `ColTable` | the method's |
| `through(t) = helper(t)` | `helper(Dynamic{ColTable})` reaches `length(Dynamic{ColTable})`, which has no method | the method's, not `helper`'s |
| `leak(t) = typeof(t)`, `wrap(t) = Wrapped(t)` | bounded: they act on the box | — |

The same in the module with the trait's default and `@erasing`. In a module that declares `bounded`, the four are refused where they are defined, each naming the line; `good` and `leak` are accepted.

### E-402: E-374's calls (`calls/`, `logs/calls-*.log`; 10^7 calls, the minimum of 7 runs, ns a call; two processes each)

| Row | baseline (E-374's script, TraitWorld-base) | head (D-1's forms, `calls/calls.jl`) |
|---|---|---|
| 1 an operation at a known type | 0.79 | 0.79 |
| 2 a method at the trait, known type | 0.79 | 0.79 |
| 3 a trait with a `Dynamic` default: a plain member at each call | 7.31–7.32 (compiled once, the object passed) | **25.42** (the forwarder's box at each call) |
| 3 … a box made once and held | — | 7.14 |
| 3 … `compiled_for` | 2.38 (the cast) | 2.38 (the wrapper) |
| 4 an element of a `Vector{Shape}` | 2.86 | 3.02 |
| 5 a field `::Dynamic{Shape}` | 5.56 | 5.56 |
| 6 a `Callable` argument: `compiled_for(f)` | 1.34 | 0.79 |
| 6 … the default | 274–283 (`with_dynamic(f)`) | 196–213 (boxed by the forwarder) |
| 6 … a box held | — | 179–196 |

- Row 3's default: the forwarder makes a box at each call. On the way: `@nospecialize` at a trait argument took the attribute's run-time path (829 ns a call); the box's constructor tests the member against the trait when it runs (110 ns). The forwarder is now compiled per member type with `@specialize` and makes the box by `jl_new_struct`: 25.4 ns, of it the allocation.
- Row 4: the loop's typed and native code are the same on both libraries; E-374's own script on the head library gives 3.02 too; in a module with the trait and its two members alone (`calls/element.jl`, `logs/element.log`) both libraries give 2.86. A difference of the session, not of the loop's code.

### E-403: NetworkDynamics' workload (`nd/`, `nd/logs/e403c-*.log`; a warm-up and 2 runs each, interleaved)

| | the session s | first pass s | the steady state, `again` d ms | new equations, `changed` b–e ms | `graphtype` s | step d (the probe, three solves) ms | digests |
|---|---|---|---|---|---|---|---|
| baseline (`keep`, the cast) | 43.3–43.7 | 19.66–19.71 | 199.1–202.5 | 513.2–516.8 | 8.29–8.43 | 217.6, 199.5, 220.9 | 32 |
| head (the box by `@erasing`, the kernel with the wrapper) | 43.5 | 19.76–19.89 | 181.3–181.4 | 510.7–516.0 | 8.29 | 217.2, 187.2, 218.5 | the same 32 |

- The first runs (`e403-*`, TraitWorld 362f08b) had the steady state at 203.8–205.1 against 206.1–223.6, and the probe's later solves at 206–207 against 199–200: the ODE port's `_sync_in!` boxed its step view again at every event check through Julia's constructor, which tests the membership when it runs (`nd/who_boxes.jl`, `nd/logs/who_boxes.txt`). TraitWorld 5a9d19d: a box of the same trait is itself. `e403b-*` and `e403c-*` are after it.
- The kernel's batch functions are compiled per model, `_run_batch!(::Type{EdgeModel}, ::Compiled{FunctionDynamics{…}}, …)`; the batches hold `Dynamic{VertexDynamics}` and `Dynamic{EdgeDynamics}`.

### E-404: a late load (`late/`, `late/logs/e404-*.log`)

| After upstream CSV's and DataFrames' plain work | baseline | head |
|---|---|---|
| `using TraitWorld`: plain instances ended | 201 of 120,962 | 201 of 120,962 |
| then `using TraitDifferentialEquations` | 757 of 122,796 | 757 of 122,728 |

- The library's 201 are E-394's: the required operations' methods at sets. The wrapper's methods, `convert` into `Dynamic{X}` and the wrapper's family in every trait end none.
- The ODE port's 757 are ForwardDiff's methods (`promote_rule` 682). The forwarders end none. The head's log has 92 entries more, of `jl_method_table_disable` at the kept-form methods' instances at the check's stand-in types (`getparam(::Dynamic{All{IndexProvider{Symbol}, ValueProvider{Float64, Float64}}}, ::Symbol)`): instances the `bounded` reading made while the image was built, dropped at the load; no plain instance among them.

### E-405: the annotations in library code (`count/annotations.jl`, `count/logs/e405-count.log`)

| | keep | cast | Erased | choosing in all | boxes by hand | `@erasing` | unwrap |
|---|---|---|---|---|---|---|---|
| TDE, the tag | 2 | 0 | 5 | **7** | 7 | 0 | 7 |
| TDE, the head | 1 | 0 | 0 | **1** | 7 | 8 | 11 |
| NetworkDynamics, the tag | 2 | 1 | 0 | **3** | 0 | 0 | 0 |
| NetworkDynamics, the head | 0 | 1 (now the wrapper, a value) | 0 | **1** | 0 | 14 | 0 |
| TraitTables, TraitCSV, the forks (not converted) | 0, 0, 0 | 4, 1, 0 | 0 | 4, 1, 0 | 0 | 0 | 0, 0, 3 |

- TDE's remaining `keep` is `kept_interpolant` (core.jl 234), outside the two pieces. The forks import `compiled_for` and call it nowhere.
- `@erasing` stands for what lowering would make implicit; written by hand it is 8 and 14 lines.

### E-406: the suites, and the check at the box over the ports (`check/ports.jl`, `logs/e406-*`)

- TraitWorld's tests: 90 testsets pass (`test/bytype.jl` new). TDE's suite: 35 testsets pass. NetworkDynamics' test subset as at the baseline (massmatrix 6; doctor 26; diffusion 108 pass, 1 fail, 1 error, 24 broken; inhomogeneous 39 pass, 1 error, 12 broken).
- `check_definitions` read at the box: the library and the table demonstrators 77 methods, the ODE packages 104 (2 not read: `Getter(::Callable)`, a bare `Callable` that no box can be formed at, and one whose instance the reflection does not return), NetworkDynamics 21, the forks 47 (2 not read, the reflection's): **no fault**. Every port loads under the `bounded` refusal that reads the box.
- Once, the first load of TraitTables, TraitCSV and TraitMakie after their images were made again crashed in the runtime's membership walk at an image's activation (`logs/e406-segfault.txt`); not reproduced in four later loads.

### E-407: GT-19's probe, the forwarder's box made three ways (`box/`, `box/logs/`; 2026-11-15, TraitWorld be39793 against TraitWorld-base e11c7cc; E-402's harness, the kept-form method kept from inlining; two processes each; load 4 to 18 of 128)

| The box | ns a call | bytes a call | the forwarder's IR (`box/logs/variants-ir-*.ll`) |
|---|---|---|---|
| the baseline: the attribute, code compiled once | 7.28–7.30 | 16 | the member boxed (an isbits `Decay` passed as `Model`), one call |
| `jl_new_struct` (the prototype's) | 26.9–27.6 | 32 | the member boxed, then the box made on the heap by the runtime call |
| `:new`, generated per member type or inlined | 105–106 | 32 | the box on the stack, passed by reference; but `ijl_isa(member, Model)` when it runs (the field's type test, a membership query), the member boxed twice |
| `:new` for a member by its definition (`struct Decay2 <: Model`): the test decided by codegen | 9.45–9.66 | 16 | the baseline's: the member boxed, the box on the stack, one call |
| a box made once and held | 5.19–5.56 | 0 | — |

- The box `Dynamic{X}` itself needs no heap: made by `:new` it lives in a stack slot and is passed by reference.
- What keeps the row lost in the library: codegen tests a field's type at `new` when it runs where it cannot decide it, and it does not decide a positive membership (a world's entry) when it compiles. So `:new` pays the membership query (105 ns), and `jl_new_struct` pays a heap box (27 ns). The library keeps `jl_new_struct`; `_box` is unchanged.
- Where codegen decides the subtyping (a member by definition), the forwarder is the baseline's code and costs 9.5 ns against 7.3: what folding the member test with an edge on the membership would give every member.
- The isbits member's own box (16 bytes) is the baseline's too: a value behind a field typed by a trait is a heap reference. NetworkDynamics' step d does not make a box on its path (the kernel passes the wrapper), so it was not run again.
