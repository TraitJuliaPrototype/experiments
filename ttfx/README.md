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

**The session** is from before the process starts to the end of the last step ("again"), startup included (0.01 s Python, 0.11–0.12 s Julia). The logs' "exit" column also holds the trailer after the last mark (digests and versions, compiled in Julia: 0.25–0.5 s), so it is not used; a bare exit takes 0.04–0.05 s in Julia (measured with and without D's packages) and about 0.07 s in Python. Totals below are sessions; the variants' totals in the second table include the trailer (subtract 0.3–0.7 s), and their sessions are in `logs/p1/` by `summarize.py`.

**Matched shapes, everything loaded first:**

| Setting | load | first solve | first plot | second model | again | **session** |
|---|---|---|---|---|---|---|
| Python | 0.45 | 0.07 | 0.51 | 0.24 | 0.17 | **1.45–1.46** |
| S, stock | 3.54–3.56 (0.09) | 3.75–3.76 (3.75) | 1.51 (1.41–1.44) | 0.19 (0.17) | 0.04 | **9.16–9.17** |
| U, patched | 3.51–3.55 (0.10) | 3.63–3.64 (3.62) | 1.67–1.68 (1.60) | 0.16 (0.14) | 0.04 | **9.12–9.18** |
| C, SciML compiled by facts | 4.52–4.53 (0.46) | 4.56–4.57 (4.54) | 1.47–1.48 (1.36–1.41) | 0.22 (0.16–0.19) | 0.04 | **10.92–10.93** |
| D, TDE + TraitMakie | 0.81 (0.41–0.42) | 0.14 (0.13) | 0.15 (0.12–0.13) | 0.056–0.057 (0.04) | 0.02 | **1.29–1.30** |
| Dp, PlainODE + PlainPlots | 0.19 (0.03) | 0.22 (0.21) | 0.25 (0.22–0.23) | 0.33 (0.32) | 0.02 | **1.13–1.14** |

**Variants (totals; the steps that move):**

Sessions (to "again"): S/p 12.83–12.98, S/b 9.72–9.75, U/b 9.81, C/b 11.18, C/s 17.63, D/p 2.63, D/b 1.39–1.40, Dp/p 1.82–1.84, Dp/b 1.24, Python/b 1.44–1.46.

