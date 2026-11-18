# E-361: trimmed binaries on the unified build, against plain Julia's (W-135, G-6)

**The question:** does a demonstrator build with `juliac --trim`, what does the trim verifier report, does the binary run, and what did the author have to add. Beside each, the plain twin, on the unified build and on vanilla Julia. Registry row: `writeup/record/experiments.md` E-361. Current numbers: `writeup/design/evidence.md` §4.

## How to run

```
source ../../../env.sh
bash run_warn.sh     # every app with --trim=unsafe-warn: session, build, run, outputs compared -> logs/run-warn.log
bash run_safe.sh     # every app with --trim=safe: the verifier's report counted            -> logs/run-safe.log
bash run_rest.sh     # the second round's programs, both ways                               -> logs/rest-warn.log, logs/rest-safe.log
```

- `build.sh <app> [project]`: one build with `julia-unified/test/trimming/juliac-buildscript.jl` (`TRIM=safe|unsafe-warn`, `NAME=`, `JULIA_TREE=julia-vanilla`). Memory guard 4 GB. Log: `logs/<name>.build.log`.
- `session.sh <app> [project] [args]`: the app in a session, for its output.
- `summarize.py <log>...`: the verifier's errors counted, by the module of the call and by the root.
- `entrypoints.jl`: the entry points and sites `verify_main` gives for an app.
- `apps/`: `hello`, `jll` (a JLL alone: the control for a JLL's `__init__`), `table` (TraitCSV and TraitTables; `TABLE_PLAIN=1` PlainTables), `ode` (TraitDifferentialEquations; `ODE_AD=1` adds a gradient through ForwardDiff; `ODE_PLAIN=1` PlainODE), `plot` (TraitMakie), `plot_plain` (PlainPlots), `csvdf` (upstream CSV and DataFrames, project `../w134/env_up`), `report` (TraitReport's task, form (t): TraitCSV, TraitTables and TraitMakie, a read, the summary, a histogram to a PNG; `REPORT_PLAIN=1` PlainTables and PlainPlots).
  - `apps/verify.jl` (`VERIFY=1`): `TraitWorld.add_entrypoints(verify_main(main, (Vector{String},)))` at build time.
  - `apps/jllhole.jl`: one entry point, `issorted(::Vector{String}, ::ReverseOrdering)`, which a JLL's `__init__` reaches through `unique!` and no build compiles. Both Julias need it (`JLLHOLE=0` omits it).
- The project is `../w134/env_demo` (the demonstrators at their heads), `env_jll` for the control.

## Results, 2026-11-10

`julia-unified` 564a2288e2, `julia-vanilla` v1.13.2 45b6d15e34, TraitWorld 05991fc, TraitTables 160639e, TraitCSV 92c46d0, TraitMakie c9e294b, TraitDifferentialEquations 6658c65. Product setting, strict mode off. One build each, load 2–3 of 128 cores.

### `--trim=safe` (`logs/run-safe.log`): the verifier's errors; no library builds

| Program | Trait form | with `verify_main`'s entry points | Plain twin, unified | Plain twin, vanilla |
|---|---|---|---|---|
| hello | builds, 1,837,424 bytes | — | — | — |
| a JLL alone | — | — | 6 | 6 |
| table (CSV read, summary) | 8 | 9 | 10 | 12 |
| ODE (Lorenz, Tsit5; Robertson, Rodas5) | 122 | 122 | does not load (below) | 14 |
| ODE with a gradient | 160 | 160 | — | — |
| plot (lines and points to a PNG) | 34 | 48 | 86 | 88 |

