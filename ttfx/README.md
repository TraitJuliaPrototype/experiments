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

### E-170's system image: not buildable here, 2026-10-27

`cache/build_sysimage.sh` (PackageCompiler 2.4.4, stock 1.13.2, `env_up`): three attempts with the session's 230 statements and one with the packages only. Each exhausted the machine's memory (30 GB, 8 GB swap) and was stopped by the watchdog: at 3.9, 1.5 and 0.8 GB available (`logs/cache/S-sysimage-mem.log`). The load's profile (E-169) stands in for this ceiling.

### E-175, the cache emulated at the level of CodeInstances, 2026-10-27

`cache/record_cis.jl` runs the perturbed workload and records every CodeInstance created after its load step, by a walk of the method table's specializations at the load mark and at the end; it keeps the signatures that name no type of `Main` (`CI=1 bash cache/make_cache.sh X`). New CodeInstances after the load: D 1,344 (facts 662, plain 682; 101 name `Main`), Dp 1,212 (139), S 3,879 (530), S/n 7,911 (164). `precompile` accepted D 997 of 1,226 kept, Dp 781 of 1,073, S 2,808 of 3,349, S/n 3,658 of 7,740 (the rest are signatures it does not compile as written). A warm-up and two sessions (`logs/p175/`, `CI=1 bash run.sh p175 …`).

| Perturbed, with the cache (to "again") | load | first solve | first plot | second model | **session** | roots only (E-172, E-174) |
|---|---|---|---|---|---|---|
| S, auto-specialized | 3.66–3.73 | 0.49 | 0.34 | 0.22 | **4.88–4.93** | 11.6–11.8 |
| S/n, `NoSpecialize` | 3.69–3.71 | 0.36 | 0.32 | 0.09 | **4.63–4.64** | 4.69–4.70 |
| D | 0.60 | 0.25 (0.16–0.17 compiling) | 0.12 | 0.05 | **1.15–1.17** | 1.51–1.52 |
| Dp | 0.19–0.20 | 0.18 | 0.08 | 0.04–0.05 | **0.64** | 0.70 |

**What it says:**
- **E-172's result for S was an artefact of recording roots only** ([the review](../../writeup/reviews/2026-10-27-cache-and-port-notes.md) B1, confirmed). Stock SciML's `AutoSpecialize` erases the function below `solve`'s entry, so its solver code is cacheable as it stands: the first solve 0.49 s instead of 5.3 s, the second model 0.22 s.
- **With a cache, every setting's work after the load is about a second or less:** S 1.1–1.2 s (Python's session less its load: 1.0 s), D 0.55 s, Dp 0.45 s.
- **The load is what remains:** 3.7 s in S, of a 4.9 s session.
- D's first solve still compiles 0.16–0.17 s with the cache: its facts code is replayed by `precompile`, which compiles a facts method's callees in Base as plain copies, not the facts copies the session uses (not verified); TraitWorld's first-call checks are not yet counted (the review's M5).

### E-169, the load of C and the owners of loaded code, 2026-10-27

C re-precompiled for TraitWorld 04095fe (122 s, 8 tasks). Its load's profile (`logs/p2/C-load-profile.log`, 3,845 samples, 1 ms): restoring images 1,836 (activating methods 799), validating edges 1,435, the rest about 570. After TraitWorld's hook fix C's load is about 3.85 s (4.5 s in E-168).

The code the load brings (`probe_owners.jl`, CodeInstances and edge entries added by `using`): S 289,549 plain, 1.00 M edge entries; C 280,963 plain (0.98 M) and 33,814 facts (0.11 M), plus 1,023 of TraitWorld's check owners. Facts code is 11% of C's loaded code: validating it is not where C's load goes.

### E-171, the scale probe, 2026-10-27

`scale/gen.py` generates three trait packages: K traits of three operations each, N types implementing all of them, M bounded functions, and a workload compiling every function for every type. ScaleS (N 4, K 2, M 8: 32 workers, 135 lines), ScaleM (12, 4, 32: 384 workers, 553 lines), ScaleL (40, 8, 100: 4,000 workers, 2,533 lines). `scale/measure.jl` times, in a fresh session: `using`, a first call at a cached key, and a new type defined in the session (`@implement` of one trait, then its first call). julia-1.13 252edca933, TraitWorld 04095fe, then with the fix below; product setting; two sessions each (`scale/logs/`).

| Package | precompile | native image | load | load, strict mode on | cached key, first call | new type: `@implement` (TraitWorld 04095fe → fixed) | its first call |
|---|---|---|---|---|---|---|---|
| ScaleS | 2.0 s | 3.0 MB | 0.158 s | 0.167 s | 1 ms | 0.23 → 0.077 s | 0.038 s |
| ScaleM | 7.0 s | 14.3 MB | 0.184 s | 0.197 s | 1 ms | 0.50 → 0.078 s | 0.038 s |
| ScaleL | 42 s | 86.5 MB | 0.304 s | 0.340 s | 1 ms | 1.25 → 0.079 s | 0.038 s |