| Setting | perturbed (`/p`), total with trailer | order B (`/b`) | strict mode on (`/s`) |
|---|---|---|---|
| Python | — | 1.52–1.54 (matplotlib's import moves into the first plot) | — |
| S | **13.51–13.67:** first solve 5.28–5.36, second model 2.24–2.29 | 10.21–10.24: load 1.10, first plot 4.09–4.12, again 0.44 (0.40 compiling: code invalidated by CairoMakie's load) | — |
| U | — | 10.33: again 0.44 (0.23–0.40) | — |
| C | — | 11.55: again 0.04 (nothing recompiled) | **18.00–18.01:** load 11.16 (2.85 compiling, 1.03 GC) |
| D | **2.93–2.94:** first solve 1.50–1.51 (1.44 compiling) | 1.70–1.73: again 0.02 | — |
| Dp | 2.15–2.17: first solve 0.89 | 1.56–1.57: again 0.02 | — |

**What it says:**
- **The small trait core meets Python's session:** D 1.29–1.30 s against Python's 1.45 s. Its plain twin Dp: 1.13 s. Small libraries are fast whatever the design; the traits' contribution is the second model, 0.056 s against Dp's 0.33 s (the model kept `Dynamic`: no solver compiled for the new function).
- **Upstream SciML and Makie take six times Python's session:** 9.5 s in S and U. Load 3.5 s; the first solve compiles 3.75 s although the call shapes are those of OrdinaryDiffEq's own workload in kind (vectors); the first plot compiles 1.4–1.6 s. The second model is cheap (0.16–0.19 s: SciML wraps the function).
- **Compiling upstream SciML by facts (C) adds** 1.0 s to the load (0.46 s compiling at load) and 0.9 s to the first solve. Under order B it recompiles nothing after the plotting library's load (again 0.04 s, against U's 0.44 s): the facts mode's protection, where users meet it.
- **Strict mode adds 6.6 s to C's load** (11.2 against 4.5 s): its prototype's check at each load (traits §10.3; facts §10.2) does not fit the target.
- **The perturbed shapes cost:** S 4.0 s more (the solver compiled again for a `Tuple` of parameters and a range, in the first solve and again for the second model); D 1.35 s more in the first solve: TDE's solver is keyed on the parameters' type (`ODEProblemTrait{T, P}`), so a `Tuple` is a new key, compiled in the session; Dp 0.7 s more.
- **D's load compiles 0.41 s** (0.81 s; Dp loads in 0.19 s).

### Phase 2 (E-169), first probes, 2026-10-27

Same build and environments (`logs/p2/`).
- **Stock SciML's first solve is keyed on the keywords, not on the user's function** (`probe_keys.jl`, `S-probe-keys.log`; one session per variant): `solve(prob, Tsit5())` with Main's function 0.16 s; with `saveat`, `reltol`, `abstol` 1.18 s; after that, a second function with the same keywords 0.09 s. OrdinaryDiffEq's workload calls `solve` without keywords, so the session compiles the keyword path: class (f), cacheable. The traces (`S-trace.jl`) show the two `solve` keyword entries at 2.29 s (Rodas5P) and 1.29 s (Tsit5).
- **The load** (`@time_imports`, `*-imports.log`): S loads 381 packages, 3.2 s summed (Makie 0.71 s; SparseArrays, StaticArrays, Pkg, REPL among the first ten); C 382 packages, 3.8 s; D 58 packages, 0.58 s. On the patched build one package per session takes 0.26–0.29 s, almost all compiling (D: IrrationalConstants; C: DocStringExtensions; on stock 6 and 1 ms): TraitWorld's load callback.
- **TraitWorld's own machinery is invalidated at every load** (`probe_inval.jl`, `D-inval.log`): loading D invalidates 126 of TraitWorld's MethodInstances (its plain machinery: `_finish_module`, `check_bounds`, `_sig_alternatives`, `_rewrite_fdef`, `_process`, …), at methods such as ForwardDiff's `promote_rule` and FixedPointNumbers' `floor`; `_on_package_load` is recompiled in every session (87–105 ms in the traces). Class (c): the code is in TraitWorld's image and invalidated by packages loaded after it.


### Phase 3a (E-172), a cache across sessions, emulated, 2026-10-27

`cache/make_cache.sh X` traces a perturbed session (`--trace-compile`), keeps the compiled statements that do not name `Main`, and compiles them in the precompile step of a package `SessionCacheX` (`cache/`), loaded at the session's load step (`/c`, environment `env_cache_X`). Kept: D 53 of 67 statements (14 name `Main`), Dp 53 of 74 (21), S 177 of 203 (26); none failed. The same build; a warm-up and two sessions (`logs/p3a/`, `logs/cache/`).

| Perturbed session (to "again") | without the cache (E-168) | with it | matched, no cache |
|---|---|---|---|
| D | 2.63 | **1.51–1.52** (load 0.90, first solve 0.27, first plot 0.16, second model 0.05) | 1.29–1.30 |
| Dp | 1.82–1.84 | **0.70** (load 0.19, first solve 0.20, first plot 0.13, second model 0.05) | 1.13 |
| S | 12.83–12.98 | **11.61–11.85** (first solve 5.16–5.29 and second model 2.25–2.30 unchanged; first plot 0.47–0.48 from 1.56) | 9.16 |

**What it says:**
- **Provisional** ([the review](../../writeup/reviews/2026-10-27-cache-and-port-notes.md) B1): `--trace-compile` records compile roots only, under the default owner; dropping a root that names `Main` drops its library-keyed callees too, and facts code is not recorded. The first bullet's "none … could be kept" for S is therefore not shown; E-175 repeats the emulation at the level of CodeInstances.
- **What a cache across sessions can keep is decided by what the code is keyed on.** S's solver code is keyed on the user's function (`ODEFunction{true, AutoSpecialize, typeof(Main.robertson!), …}` in the problem's type, at `solve`'s keyword entry), so none of its 7.5 s of solver compilation is kept; its plotting code, keyed on library types, is (1.1 s saved).
- **Dp recovers most:** PlainODE keeps the user's function behind a `FunctionWrapper` at a plain signature, so its solver is keyed on library types, and all of it is kept. Erasing the user's types at the library's boundary is what makes code cacheable, by traits (`Dynamic`) or by hand.
- **D recovers 1.1 s** (first solve 1.50 → 0.27 s), less than Dp: its load grows 0.09 s with the cache, and its first solve keeps 0.18 s of compiling (not diagnosed).
- **Fixed in TraitWorld 04095fe** (the load profile, `logs/p2/D-load-profile.log`: 260 of 660 samples in TraitWorld's image hook, compiling its body at the first image load): `_on_package_load` compiled by facts, and the hooks' bodies, reached through `invokelatest`, precompiled. D's load 0.81 → 0.44–0.46 s; its session 1.29–1.30 → 0.94–0.99 s (`logs/p2fix2/`; Dp unchanged, 1.14–1.19 s, `logs/p2fix/`). TraitWorld's, the acceptance suite's, TDE's and TraitMakie's tests pass (`experiments/checks/logs/w58-hooks/`). 122 of TraitWorld's MethodInstances are still invalidated by D's loads (its plain macro and definition-time machinery); they are not on a session's path unless trait code is defined in it.

### E-174, the key hypothesis at upstream scale, 2026-10-27

Stock 1.13.2, upstream OrdinaryDiffEq and CairoMakie (S), the user's functions behind `ODEFunction{true, NoSpecialize}` (`/n`), so the problem's type does not name them. The cache built as in E-172 from a perturbed `/n` session (`cache/make_cache.sh S n`: 230 of 253 statements kept, 23 name `Main`). A warm-up and two sessions (`logs/p174/`). Digests as in every setting.

| Session (to "again") | load | first solve | first plot | second model | **session** |
|---|---|---|---|---|---|
| S, perturbed (E-168) | 3.57 | 5.28–5.36 | 1.56–1.57 | 2.24–2.29 | **12.83–12.98** |
| S/n, perturbed, no cache | 3.55–3.57 | 8.19–8.22 | 1.55–1.56 | 2.71–2.73 | **16.19–16.20** |
| S/n, matched, no cache | 3.62–3.64 | 7.50–7.55 | 1.52 | 0.08 | **12.88–12.94** |
| **S/n, perturbed, with the cache** | 3.66–3.67 | **0.30** | 0.48 | **0.08** | **4.69–4.70** |

**What it says:**
- **With the user's function out of the solver's types, a cache across sessions keeps upstream SciML's solver code:** the first solve 0.30 s instead of 8.2 s, the second model 0.08 s. After the load, the session takes 1.03 s, against Python's 1.00 s (its session less its load).
- **What remains is the load:** 3.66 s of the 4.69 s.
- `NoSpecialize` alone, without the cache, is slower (16.2 s): OrdinaryDiffEq's workload does not compile its path. A new function then costs nothing (0.08 s).
- The run time does not suffer here ("again" 0.04 s in every variant).

### E-173, the cache's checks, 2026-10-27

TraitWorld 04095fe (D's cache rebuilt: 52 of 66 statements kept); otherwise as E-172 and E-174 (`logs/p173/`).
- **Order independence: not tested.** Each emulated cache package depends on the plotting library, so loading it at the load step loads CairoMakie (or TraitMakie, PlainPlots) there too: the `/b` sessions with a cache ran in order A (S/pncb 4.63–4.70 s, load 3.60–3.67 s, as S/pnc). The test needs the cache split by dependency set ([the cache note](../../writeup/plans/2026-10-27-session-cache.md) §3), so that its solver part loads with the solver and its plotting part with the plotting library.
- **Recurrence** (a cache built from a perturbed session, used by a matched one):

| Session (to "again") | load | first solve | first plot | second model | **session** | the same session without a cache |
|---|---|---|---|---|---|---|
| D/c | 0.61 | 0.09 | 0.12–0.13 | 0.05 | **1.02** | 0.94–0.99 |
| Dp/c | 0.19–0.20 | 0.17 | 0.10 | 0.32 | **0.92** | 1.14–1.19 |
| S/nc | 3.68–3.74 | **6.27–6.29** | 0.48 | 0.08 | **10.68–10.80** | 12.88–12.94 |

- **Stock SciML's solver is keyed on the call's shape:** a cache from `Tuple` parameters and a range of saving times leaves the matched session (vectors) compiling 6.3 s in its first solve. Each new shape costs its compilation once; a cache across sessions pays it once per shape, not once per session, but the first time stays.
- D's cache adds 0.15 s to its load (0.61 against 0.44–0.46 s); its first solve is covered either way (TDE's workload has the matched shapes).


### E-169, the load of S, 2026-10-27

A sampling profile of `using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie` on stock 1.13.2 with C frames, 1 ms (`logs/p2/S-load-profile.log`; 3,333 samples in the load):
- restoring the images (`jl_restore_incremental_from_buf`): 1,603, of which activating their methods (`jl_activate_methods`, mostly the type-intersection search of what each insertion invalidates) 919;
- validating the images' edges (`insert_backedges` → `verify_method_graph`, in the compiler's world): 1,285;
- the rest (`__init__`, finding and checking cache files): about 450.

Julia's loader machinery, not package code, takes the load: method insertion and edge validation are about two thirds. A system image of the stack needs neither; phase 3's second ceiling measures it.