- `verify_main`: table 1165 targets, 16 entry points, 20 run-time sites, 2.8 s; ODE 140, 0, 9, 1.9 s; ODE with the gradient 170, 0, 23, 3.0 s; plot 1081, 24, 44, 3.2 s. Each walk complete.
- The table's 8 errors: 4 are Base's `repeat(::Char, ::Int)` (an `:invoke` with no code, plain Julia's too), 2 `emptylike(…)` on a value known by its trait, 2 `push!(::Vector{Column}, ::Any)` on a cast's result.
- Entry points add code, and with it more code for the verifier to refuse (plot 34 to 48).

### `--trim=unsafe-warn` (`logs/run-warn.log`): every program builds; only hello and the JLL control run

| Program | Bytes | First failure when run |
|---|---|---|
| hello | 1,837,424 | runs; output equal to the session's |
| a JLL alone, unified / vanilla | 2,031,120 / 1,928,344 | runs; equal |
| table, as written | 2,813,472 | `MethodError`: `emptylike(::Vector{Int64})`, an operation on a value known by its trait |
| table, with entry points | 2,894,624 | `MethodError`: `push!(::Vector{Column}, ::Any)` at CSVCore.jl:128, a cast's result; `verify_main` lists the site |
| table, plain twin, unified / vanilla | 2,270,256 / 2,137,752 | `MethodError`: `PlainTables.fillcolumn(Int64, …)`, a dispatch on a type value |
| ODE, as written / with entry points | 3,611,704 / 3,612,488 | `MethodError`: `Core._keep_dynamic(Dynamic{Callable{…}}, lorenz!)`, from the problem's constructor; `verify_main` lists the site (frontend.jl:62) |
| ODE with a gradient | 3,894,432 / 3,896,992 | the same |
| ODE, plain twin, vanilla | 2,325,456 | `MethodError`: `PlainODE._promote_state(…)` |
| plot, as written / with entry points | 4,752,744 / 5,026,784 | no code for `ColorName(::Symbol)` (the runtime tries to infer it) |
| plot, plain twin, unified / vanilla | 4,283,992 / 4,129,928 | `MethodError`: `kwcall((color = :blue,), lines!, …)` |

## Reading

- **No demonstrator runs trimmed as written, in either form.** Each stops at its first call dispatched at run time. Plain Julia's twins stop at theirs.
- **What the trait form adds:** `verify_main` names the members' operations and the casts' instances, and `add_entrypoints` gives them to the build. The table then gets past both and stops at a site the report lists. A plain twin has no such list.
- **What stops the trait form is the design's own way to compile once:** a value known only by its trait is operated on by a call dispatched at run time, and `--trim=safe` refuses every such call, though every target is declared and compiled. Recorded as the tension GT-13 (`writeup/open-issues.md` §1).
- **Fixed on the way** (Julia): a trimmed image marks every module as never compiled by facts (TraitWorld's `__init__` failed in a binary before); a trimmed build has no code slots (a slot's callee was not kept in the image). TraitWorld: `verify_main` lists a cast's members and instances, reports `entrypoints` and `complete`, and walks to its own bound (the walk had stopped silently at 400 signatures).

## Observed, not diagnosed

- **A build on a depot without the packages' images** loads them from source and has crashed there (segmentation faults while loading TraitNonlinearSolve and Colors, on both Julias). `run_warn.sh` runs the session first, which writes the images.
- **Under `unsafe-warn` the verifier's report is cut off** when the build's process exits (output to a file, both Julias). Its counts are the `safe` round's.
- **PlainODE does not load on the unified build:** it defines a function named `compiled_for`, which is reserved there (`logs/ode-plain.build.log`).
- `verify_main` lists sites in Base that the verifier does not refuse (`!==` at array.jl:1186, `TypeVar` at array.jl:837: 15 of the table's 20), and does not see Base's `repeat` hole or a JLL's `__init__` (traits T-107).

## Results, 2026-11-11: the programs the first round left

The same builds and packages; TraitDifferentialEquations at the commit that renames PlainODE's `compiled_for` to `specialized` (the name is a cast on the unified build and cannot be defined). One build each, load 3–6 of 128 cores. `logs/rest-safe.log`, `logs/rest-warn.log`.

| Program | `safe`: the verifier's errors | `unsafe-warn`: bytes | First failure when run |
|---|---|---|---|
| report (read, summary, histogram to a PNG), as written | 44 | 5,112,896 | `MethodError`: `emptylike(::Vector{Int64})`, an operation on a value known by its trait |
| report, with entry points | 59 | 5,330,056 | `MethodError`: `push!(::Vector{Column}, ::Vector{Float64})`, a cast's result |
| report, plain twin (PlainTables, PlainPlots), unified / vanilla | 96 / 98 | 4,420,608 / 4,257,912 | `MethodError`: `PlainTables.fillcolumn(Int64, …)` |
| upstream CSV with DataFrames, unified / vanilla | 770 (and 2 warnings) / 766 (and 2) | 7,668,264 / 6,813,128 | `MethodError`: `CSV._stringsink(…)` |
| ODE, plain twin, unified (vanilla: the first round) | 14 | 2,436,584 | `MethodError`: `PlainODE._promote_state(…)` |

- `verify_main` on the report: 1548 targets, 40 entry points, 63 run-time sites, complete, 4.1 s.
- The report is the table and the plot together, and stops where the table stopped. Nothing new: GT-13.
- Upstream CSV with DataFrames is two orders of magnitude further from a trimmed build than any demonstrator, on both Julias: 524–526 of its errors are calls in Base, 148 in CSV, 50 in DataFrames.
- PlainODE on the unified build gives vanilla's 14 errors and stops at vanilla's call.