**What it says:**
- **The load grows much slower than the code:** 125 times the workers and 29 times the native code cost 0.15 s more. Strict mode adds 0.01–0.04 s. Neither fails the premise.
- **`@implement` of a user's type grew with the library's size** (0.23 → 1.25 s). TraitWorld's definition hook re-ran the keep analysis of every bounded function of the trait module (by inference) for each method the implementation added, although that analysis follows only methods of trait-module code, so a method defined outside cannot change its result. Fixed (TraitWorld 003ce8f): the refresh runs only for a method that is trait-module code. A new type's `@implement` now takes 0.08 s at every size.
- Defining the struct and its `@implement` in one top-level block is refused with "Main does not own TNew": the block's macros expand before the struct exists. The message misleads (open issue 74).

### E-175, D's remaining compilation with the cache, 2026-10-27

D's first solve kept compiling 0.16–0.21 s with its cache. Three causes, each found by recording what the cached session still created (`RECORD_LIST=… cache/record_cis.jl`, `logs/p175d/`) and a profile (`prof_session.jl`):
1. **Facts code replayed as plain copies:** `precompile(sig)` compiles plain code; the session needs the facts owner's copies of Base methods (603 facts CodeInstances still made). The cache now compiles those for the facts owner (`fpc`: `Compiler.typeinf_ext_toplevel(mi, world, SOURCE_MODE_ABI, TRIM_NO, FACTS_OWNER)`); the cached session then made 15.
2. **Trait objects' types do not round-trip through printing** (TraitWorld prints them by bound and key, `PCT at Vector{Float64}`), so their statements failed. The recorder now serializes the types (`trace.jls`); failed statements 235 → 94.
3. **TraitWorld's first-call checks ran again** (`checked_call` → `_check_once` → `worker_problems`, inference in every session; the review's M5). TraitWorld now lists the signatures checked in a session (`_CHECKED_IN_SESSION`); the cache runs those checks at its build and keeps them in its image as checked ahead (`__tw_checked__`).

| D, perturbed (to "again") | load | first solve | first plot | second model | **session** |
|---|---|---|---|---|---|
| no cache | 0.80 | 1.50 | 0.13 | 0.07 | 2.63 |
| cache, plain replay (E-175) | 0.60 | 0.25 | 0.12 | 0.05 | 1.15–1.17 |
| cache with facts replay, exact types, checks kept | 0.57 | **0.093** | 0.12 | 0.05 | **0.97–0.98** |
| matched, no cache (TraitWorld 04095fe) | 0.44–0.46 | 0.19 | 0.13 | 0.06 | 0.94–0.99 |

A cache across sessions for trait code needs all three: the facts owner's code, the exact types, and the checks' results. With them the off-workload session runs like the on-workload one.

### E-175, S's caches with exact types, 2026-10-27

The same with the types serialized (`trace.jls`): S/pc 4.69–4.70 s (first solve 0.46, first plot 0.27, second model 0.22; 360 of 3,347 statements refused, 541 before); S/pnc 4.43–4.44 s (`logs/p175s/`). After the load, stock's session takes 1.1 s (0.8 s with `NoSpecialize`).

### E-176, the methods a load adds, 2026-10-27

