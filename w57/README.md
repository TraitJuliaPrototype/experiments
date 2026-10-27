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

- `sites.jl`: each frame's generic calls whose signature is no fact signature (`Compiler.is_fact_sig`), with the withdrawn-assertion log.
- `patched.jl`: evaluates the patched sources of `isvatuple`, `fieldcount` and `datatype_fieldcount` into Base, then runs `effects.jl` (a check before a rebuild; not a measurement).

## Results

| Date | Build | Outcome |
|---|---|---|
| 2026-10-27 | julia-1.13 04e213c4f8 | (1) not yet: `array_subpadding(Dual…, Float64)`, `padding` and `packedsize` neither foldable nor `nortsite`; the roots `unwrap_unionall`, `isabstracttype`, `fieldcount(DataType)`, `datatype_alignment` are. The log withdraws `isvatuple` and `fieldcount` at `Union{Type{Float64}, Type{Partials{1,Float64}}}` and everything above. Three calls at signatures that are no facts (`logs/sites.log`): `isvarargtype(::Any)` in `isvatuple`, `length(::Tuple)` in `datatype_fieldcount` (a `NamedTuple`'s names), `TypeError(::Symbol, ::Type{DataType}, ::Any)` on `fieldcount`'s error path. |
| 2026-10-27 | 04e213c4f8 with those three fixed, evaluated into Base (`patched.jl`) | (1) holds: `array_subpadding` foldable with `nortsite` set for both dual types and the reverse direction; nothing withdrawn while `reinterpret(Float64, ::Vector{Dual})` compiles by facts (`logs/patched.log`). The fixes are julia-1.13 252edca933. |
