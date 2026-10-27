# Load and first use: SciML and Makie against SciPy and matplotlib (E-168 to E-171)

The experiments of W-58 ([the plan](../../writeup/plans/2026-10-27-ttfx-sciml-makie.md); registry rows E-168 to E-171 in `writeup/record/experiments.md`). One fresh session, start to exit: load an ODE solver and a plotting library, solve Lorenz (non-stiff) and Robertson (stiff), plot both to PNGs, solve and plot a second model (Van der Pol), then both again.

## How to run

```sh
cd experiments/ttfx
bash precompile.sh "S U C D"          # setup, minutes per setting, alone
bash run.sh <tag> "py S U C D Dp" 2   # a discarded warm-up, then 2 sessions per setting
bash run.sh <tag> "S/p D/b C/s" 2     # variants: /p perturbed shapes, /b plotting after the first solve, /s strict mode
python3 -I summarize.py logs/<tag>/*.log
```

- `workload.py` (Python), `workload.jl` with `plotting.jl` (S, U, A, C: upstream API), `workload_d.jl` (D, Dp: the demonstrators and their plain twins), `pngs.jl`.
- Settings, harness and predictions: the plan §2–§4. Each setting has its own depot (`depot-*`, not committed); Julia runs with `--compiled-modules=existing --pkgimages=existing`; `summarize.py` marks a log that shows precompiling, a rejected image or an error INVALID.
- Python: `pyenv/` (uv; not committed): Python 3.12.14, numpy 2.5.4, SciPy 1.18.1, matplotlib 3.11.2.

## Results

### Phase 1 (E-168), 2026-10-27

julia-1.13 252edca933 (S: stock 1.13.2), TraitWorld main bbfc130, TraitDifferentialEquations w34 669cd9b, TraitMakie 9436157; strict mode off unless `/s`; two cores; load 0.6–1.3. A warm-up and two sessions per setting; the two agree within 1% (`logs/p1/`). Seconds; per step the wall time since the previous mark, compile time in brackets. Digests agree within the plan's tolerance in every setting. PNGs: Julia and Python 800×600 and 800×400; D and Dp 600×400 (two PNGs for the first plot).

**Matched shapes, everything loaded first:**

| Setting | load | first solve | first plot | second model | again | exit | **total** |
|---|---|---|---|---|---|---|---|
| Python | 0.45 | 0.07 | 0.51 | 0.24 | 0.17 | 0.08 | **1.53** |
| S, stock | 3.54–3.56 (0.09) | 3.75–3.76 (3.75) | 1.51 (1.41–1.44) | 0.19 (0.17) | 0.04 | 0.33 | **9.49–9.50** |
| U, patched | 3.51–3.55 (0.10) | 3.63–3.64 (3.62) | 1.67–1.68 (1.60) | 0.16 (0.14) | 0.04 | 0.35 | **9.47–9.54** |
| C, SciML compiled by facts | 4.52–4.53 (0.46) | 4.56–4.57 (4.54) | 1.47–1.48 (1.36–1.41) | 0.22 (0.16–0.19) | 0.04 | 0.37–0.53 | **11.30–11.45** |
| D, TDE + TraitMakie | 0.81 (0.41–0.42) | 0.14 (0.13) | 0.15 (0.12–0.13) | 0.056–0.057 (0.04) | 0.02 | 0.29 | **1.58–1.59** |
| Dp, PlainODE + PlainPlots | 0.19 (0.03) | 0.22 (0.21) | 0.25 (0.22–0.23) | 0.33 (0.32) | 0.02 | 0.33 | **1.46–1.47** |

**Variants (totals; the steps that move):**

| Setting | perturbed (`/p`) | order B (`/b`) | strict mode on (`/s`) |
|---|---|---|---|
| Python | — | 1.52–1.54 (matplotlib's import moves into the first plot) | — |
| S | **13.51–13.67:** first solve 5.28–5.36, second model 2.24–2.29 | 10.21–10.24: load 1.10, first plot 4.09–4.12, again 0.44 (0.40 compiling: code invalidated by CairoMakie's load) | — |
| U | — | 10.33: again 0.44 (0.23–0.40) | — |
| C | — | 11.55: again 0.04 (nothing recompiled) | **18.00–18.01:** load 11.16 (2.85 compiling, 1.03 GC) |
| D | **2.93–2.94:** first solve 1.50–1.51 (1.44 compiling) | 1.70–1.73: again 0.02 | — |
| Dp | 2.15–2.17: first solve 0.89 | 1.56–1.57: again 0.02 | — |

**What it says:**
- **The small trait core meets Python's session:** D 1.58–1.59 s against 1.53 s. Its plain twin Dp: 1.46–1.47 s. Small libraries are fast whatever the design; the traits' contribution is the second model, 0.056 s against Dp's 0.33 s (the model kept `Dynamic`: no solver compiled for the new function).
- **Upstream SciML and Makie take six times Python's session:** 9.5 s in S and U. Load 3.5 s; the first solve compiles 3.75 s although the call shapes are those of OrdinaryDiffEq's own workload in kind (vectors); the first plot compiles 1.4–1.6 s. The second model is cheap (0.16–0.19 s: SciML wraps the function).
- **Compiling upstream SciML by facts (C) adds** 1.0 s to the load (0.46 s compiling at load) and 0.9 s to the first solve. Under order B it recompiles nothing after the plotting library's load (again 0.04 s, against U's 0.44 s): the facts mode's protection, where users meet it.
- **Strict mode adds 6.6 s to C's load** (11.2 against 4.5 s): its prototype's check at each load (traits §10.3; facts §10.2) does not fit the target.
- **The perturbed shapes cost:** S 4.0 s more (the solver compiled again for a `Tuple` of parameters and a range, in the first solve and again for the second model); D 1.35 s more in the first solve: TDE's solver is keyed on the parameters' type (`ODEProblemTrait{T, P}`), so a `Tuple` is a new key, compiled in the session; Dp 0.7 s more.
- **D's load compiles 0.41 s** (0.81 s; Dp loads in 0.19 s). **Julia's exit takes 0.29–0.53 s** against Python's 0.08 s.