`probe_external.jl` counts the methods a `using` adds, and those extending a function their package does not own (external), per package (`logs/p176/`). The load times of C and ScaleL in these logs are not valid (their images were stale after TraitWorld's commits, so those sessions compiled); the counts are.

| Load | methods added | external | load time (valid run) |
|---|---|---|---|
| S: OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie | 80,263 | 27,681 | 3.52 s |
| C: the same, SciML compiled by facts | 81,929 | 27,944 | 3.85 s (E-169) |
| D: TraitDifferentialEquations, TraitMakie | 9,196 | 3,806 | 0.45 s |
| Dp: PlainODE, PlainPlots | 6,925 | 3,086 | 0.16 s |
| ScaleL (4,000 workers) | 5,896 | 2,610 | 0.30 s (E-171) |

- **The stack's load follows its size in methods,** and that is its dependency tree: in S the most external methods come from Distributions (2,248 of 4,333; reached through Makie), SciMLBase (1,558), ForwardDiff (1,404), Makie (1,358), SparseArrays, DataStructures, Unitful, SciMLOperators. 381 packages in all.
- **A trait world is not cheap to load by any mechanism of its own:** ScaleL's external methods are mostly its implementations' registrations with TraitWorld's functions (1,764). It is cheap because it is small. The lever on the load is the tree's size: which packages a solver and a plotting core must load.

**The trees** (stock 1.13.2, two sessions each, `logs/p176/trees.log`): `using OrdinaryDiffEqTsit5` 0.34 s, 83 packages; with `OrdinaryDiffEqRosenbrock` 1.09 s, 156 packages (the linear-solver tree, SparseArrays, Pkg); `using CairoMakie` 2.68–2.70 s, 261 packages; all three 3.56–3.84 s, 386 packages. Makie binds REPL and FileIO binds Pkg. Python's whole import: 0.45 s.

**A plotting core's floor** (`probe_floor.jl`, stock 1.13.2, two sessions, `logs/p176/floor.log`): the dependencies the workload's plot plausibly needs, loaded without Makie (ColorTypes, Colors, FixedPointNumbers, Observables, ComputePipeline, GeometryBasics, StaticArrays, GridLayoutBase, FreeType, FreeTypeAbstraction, PlotUtils, Format, Cairo, PNGFiles): 0.51 s, 66 packages; with MathTeXEngine (Makie's default text) 0.72 s, 83 packages. CairoMakie's tree: 2.7 s, 261 packages. A core with Makie's algorithms on that tree loads its own code on top (Makie's image alone takes 0.71 s for 7,414 methods).

**The solver's floor** (`probe_floor_solver.jl`, two sessions, `logs/p176/floor-solver.log`): OrdinaryDiffEqTsit5, ForwardDiff and DiffEqBase 0.47 s, 98 packages; `OrdinaryDiffEqRosenbrock` adds 0.73 s and 55 packages (the linear-solver tree).

**An estimate for a port on lean trees:** a plotting core about 1 s, a solver about 0.5 s, Julia's startup 0.1 s, the work after the load with a cache about 1 s: a session of about 2.6–2.7 s, against Python's 1.45 s and stock's 9.2 s. An estimate from floors, not a measurement.


### Setting A (`all`), preliminary, 2026-10-27

The facts system image rebuilt for julia-1.13 252edca933 (231 s); `env_up` precompiled under `all` into `depot-A` (258 s). A warm-up and two sessions (`logs/p1A/`): A 14.88–14.91 s (load 8.33–8.44, first solve 4.83–4.90, first plot 1.23–1.25, second model 0.22); A/p 18.4–19.0 s; A/b 14.55–14.61 s (the plotting library's load moves into the first plot: 7.8 s). The new check flagged SHA and Sockets; a false positive: they come from the system image (the check now excludes modules in the system image). Under `all` the load doubles (CairoMakie compiled by facts; evidence §3 had 4.9 against 1.9 s for CairoMakie alone).

### E-177, the trait-specific test: a split cache, order B and a late load, 2026-10-27

`cache/make_split_cache.sh X` records a perturbed session with the solver library loaded first, splits the recorded types by dependency set (a type naming a package that only the plotting library brings goes to the plotting part), and builds two packages: `SessionCacheXS` (the solver part) and `SessionCacheXP` (the plotting part), each loaded by the workload as soon as its dependencies are (`/x`). The late load (`/l`): `using OffsetArrays, StaticArrays` after the second model, before "again". julia-1.13 252edca933, TraitWorld e6d5976; a warm-up and two sessions (`logs/p177/`; the runs' STALE flags are the false positives above). D's split: solver part 1,245 types, plotting part 3; Dp's: 1,057 and 20.

| Perturbed (to "again") | split cache, order A | split cache, order B | split cache, late load: "again" (compiling) | no cache, late load: "again" (compiling) |
|---|---|---|---|---|
| D (traits) | 1.02 s | 1.08–1.09 s | 0.020 s (0.00) | 0.020 s (0.00) |
| Dp (plain) | 0.65 s | 0.69–0.71 s | 0.064 s (0.04) | 0.064 s (0.04) |

**What it says:**
- **The trait-specific claim holds on this path, at a small scale:** after the late load, the plain twins recompile 0.04 s of their code, cached or not; the trait code recompiles nothing. At the large scale the same was measured without a cache (E-168): after CairoMakie loads late, stock recompiles 0.44 s, the facts-compiled SciML core 0.04 s.
- **Order B costs both alike** (0.05–0.08 s more in the first solve), so it is not the load order that the trait code is protected from here, but later loads that add methods to Base's functions.
- The plain twins stay faster in every cell at this scale; the traits' advantage is what later loads cannot take away, and it grows with the code that later loads would invalidate.

**At scale** (S, C, A; DataFrames added to `env_up` and `env_core` as the late load, `WL_LATE_PKGS`; the split caches for S and C; "again" split into its solve and its plot, `again_solve`; `logs/p177/`, `logs/p177b/`):

| Session (to "again") | load | first solve | first plot | second model | late load | again: solve | again: plot (compiling) | **session** |
|---|---|---|---|---|---|---|---|---|
| S/px (split cache, order A) | 3.64–3.70 | 0.80–0.81 | 0.39–0.40 | 0.46–0.47 | — | — | 0.05 | **5.45–5.55** |
| S/pxb (order B) | 1.16–1.17 | 0.48 | 2.99–3.01 | 0.41 | — | — | 0.59–0.60 (0.36–0.38) | **5.75–5.78** |
| S/pxl (late load) | 3.67–3.82 | 0.81–0.83 | 0.40 | 0.31–0.47 | 0.38–0.57 | 0.001 | 6.12 (6.05–6.06) | **12.0–12.1** |
| S/l (no cache, matched) | 3.64–3.76 | 3.86–3.93 | 1.54–1.57 | 0.17–0.21 | 0.40–0.44 | 0.001 | 6.15–6.23 (6.09–6.17) | **15.9–16.2** |
| C/px | 4.27–4.30 | 0.34 | 0.41 | 0.19–0.20 | — | 0.014 | 0.12 | **5.45–5.49** |
| C/pxb | 1.56 | 0.50 | 2.97–2.99 | 0.20 | — | 0.015 | 0.22 | **5.58–5.60** |
| C/pxl | 4.30–4.31 | 0.33–0.34 | 0.40–0.41 | 0.19–0.20 | 0.47–0.48 | 0.003 | 6.14–6.19 (6.08–6.13) | **11.97–12.03** |
| A/l (all by facts, no cache, matched) | 8.21 | 4.74–4.86 | 1.21–1.24 | 0.22 | 0.46–0.48 | 0.003 | **0.28 (0.02)** | 15.2–15.4 |
| A/pl (perturbed) | 8.22–8.48 | 6.55–6.57 | 1.34–1.36 | 2.43–2.46 | 0.47–0.48 | 0.003 | **0.11–0.12 (0.02)** | 19.3–19.6 |

**What it says:**
- **A later DataFrames load invalidates Makie's plotting code, where it is plain:** 6.1 s of recompiling in the plot after it, in S and in C (whose SciML core is compiled by facts, its Makie not), with or without a cache. The solves recompile nothing in any setting.
- **Compiled by facts (A), the same plot recompiles 0.02 s.** The design's load protection, at scale, in a realistic session: the trait-specific (facts-specific) gain on this path, and the reason for the port's first Makie step (Makie compiled by facts).
- **Its price is A's load:** 8.2 s against S's 3.6 s. Why facts images load slower is the next question (E-169's open item; open issue 73).
- With split caches, S and C both reach 5.45–5.55 s; order B costs S 0.36–0.38 s of recompiling in the plot after CairoMakie's load, C 0.

### Why setting A loads in 8.2 s, 2026-10-27

- **Per package** (`@time_imports`, `logs/p2/A-imports.log`): the sums are A 3.26 s against S 2.06 s; the largest differences are DelaunayTriangulation (+0.40 s), DataStructures (+0.19), ShaderAbstractions (+0.16), AdaptiveArrayPools (+0.11), Makie (+0.09), SparseArrays (+0.08). Most of A's extra 4.6 s falls outside any one package's time.
- **The profile** (`logs/p2/A-load-profile.log`, 7,629 samples): restoring images 4.18 s (S 1.6 s), of which `jl_specializations_get_linfo_` 3.05 s, in type-equality and subtype checks; validating edges 2.84 s (S 1.29 s).
- **The cause of the first:** A's images carry 1,058 specializations each of `Base._push!` and `Base.__safe_setindex!` at exact type-valued signatures, `(Vector{Type}, Type{Union{Tuple{…}, Tuple{…}}})`, whose signature types have no hash (`probe_hash0.jl`, `probe_specs_load.jl`). They come from the documentation system: `Docs.MultiDoc` keeps a `Type[]`, and each documented method with optional arguments pushes its signature's union of tuples. Inserting a specialization without a hash scans the method's whole list with `jl_types_equal` (`gf.c`, `jl_specializations_get_linfo_`), so the 2,116 insertions scan lists of about 2,900 entries. Plain Julia interprets that top-level code and keeps no such specialization (`repro_typepush.jl`: none in plain mode; 319 already in the facts system image); inferring the call creates one in either interpreter (`repro_typepush2.jl`). Under the facts image the code is inferred and the result kept in the package's image. W-59.
- **The second** (validation 2.84 against 1.29 s): not diagnosed.

### W-59's fix, measured, 2026-10-27

julia-1.13 6800be7839 (images keep no external code specialized at a signature type without a hash), the facts system image rebuilt, `depot-A` precompiled again (239 s). The hash-less specializations of `_push!` and `__safe_setindex!` are gone from what the load adds (`probe_hash0.jl`: the largest groups left are Makie's own `map`, about 100 each). A warm-up and two sessions (`logs/p59/`):

| Setting A | load | first solve | first plot | second model | late load | again: solve / plot (compiling) | **session** |
|---|---|---|---|---|---|---|---|
| before (julia-1.13 252edca933) | 8.21–8.44 | 4.83–4.90 | 1.23–1.25 | 0.22 | — | — | 14.88–14.91 |
| after, matched | **3.83–3.84** | 4.78–4.80 | 1.32–1.33 | 0.21 | — | 0.015 / 0.08 | **10.35–10.40** |
| after, late DataFrames | 3.79–3.86 | 4.89–4.90 | 1.33–1.34 | 0.21–0.22 | 0.25 | 0.003 / 0.11 (0.02) | 10.71–10.79 |

The load under `all` falls from 8.2 to 3.8 s, about stock's 3.6 s: the 4.4 s saved are both the insertion's scans and the validation of those instances. Makie compiled by facts keeps its protection (the plot after a late DataFrames load recompiles 0.02 s). The other settings' images were stale after the rebuild (the trailer's check flagged them) and are measured again.

**The other settings on julia-1.13 6800be7839** (re-precompiled: U 222 s, C 181 s, D 46 s; a warm-up and two sessions, all valid by the trailer's check; `logs/p59/`): U 9.47–9.59 s (load 3.57–3.74); C 10.75 s (load 4.15–4.16); D 0.99–1.00 s; Dp 1.19 s; A/b 10.2–10.4 s; after a late DataFrames load the plot recompiles 6.08–6.19 s in C and 6.17–6.19 s in U (Makie plain), as before. W-59 changed little outside `all` (C's load 4.27–4.30 → 4.15 s).

### E-178, reuse across call shapes, 2026-10-27

The CodeInstance-level caches rebuilt on julia-1.13 6800be7839 (and C's for the first time: 2,485 facts and 1,496 plain CodeInstances recorded), each from a perturbed session; used by matched sessions (`X/c`) and, for comparison, by perturbed ones (`X/pc`, the cache's own shapes). A warm-up and two sessions (`logs/p178/`).

| Session (to "again") | first solve | first plot | second model | **session** | no cache (`logs/p59/`) |
|---|---|---|---|---|---|
| S/c: matched, cache from perturbed | 3.66–3.80 | 0.26–0.27 | 0.16–0.17 | **7.84–8.11** | 9.16–9.17 (S, E-168) |
| S/pc: perturbed, its own shapes | 0.45 | 0.26 | 0.22 | 4.74 | 12.8–13.0 |
| C/c | 4.43–4.56 | 0.26 | 0.18–0.19 | **9.32–9.49** | 10.75 |
| C/pc | 0.33–0.34 | 0.27 | 0.19 | 5.31–5.35 | — |
| D/c | 0.08 | 0.11–0.12 | 0.05 | **0.99** | 0.99–1.00 |
| D/pc | 0.09 | 0.12 | 0.05 | 1.00 | 2.63 |
| Dp/c | 0.15 | 0.08 | 0.29 | **0.87–0.88** | 1.19 |
| Dp/pc | 0.18 | 0.08 | 0.04 | 0.65 | 1.82–1.84 |

**What it says:**
- **SciML's solver code is not reused across call shapes:** a cache from `Tuple` parameters and a range of saving times leaves the matched session's first solve compiling as without a cache (S 3.7 s, C 4.5 s). The plotting code is reused (first plot 0.26 s instead of 1.5 s).
- **So a cache across sessions pays once per call shape** on SciML's path; the core's entry must normalize what it can (the options record of the port note's move 1b) for a cache to recur. The parameters' type, which the right-hand side reads, stays a key.
- Dp's second model is not reused (a new function, compiled per signature by its wrapper), D's is (the model `Dynamic`).

### E-179, a lean Makie, 2026-10-27

`lean/`: forks of Makie 0.24.16, CairoMakie and ComputePipeline (the port's clone, commit 47479e0a) without StatsBase, Distributions, KernelDensity, StatsFuns, DelaunayTriangulation, TriplotBase, Unitful, SparseArrays, REPL, FFMPEG_jll and Downloads. Features dropped (open issue 75, option (i)): the statistics recipes (`hist`, `density`, `ecdf`, `qqplot`, `qqnorm`, `boxplot`, `violin`, `crossbar`, `hexbin`, `raincloud`), `tricontour`, `tricontourf`, `triplot`, `voronoiplot`, `spy`, units on axes, video recording, the downloaded texture atlas, the REPL's field docs. Contours (Contour, Isoband) kept. Each change is marked `E-179 lean` in the source. Setting `L`: stock 1.13.2, `lean/env_lean`, `depot-S`; a warm-up and two sessions (`logs/p179/`).

| | load | first solve | first plot | second model | **session** |
|---|---|---|---|---|---|
| L (lean Makie) | 3.15–3.17 | 3.68–3.73 | 3.73–3.75 | 0.16–0.17 | **10.94–10.98** |
| S (upstream, E-168) | 3.54–3.56 | 3.75–3.76 | 1.51 | 0.19 | 9.16–9.17 |

`using CairoMakie` alone: lean 2.32 s and 173 packages, against 2.7 s and 261.

**What it says:**
- **Dropping Makie's heavy dependencies saves 0.4 s of the load.** The rest is not Makie's own code alone (the attribution below): the port must shrink both the plotting core (`PlotCore`) and the tree it keeps.
- The lean fork's first plot compiles 3.7 s against 1.5 s: its precompile workload covers less of the path (not diagnosed: the forks are dev'd paths, built from the clone's commit).


### E-180, TraitWorld's cache across sessions as a mechanism, 2026-10-27

TraitWorld branch `session-cache` (`src/cache.jl`, commit 031932a), julia-1.13 6800be7839. Variant `/k`: `JULIA_TW_CACHE=1`, the builder run synchronously at exit (`JULIA_TW_CACHE_BUILD=sync`), the cache in `cache/tw-cache-<setting>/` (not committed). The warm-up session (`-w`) starts with an empty cache, records, and its exit runs the builder; the sessions after it load the parts. Off-workload shapes (`/p`). Logs: `logs/e180a/` (D), `logs/e180c/` (C). Probe: `cache/probe_k.jl` (what a session with the cache still compiled).

| | load | first solve | first plot | **session** | the cache's load | recording at exit | builder |
|---|---|---|---|---|---|---|---|
| D/p, no cache | 0.45–0.46 | 1.53–1.57 | 0.13 | **2.36–2.39** | | | |
| D/pk | 0.62–0.64 | 0.093–0.097 | 0.15 | **1.06–1.08** | 5 parts, 0.15 s | 0.09 s | 27 s (1,270 entries), then 2–5 s |
| D/pkb (order B, the cache recorded in order A) | 0.47–0.49 | 0.13–0.18 | 0.23–0.25 | **1.05–1.11** | 0.15 s | 0.09–0.12 s | |
| D/pkl (a late load) | 0.62–0.63 | 0.09 | 0.14 | **1.16–1.19** (late step 0.12–0.14) | | | |
| D/pks (strict mode) | 0.79–0.88 | 0.12–0.13 | 0.12 | **1.22–1.33** | | | |
| C/p, no cache | 4.22–4.28 | 10.98–11.51 | 1.52–1.58 | **19.2–19.95** | | | |
| C/pk | 4.51–4.63 | 0.52 | 0.62–0.63 | **6.07–6.19** | 45 parts, 0.45 s | 0.13 s | 174 s (3,418 entries) |

The outputs (solutions, images) are identical with and without the cache in every D setting. Strict mode (`experiments/docs-examples/strict.jl`, three sessions, the second and third with the cache): the same 5 of 5 checks, the pirate refused and the harmless one accepted.

**What it says:**
- **The mechanism reproduces the emulation** (E-175: D 0.97 s) with no step by hand: D's off-workload session 2.4 → 1.07 s, C's 19.4 → 6.1 s.
- **Order independence holds** for the session with a cache recorded in the other order (D/pkb's first session 1.10 s).
- **The cost is the parts' load:** about 30 ms a part for D, 10 ms a part for C, 45 parts for C's 3,418 entries. Coarser parts are the next lever.
- Three faults found on the way, fixed: the builder inherited `--pkgimages=existing` and made images without native code (the session generated the code again, 0.3 s a signature); a package callback runs inside `require`, whose cache of the load path predated the parts' directory; the cache's own code was not in TraitWorld's image (0.5 s at exit).
- Each session with the cache still compiles about 220–280 signatures the store has (TraitWorld's own code before its part loads, and code the session invalidates): about 0.1 s, not diagnosed further.

**Where the parts' load goes** (C, `cache/probe_parts.jl`, `logs/e180c/parts.log`; the workload's packages loaded first, then each part in turn): the freshness check 1.3–5 ms a part (0.076 s in all), the load 4–23 ms a part (0.34 s). Parts of 1–8 entries take 4–8 ms each; the largest, 15–23 ms (OrdinaryDiffEqTsit5 487 entries, OrdinaryDiffEqRosenbrock 571, LinearSolve 105). About 20 of the 45 parts hold fewer than 10 entries. A part's load is mostly a fixed cost.

### E-181, the parameters at the surface, 2026-10-27

`params/`: `params.jl` (a fresh session's first solve of Lorenz with Tsit5 and Robertson with Rodas5, with parameters of kind `vector`, `tuple`, `namedtuple`, or a struct defined in `Main`; then the steady state) and `steady.jl` (per solver, longer solves, a callback reading `integ.p`, the minimum of 50), run by `params/run.sh <branch>`. TDE `w34` 669cd9b (the parameters' type a key of the solver) against `partial-p` 6234487 (the right-hand side partially evaluated on the parameters, the solver keyed on the state's type; now w34). julia-1.13 6800be7839, TraitWorld 5589f4c; product setting; no cache; two fresh sessions each. Logs: `logs/e181/`, `logs/e181d/` (setting D after the change).

| first solve (s) | vector (workload) | tuple | namedtuple | struct in `Main` |
|---|---|---|---|---|
| w34 669cd9b | 0.14–0.15 | 1.31–1.34 | 1.27–1.32 | 1.51–1.56 |
| partial-p, first build (the function also entered at the old signatures) | 0.16 | 0.38 | 0.36–0.38 | 0.54–0.56 |
| partial-p 6234487 | 0.16 | 0.21 | 0.20 | 0.26 |

| steady state (ms, min of 50) | Tsit5, Lorenz (0, 100) | Rodas5, Robertson | Tsit5 with a callback |
|---|---|---|---|
| w34 669cd9b, vector / tuple | 0.26–0.27 / 0.25 | 0.16 / 0.18 | 0.29–0.31 / 0.31 |
| partial-p 6234487, vector / tuple | 0.26–0.28 / 0.26–0.28 | 0.17 / 0.17 | 0.32–0.33 / 0.32–0.33 |

Setting D after the change (`logs/e181d/`): matched 0.965 s (before 0.94–0.99), off-workload 1.11–1.12 s (before 2.36–2.39).

**What it says:**
- **The parameters' type need not reach the solver.** A new parameter type compiles the user's function and the outer layer's small records, 0.05–0.1 s beyond the workload's type, instead of the solver (1.1–1.4 s).
- **The steady state is unchanged within about 5%,** with the same steps: the parameters move from an argument of the dynamic call into the record.
- The first build entered the user's function at the old signatures too (0.19 s per new parameter type in the record's constructor): the outer layer must not keep forms the core does not use.

**E-179's load attributed** (2026-10-27, after [the memo's review](../../writeup/reviews/2026-10-27-lean-core-memo.md) M6; `@time_imports using CairoMakie` in `lean/env_lean`, stock 1.13.2, `depot-S`, one session; `logs/e179m6/lean-imports.log`): 2.28 s in all, the packages' increments 2.08 s over 168 packages. Makie 0.60 s, CairoMakie 0.29 s, ComputePipeline: 0.89 s together (43%). The other 165 packages 1.19 s, among them SparseArrays 0.23 s (through Interpolations, AxisAlgorithms, WoodburyMatrices), Pkg 0.13 s (through FileIO and Makie), StaticArrays 0.12 s, ImageCore 0.07 s, GeometryBasics 0.07 s, REPL 0.06 s (through MathTeXEngine, UnicodeFun). The lean fork dropped SparseArrays and REPL as Makie's own dependencies; they come back through others.

### E-183, what of Makie's own code the workload's plot runs (W-60's X1), 2026-10-27

One untimed session of the workload in S (stock 1.13.2, `env_up`, `depot-S`), with line coverage of Makie 0.24.16's source (`--code-coverage=@<Makie's src> --code-coverage=logs/x1/makie.info`). With coverage on for Makie, its image's native code is not used: the session compiled 24.4 s in all, against about 6 s without, so the functions that ran were compiled with counters. Logs: `logs/x1/` (`makie.info`, the lcov trace; `summary.txt`).

- **2,710 of about 44,400 code lines run (6.1%), in 52 of 150 files.** By file or directory: `makielayout/` 841 (the `Axis`, its ticks, spines and layout), `compute-plots.jl` 316 (the plot's ComputePipeline graph), `basic_recipes/` 264, `camera/` 165, `layouting/` 159, `scenes.jl` 135, `conversions.jl` 127, `utilities/` 109; the rest under 65 each.
- **No line that calls MathTeXEngine or makes a `LaTeXString` ran:** the log axis's tick labels are rich text (`richtext.jl`, 5 lines), not LaTeX. MathTeXEngine (0.21 s of the floor, and REPL through it) is a candidate for a loading stub.
- **What it says:** a `PlotCore` slice for this workload is a small part of Makie; the axis is its largest piece. Splitting can make the core lean; the compatibility machinery's share on this path is `compute-plots.jl` and the conversions (about 450 lines run).

### E-184, normalization at the entry at upstream scale (W-60's X5), 2026-10-27

Setting S (stock 1.13.2, `depot-S`). `workload.jl`'s new switches: `WL_PARAMS` and `WL_SAVEAT` set the parameters' and saving times' shapes one at a time; `WL_NORM=1` sends each `solve` through a wrapper (`nsolve`) that turns `saveat` into a `Vector{Float64}` and the tolerances into `Float64`. Caches: E-175's emulation at the level of CodeInstances (`CI=1 CACHE_TAG=<tag> bash cache/make_cache.sh S [n]`), each recorded from a session with `Vector` parameters and a **range** of saving times, used by sessions with **vectors**. `n`: the user's function behind SciMLBase's `NoSpecialize` (E-174), the stand-in for SciML's move 1. A warm-up and two sessions each; logs `logs/e184*/`.

| | first solve (s) | session (s) |
|---|---|---|
| no cache, the wrapper (`logs/e184/`) | 3.85–3.94 | 9.37–9.56 |
| a cache from ranges, no wrapper (`logs/e184raw/`) | 1.50 | 6.00–6.03 |
| a cache from ranges, the wrapper (`logs/e184norm/`) | 0.51 | 4.87–4.91 |
| `NoSpecialize`, no cache (`logs/e184n/`) | 7.34–7.61 | 12.69–13.01 |
| `NoSpecialize`, a cache from ranges, the wrapper (`logs/e184nnorm/`) | 0.12–0.13 | 4.48–4.50 |

The residual with the wrapper (`logs/e184norm/residual.jl`, `--trace-compile-timing`): the session's `nsolve` path at problem types that name the user's function (`ODEFunction{true, …, typeof(lorenz!)}`), 0.56 s of compile roots, and the plotting and digest code at the solution's type.

**What it says:**
- **Normalizing at the entry makes the cache recur across call shapes:** the first solve 1.50 → 0.51 s.
- **What remains is keyed on the user's function** through the problem's type. With the function out of that type (`NoSpecialize`, standing in for move 1), the first solve from a cache recorded with other call shapes takes 0.12 s. Move 1 is needed for recurrence, as the memo's X5 predicted it might be.
- Without a cache, `NoSpecialize` costs 7.3–7.6 s: upstream's images cover the `AutoSpecialize` path only. A port's images must cover its own erased path (as TDE's do).

### E-185 and E-186, the load's validation remembered (W-64), 2026-10-27

**E-185** (`loader/prof_load.jl`, `logs/e185/`): the profiler over the workload's `using` in S (stock 1.13.2, one session). Of the main thread's samples: edge validation about 34% (about 1.4 s), method activation about 27%, promoting validated code 0.4%.

**E-186** (`loader/e186.sh`, variant `/v`: `JULIA_REMEMBER_VALIDATION=1`): julia-1.13 f1866b9d4e (the change of [W-64's note](../../writeup/plans/2026-10-27-remembered-validation.md), revision 2), each environment precompiled again on it, the remembered outcomes cleared; a warm-up session records, three sessions reuse. U: the patched Julia, upstream packages, plain; C: the facts-compiled SciML core with CairoMakie. Logs `logs/e186/` (run 1, on 30a89bc2fe with an identity set per image, in `logs/e186/run1/`).

| | load | first solve | first plot (GC) | session |
|---|---|---|---|---|
| U | 3.74–3.90 | 3.66–3.73 | 1.58–1.62 (0.07) | 9.36–9.55 |
| U/v | 3.11–3.13 | 3.69–3.79 | 1.78–1.81 (0.18) | 8.95–9.07 |
| C | 4.31–4.34 | 4.67–4.68 | 1.50–1.51 (0.03) | 10.85–10.89 |
| C/v | 3.53–3.54 | 4.57–4.67 | 1.73–1.76 (0.16–0.19) | 10.27–10.38 |

- The digests are the same in all twelve sessions.
- **The chain:** a session that defines `f() = 1` before `using OrdinaryDiffEqTsit5` records 83 outcomes (386 → 469 files); the same definition again reuses them (the load 0.344 → 0.282 s); `g(x::Int) = 2` instead records new ones (552).
- **What it says:** remembering validation saves 0.6–0.8 s of the load, about half of E-185's 1.4 s: the walk, the backedges and the cache insertions remain. The first plot pays 0.17–0.25 s more, all of it a garbage collection that the load's own garbage triggered earlier without the remembered path (run 1's identity set was not the cause: the same with run 2's sentinel). Net, a session gains about 0.5 s.

### E-188, the origins of a session's facts code (W-66 step 1), 2026-10-27

`cache/probe_origins.jl`: the runtime's newly-inferred list switched on from the start of a session; after the workload, for each CodeInstance of owner `:facts` the session made, its origins: the packages owning its method, its signature's types, and its edges' callees and signatures. julia-1.13 41d199c557, TraitWorld 5589f4c, TraitDifferentialEquations 6234487; one session each; `logs/e188/`.

| | D/p (trait demonstrators) | C/p (the facts-compiled SciML core, CairoMakie) |
|---|---|---|
| CodeInstances made: facts / plain | 95 / 475 | 11,543 / 11,453 |
| facts, naming the session's own code or types | 32 | 363 |
| facts, cacheable | 63 | 11,180 |
| origins per entry besides Base and Core (mean, max) | 0.94, 3 | 1.97, 18 |
| entries on Base and Core only | 24 | 5,622 (50%) |
| distinct origin sets | 7 | 213 |
| packages that are an origin (of those loaded) | 3 (of 68) | 39 (of 398) |
| the largest share one package's new version invalidates | 41% (TraitDifferentialEquations) | 24.7% (LinearAlgebra), then SciMLBase 19.9%, DiffEqBase 16.6% |

C's session compiled 20.9 s during its load (an extension image stale in `depot-C`, as in E-187), so its counts include code compiled at load.

**What it says:**
- **Keyed on origins, a cache keeps most of itself across a change:** half of C's cacheable facts code depends on Base and Core only, the rest on 39 of 398 packages; no single package's new version invalidates more than a quarter. An environment key loses all of it at any change.
- **A facts-only cache leaves plain code out:** in C half of what the session compiles is plain (most of it Base's methods called from plain code); in D, after the parameters moved to the surface (E-181), the session compiles little of either. In a whole trait world the plain share is what plain layers call.
