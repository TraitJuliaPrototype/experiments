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
