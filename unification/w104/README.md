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
