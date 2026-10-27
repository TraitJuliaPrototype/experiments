# W-57: Base's type-introspection layer on builtins and `invoke` (E-167)

The checks of W-57's parts 1 and 2 ([the memo](../../writeup/plans/2026-10-27-w57-type-introspection-layer.md); registry row E-167 in `writeup/record/experiments.md`).

## How to run

One Julia job at a time, niced, through the shared lock:

```sh
cd experiments/w57
J=../../julia-1.13/julia
JULIA_LOAD_PATH="../../TraitDifferentialEquations/scripts/env:@stdlib" flock /tmp/claude-1000/julia-review.lock nice -n 19 $J --startup-file=no effects.jl > logs/effects.log 2>&1
```

- `effects.jl`: (1) the effects of `array_subpadding` and the layer's roots under the facts interpreter, and the withdrawn-assertion log of `reinterpret(Float64, ::Vector{Dual})` compiled by facts.
- P4's step d: `ndport/scripts/run_workload.sh w57 P4 1` (logs `ndport/logs/w57/`), summarized by `ndport/scripts/summarize.py`.

## Results

None yet.
