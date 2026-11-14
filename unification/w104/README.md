# W-104, phase 4: the demonstrators on the head (E-373)

Each demonstrator's own suite on the head of `julia-unified` and `TraitWorld-unified`, one at a time. A check that the demonstrators follow the design, not a measurement of time. Current numbers: [the evidence](../../../writeup/design/evidence.md).

## How to run

```
bash suites.sh                 # every suite, in order
bash suites.sh tables csv      # some
```

Names: `tables`, `csv`, `makie`, `tde` (`Pkg.test` of TraitTables, TraitCSV, TraitMakie, TraitDifferentialEquations), `report` (TraitReport's `scripts/check.sh`: the trait form and its plain twin print the same summary and draw the same PNG on three datasets), `forks-session` (the forks' `scripts/check_session.sh`: step digests against upstream, the REPL session's marks), `forks-Tables`, `forks-CSV`, `forks-DataFrames` (the upstream suites on the forks), `nd` (NetworkDynamics' test subset, `ndport/scripts/r3_nd_tests.jl`).

Each suite's output is in `logs/<name>.log`, with the commits and the load in its first line; a line per run is appended to `logs/summary.log`. `logs/ode-fully-typed.log` is `fully_typed`'s report on the ODE port's program (`../w142/ft_app.jl ../w135/apps/ode.jl`).

## Results

| Date, build | Suite | Result |
|---|---|---|
| 2026-11-14, `unified` 42681be784, TraitWorld 78da5cb | tables, csv, makie, report, tde, forks-session, forks-Tables, forks-CSV | pass |
| the same | forks-DataFrames | 4 errors, each an `@inferred` that sees `Any` (`data.jl:283`, `dataframe.jl:1180`, `sort.jl:282`, `tables.jl:326`): open issue 157 (a), as on 2026-11-09 |
| the same | nd | first run: NetworkDynamics does not precompile, `compiled_for` not defined (the cast's name is bound, not reserved: the port imports it now). Then as on 2026-11-08: massmatrix 6 pass; doctor 26 pass; diffusion 108 pass, 1 fail, 1 error, 24 broken; inhomogeneous 39 pass, 1 error, 12 broken |
| 2026-11-14, `unified` 86deee2f98 (a test `isa` at a set narrows), TraitWorld baadf9f | every suite again | the same results: all pass but forks-DataFrames (the same 4 errors) and nd's known failures. These are the logs kept in `logs/` |
| the same | the ODE program's fully typed report | not fully typed, 4 calls, one cause: the front end's result is `Any` (open issue 183) |

## What was found

- **The tool `detect_kept_storage` over-reported:** it listed TraitMakie's nine stores of a `Dynamic{Plot}` the method makes itself, which is the same at every caller and allowed (traits §8.1). It lists a `keep`'s value only now, also through a local variable (TraitWorld baadf9f).
- **The ODE port stored callbacks with `keep` in vectors typed by the trait** (six sites): stored as the objects now (TraitDifferentialEquations f8c6765).
- **A result annotation at a trait was inferred as `Any`.** Tried on the ODE port's front end (`ODEProblem(…)::ODEProblemTrait`): the caller still saw `Any`. The cause: the annotation's lowered code tests `x isa X`, and a test at a set refined neither branch (compiler §4.8). Fixed at the rule (`unified` 86deee2f98; gate `../gates/n31_isa_narrows.jl`).
- **The ODE port's front end is kept from inference by hand** (`@nospecializeinfer`), so a program that calls it is not fully typed, with or without a cast: open issue 183, for the ports' lessons (W-147).

## The ODE port's front end, typed (E-387, 2026-11-14)

The rework that open issue 183 proposed (TraitDifferentialEquations 0483ac0, on `unified` 21c9b33e39 with TraitWorld 2072e75). Logs: `../w120/logs/sessions-fe-before.log`, `sessions-fe-after.log` (`bash ../w120/sessions.sh <tag> 3`); `../w135/logs/ode-fe.build.log` (`NAME=ode-fe TRIM=safe bash ../w135/build.sh ode`, after a session of the program); `../w142/logs/agree-fe.log`.

| | Before (`unified` 86deee2f98, TDE f8c6765) | After |
|---|---|---|
| The port's suite | 34 test sets pass | 34 test sets pass |
| The ODE session: wall; the load; the first run (a warm-up and 3 fresh processes, one thread, load 1 to 3 of 128) | 1.25 s; 574 to 577 ms; 405 ms | 1.33 to 1.34 s; 617 to 621 ms; 416 to 420 ms |
| The program under `--trim=safe`, the verifier's errors | 122 (E-361, on an earlier build) | 50: `step_event_condition` 16, other operations of `StepCallback` and `StepEvent` 16, `_enter_callback!` and `_enter_step_callback!` 4, an attributed call 2 (the callbacks: 38); Rodas5 6; a sort 6 |
| `ODEProblem(f, u0, tspan, p)` as its caller's code knows it | `Any` | in a session `ODEProblem{T, P, Dynamic{…}, …}`; in a build `ODEProblem{T, P, PartialFn{typeof(f), P}, …}` |

What it took beside the port: a closed build compiles a trait argument for its type where the call knows it (compiler §7.6); a cast at a parametric type's constructor was dropped in compiled callers (fixed; gate `n6_attribute`); the fully typed report named the session's cause for a call the build compiles (fixed in TraitWorld). What is left: open issue 184.

