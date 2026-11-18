# Re-baseline on stock Julia 1.13.2 (2026-10-16)

The measurements of `world/`, `lens/`, `interfaces/` (x12, x13), `solvers/` and `errors/`, re-run on stock Julia 1.13.2 (juliaup), compared with the Julia 1.12.2 numbers in the READMEs, in `writeup/design-findings.md` §12–§18 and in `writeup/explorations/solvers.md` and `runtime.md` of the design repository. Nothing was built; no juliac.

**How it ran.** One Julia process at a time, `nice -n 10`, `JULIA_NUM_PRECOMPILE_TASKS=4`, `JULIA_PKG_OFFLINE=true`; at least three fresh processes per timing, min–max given. Load averages (1/5/15 min) were logged with every run. Most of them were 1.3–3.5 while one of my processes ran. The sandbox hides other users' processes, so the load average is the only sign of other work.

**Which numbers were re-taken.** Between 13:00 and 13:25 CEST (11:00–11:25 UTC) the main session ran TraitWorld's test suite several times. Everything timed in that window was taken again after 13:27 on a machine with no other Julia jobs, and only the re-taken numbers appear below:
- x13 (13:27–13:31);
- x12 (13:31–13:34);
- the solver scripts on both versions (13:34–13:37);
- the pinned world benchmarks on both versions (13:37–13:40);
- the cold precompile timings (13:40–14:07).

Taken before the window and kept: the first world batch (12:51–12:56), the lens benchmark (12:55–12:56) and the 1.13.2 OrdinaryDiffEq precompile (12:57–12:59). The error-message sizes are counts, not timings. During the re-take the machine was 3–5% slower than in the morning, even for plain loops (`plain_total` at 4096: 14.25 µs at 12:51, 14.75–15.39 µs at 13:37). So ratios hold up better than absolute times. The cold precompiles ran at load 3–6, which is more than my 4 tasks account for, so other non-Julia work was probably running.

**TraitWorld was pinned.** Another session was editing `TraitWorld/` during the run: two commits, 3a1d3a6 at 12:55 and 2830a19 at 13:02, then uncommitted changes. One of those intermediate states failed to precompile (`UndefVarError: ##R#151 not defined in TraitWorld._PC`, TraitWorld.jl:78). All TraitWorld-dependent numbers below therefore use a snapshot of commit **2830a19**, made with `git archive`, and copies of the environments that point at it (`baseline-1.13/pin_env.sh`). Nothing in `TraitWorld/` was touched. The first world batch (12:51–12:56) used the live tree, at about 98b3f5c. It is listed separately.

**1.12.2 controls.** Many recorded 1.12 numbers were taken with older TraitWorld versions and on a differently loaded machine. Where it was cheap, the same scripts were also run on 1.12.2 with the same TraitWorld snapshot, the same day, as a control. Two cases:
- **SciML:** the control used a separate cold depot holding exactly the packages of the v1.12 default environment's manifest (`JULIA_DEPOT_PATH=$TMPDIR/depot112`, with `packages`, `registries` and `artifacts` symlinked to `~/.julia`), so the shared `~/.julia/compiled/v1.12` was not touched. That depot is deleted.
- **x12 on 1.12.2:** not re-run (see "Not done").

## Environments

| environment | 1.13 manifest | resolution |
|---|---|---|
| `world/env` | `Manifest-v1.13.toml` | offline, no package changes |
| `world/concrete/env` | `Manifest-v1.13.toml` | offline, no package changes |
| `interfaces/env` | `Manifest-v1.13.toml` | offline. Registry packages unchanged (CSV 1.1.0, CairoMakie 0.15.16, DataFrames 1.8.2, Makie 0.24.16, …); only standard libraries and their JLLs moved to the 1.13 versions (LinearAlgebra 1.13.0, OpenBLAS_jll 0.3.30, LibCURL 1.0.0, …) |
| `solvers/env` (new) | `Project.toml` with `OrdinaryDiffEq` only, `Manifest-v1.13.toml` | resolved offline from a copy of `~/.julia/environments/v1.12/Manifest.toml`, so the versions are the 1.12 baseline's: OrdinaryDiffEq 7.0.0, OrdinaryDiffEqCore 4.2.1, OrdinaryDiffEqTsit5 2.0.0, OrdinaryDiffEqRosenbrock 2.2.0, SciMLBase 3.13.0, DiffEqBase 7.5.0, ForwardDiff 1.3.3, LinearSolve 3.80.0 |

The 1.12 `Manifest.toml` files are unchanged. The network was never needed. Two kinds of attempt were blocked by the sandbox and harmless:
- `pkg.julialang.org` (Pkg's registry update check; offline mode then used the local registry);
- `julialang-s3.julialang.org` (most likely juliaup's version check at every start).

## 1. world: per-element costs, entry, definition checking, concrete mode

`bench_m1.jl`, `bench_m5.jl`, `defcheck_demo.jl skip|noskip`, `concrete/run.jl`. Columns:
- "1.12 recorded" is the README or findings number;
- "1.12.2 control" and "1.13.2" are the re-take (13:37–13:40, TraitWorld 2830a19);
- "1.13.2, first batch" is 12:51–12:56 (live TraitWorld at about 98b3f5c, quieter machine).

| measurement | 1.12 recorded | 1.12.2 control | 1.13.2 | 1.13.2, first batch | notes |
|---|---|---|---|---|---|
| `total`, 4096 elements, representation / projection vs plain | 1.00–1.01× | 0.99–1.02× / 1.01–1.03× | **1.00–1.02× / 1.00–1.02×** | 1.01× / 1.01–1.03× | unchanged: the steady state is plain Julia |
| the same, 16 elements | 2.8–3.0× (101 / 105–107 ns, plain 35.5–35.9) | 2.85–2.86× / 2.91–2.98× (108–109 / 111–113 ns, plain 38) | **3.35–3.51× / 3.46–3.68×** (108–112 / 111–119 ns, plain 31.9–32.2) | 3.23–3.35× / 3.41–3.49× (99–104 / 104–108 ns, plain 30.5–30.9) | the entry costs the same; 1.13's plain loop is faster (32 vs 38 ns), so the ratio rises |
| dynamic operations, 4096 | 7.0–7.3× (6.3–6.4 ns/el) | 7.09–8.38× (6.5–7.8 ns/el) | **6.75–6.85× (6.2–6.3 ns/el)** | 6.69–6.94× (5.8–6.0 ns/el) | |
| `colsum` specialized / `colmap` erased, 16 elements | 120–127 / 219–220 ns | 222–245 / 317–360 ns | **222–229 / 340–350 ns** | 194–206 / 293–306 ns | |
| fixed cost per call (`colsum` at 16 minus `sum`) | about 110 ns | 214–236 ns | **216–223 ns** | 189–200 ns | **doubled since M5 on both versions**: a TraitWorld change, not 1.13 |
| erased per element, 4096 | 4.0–4.4 ns | 4.4–4.6 ns | **4.2–4.7 ns** | 4.1–4.3 ns | |
| specialized / `abs2`, 4096, vs plain | 1.31× / 1.47× | 1.52–1.59× / 1.81–1.88× | **1.52–1.54× / 1.71–1.90×** | 1.49–1.51× / 1.77–1.86× | worse than recorded on both versions: TraitWorld |
| first call of a new closure: erased / plain `map` / specialized | 7.3–8.4 / 19–20 / 35–36 ms | 8.6–16.1 / 24.6–28.9 / 47.8–55.6 | **8.2–9.4 / 22.8–25.8 / 52.3–56.1** | 6.6–6.7 / 19.3–20.2 / 43.0–44.1 | |
| fresh session, projection: implement + first calls | 123–128 + 9–10 ms | 144–158 + 12–18 | **145–157 + 12–14** | 123–126 + 9.8–10 | |
| fresh session, dynamic operations | 241–259 + 118–127 | 328–338 + 32–33 | **294–303 + 29–30** | 249–253 + 23–143 | first calls are bimodal on 1.13 in the first batch (23 or 143 ms) |
| fresh session, own representation | 204–209 + 104–107 | 267–274 + 150–158 | **256–261 + 167–170** | 223–232 + 145–160 | |
| `check_definitions(Columns)`, cold | 184–199 ms | 214–255 | **184–213** | 164–172 | |
| first `colrange` of a new representation, skip / noskip | 21.4–21.6 / 24.8–25.5 ms | 26.5–31.7 / 28.2–44.1 | **23.7–29.9 / 25.1–25.5** | 20.8 / 22.4–23.6 | the 1–3 ms gain from skipping is within noise in the re-take; visible in the first batch |
| first `colmean` / `meandiff`, skip | – | 66–85 / 13.7–16.5 | **64–79 / 11.8–14.7** | 53–61 / 9.5–9.8 | |
| concrete mode: abstract vs typed field | 66.0 vs 0.89 ns/el, 74× | 68.7–78.6 vs 0.94–1.16, 68–75× | **66.5–68.9 vs 0.93–1.03, 66–71×** | 67.1–74.4 vs 0.91–0.96, 73–78× | unchanged |
| `check_concrete` | 91 ms | 122–127 | **113–115** | 98–106 | the build-time warning appears on 1.13 as on 1.12 |

**Reading.** The design's steady-state claims hold on 1.13 unchanged: 1.00–1.02× at 4096, about 6 ns per element for a type's own operations, and the 70× cliff for an abstract field. The entry's fixed cost is now about 200–220 ns on both versions, against the recorded 110 ns. The control locates the regression in TraitWorld since M5, not in 1.13: the Callable-mode rework, sealing, view-cache recording and the definition-check flag are all on the path. It deserves its own look.

## 2. Lens (`lens/lens_bench.jl`, -O2, 10^8 accesses, best of three; 12:55–12:56)

| access | 1.12 recorded (§18) | 1.12.2 control | 1.13.2 |
|---|---|---|---|
| read, direct field | 1.04 ns | 0.87–0.88 | 0.87–0.94 |
| read, held value | 1.03 | 0.87–0.88 | 0.87–0.93 |
| read, lens via builtin `getfield(::Any, i)::R` | 4.6–4.7 | 3.85–4.58 | 4.27–4.59 |
| read, lens via a load at the byte offset | 1.15 | 0.87–0.88 | 0.87–0.94 |
| write, direct | 0.6 | 0.46 | 0.53–0.57 |
| write, lens via builtin `setfield!` | 13.6 | 10.35–10.66 | 10.56–10.83 |

The same on both versions. The offset load now costs exactly a direct read. The recorded §18 numbers come from a slower moment of the machine; the liveness check (lens 10.0, snapshot 1.0) passes.

## 3. interfaces: view caches (x12) and Makie as trait world (x13), with the load filter injected

**Injection on stock 1.13.2: it works.** `runtime-injection/exp113/inject113.jl` includes the ported `reinfer_tw_1132.jl` into `Base.Compiler.ReinferUtils`. It then calls `Base.Compiler.activate_codegen!()`, advances `Base._require_world_age`, and runs the measurement script. Costs: the injection 0.105–0.134 s, `activate_codegen!` 0.007–0.009 s.
- It keeps image edges at load: 270 in x12 "before", 265 in x13 with CSV first.
- With `JULIA_TW_PROTECT` it keeps 1,062–1,369 edges.
- It removes the trait-world recompilation in every case where the outside packages load before the cached code.

As on 1.12, it does nothing for code that loads first and is invalidated later at method insertion ("after"). That half needs the C patch.

### x12 (`interfaces/scripts/x12_viewcache.jl`; view cache recorded on 1.13.2 into a fresh `JULIA_TW_VIEWCACHE_DIR`: 1 package, built in 1.8 s; first calls in a new session)

| first call | 1.12 recorded: no cache / stock cache (session 21) / stock, session 22 rerun / injected (1.12.2) | 1.13.2 no cache | 1.13.2 stock, view cache | 1.13.2 injected, view cache |
|---|---|---|---|---|
| `summarize(ramp)`, lean | 106–139 / 3.1 / – / – | 104–106 ms (43–44 recompiling) | **3.1–3.2 ms** | 3.1–3.2 ms |
| `summarize`, CSV and Makie before | 1188 (1060) / 3.3 / 31.8–31.9 / **3.5–3.6** | 871–887 (808–824) | 71–72 (68–69 recompiling) | **3.2–3.6 ms** (270 edges kept) |
| `summarize`, after | 959 (839) / 3.3 / 33.5 / 3.4 | 902–924 (838–859) | 73–74 (69–71) | 78–84 (75–81): insertion, not helped |
| `histcounts`, `zscores`, `colstd` | 7–45 / 0.1–0.6 | 26–36 ms each | 0.1–0.6 | 0.1–0.6 |
| `report(ramp)`, lean | 60–77 / 5.0 | 66–68 | 5.0–5.2 | 5.1–5.3 |
| `report`, before | – / 30 / 28.3–29.3 / **4.9** | `TraitUseError` | 26–31 (23–28 compiling, 0 recompiling) | **4.4–4.9 ms** |
| `report`, after | – / 30 / 28.0 / 28.4 | `TraitUseError` | 26–27 (21–23 recompiling) | 26–29 (22–24 recompiling): not helped |
| load time, before / after | – / – / 5.4–5.8 s / 5.6–5.8 | 4.3–4.5 / 4.9–5.0 s | 4.4 / 4.9–5.1 | 4.7–4.8 / 5.2 |

Notes:
- **No cache, CSV and Makie loaded:** `report` stops with `TraitUseError: Reports.jl:67 calls InlineStrings.string / Format.string, outside the trait world (rule 1)`. Its abstract `string` call resolves to those packages' methods once they are loaded. The 1.12 table shows "–" in these cells; this is the reason. With the view cache the signature counts as checked at build time, so no error.
- **1.13.2 stock `summarize` with outside packages:** 71–74 ms, against 3.3 ms in session 21 and 31.8 ms in session 22's 1.12 rerun. It is recompilation either way, and the injected filter takes it to 3.2–3.6 ms. Without a 1.12.2 control at TraitWorld 2830a19 it is open whether 1.13 or TraitWorld moved it.
- **A lean session also recompiles 43 ms of `summarize`** without a cache on 1.13. Not traced.

### x13 (`interfaces/scripts/x13_makie_protected.jl`; read `sample.csv`, summarize, histogram, PNG; `JULIA_TW_VIEWCACHE=0`)

`JULIA_TW_PROTECT` = Makie's tree, computed from the 1.13 manifest: CairoMakie's dependencies without standard libraries and JLLs, plus MakiePlots, 141 packages, as in session 21 (`baseline-1.13/makie_tree_113.txt`).

| | 1.12.2 patched build (session 21) | 1.13.2 stock | 1.13.2 injected, trait stack only | 1.13.2 injected, Makie's tree protected |
|---|---|---|---|---|
| to the first PNG, default order | 15.7–16.0 s (filter off) | **14.22–14.28 s** | 14.49–15.11 | **8.32–8.49 s** |
| to the first PNG, CSV and DataFrames first | 16.1–16.2 | 14.34–14.42 | 14.32–14.54 | **8.09–8.12** |
| read, summarize, plot, PNG after loading | 10.3–10.6 | 9.81–9.97 | 9.76–10.32 | **3.47–3.59** |
| compiling during it (recompiling) | 10.2–10.5 (5.1–5.4) | 9.75–9.87 (4.40–4.62) | 9.69–10.25 (4.34–4.61) | 3.42–3.53 (0.68–0.84) |
| load | 5.4–5.7 | 4.31–4.52 | 4.47–4.79 | 4.58–4.90 |
| image edges kept at load | – | – | 22 / 265 | 1,062 / 1,369 |
| with Makie protected, patched 1.12 | 8.5–8.9 s first PNG; 2.9–3.3 s work (0.6 recompiling) | | | |

- **The ad-hoc time to first PNG on stock 1.13.2 is 14.2–14.4 s,** against 15.7–16.2 s on the 1.12.2 build with the filter off. The load is 4.3–4.5 s instead of 5.4–5.7 s.
- **With the injected load filter and Makie's tree protected, stock 1.13.2 matches the patched 1.12 build:** 8.1–8.5 s in both orders. Makie recompiles almost nothing (0.7–0.8 s left).
- **Why the default order also benefits** without the insertion half: DataFrames depends on InlineStrings and SentinelArrays, the main invalidators. DataFramesWrapper loads it before MakiePlots, so the invalidators precede Makie in both orders.

## 4. Solvers: stock SciML on 1.13.2 (the TraitDifferentialEquations baseline)

`solvers/ttfs_baseline.jl`, `ttfs_repeat.jl`, and the new `ttfs_detail.jl`: the same steps with `@timed`, so each has compile, recompile and GC time and allocations, plus a second loss closure and a final full GC. Lorenz on a 3-vector, `(0, 1)`. One fresh session per run, three runs each, re-taken 13:34–13:37. The 1.12.2 control used identical package versions in a cold depot.

| scenario | 1.12.2 recorded (solvers.md, single runs) | 1.12.2 control | **1.13.2** | compiling share (1.13.2, `ttfs_detail`) |
|---|---|---|---|---|
| `using OrdinaryDiffEq` | 2.6 s | 1.80–1.84 s | **1.73–1.77 s** | 0.06 s compile, 0.22–0.26 s GC (1.12: 0.19 s compile, 0.41–0.44 s GC) |
| Tsit5, first solve | 0.16 | 0.143–0.147 | **0.141–0.168** | all compile |
| Tsit5, a second model function | 0.16 | 0.122–0.125 | **0.101–0.109** | all compile |
| Tsit5, `Vector{Float32}` state | 2.06 | 1.80–1.88 | **1.56–1.57** | all compile (0.02 s recompiling) |
| Tsit5 + `DiscreteCallback` | 0.84–0.96 | 0.80–0.82 | **0.80–0.83** | all compile |
| another `DiscreteCallback`, new closures (`ttfs_repeat`) | 0.96 | 0.81–0.96 | **0.67–0.83** | |
| `CallbackSet` of both (`ttfs_repeat`) | – | 0.83–0.99 | **0.72–0.76** | |
| Tsit5 + `ContinuousCallback` | 1.10 | 1.10–1.13 | **0.98–1.09** | all compile |
| Rodas5, first solve | 1.43 | 1.40–1.42 | **1.45–1.49** | all compile |
| Rodas5, a second model function | 0.08 | 0.077–0.080 | **0.069–0.075** | |
| `ForwardDiff.gradient` through Tsit5, first | 1.97–2.73 | 1.89–1.93 (`ttfs_repeat`: 2.29–3.09) | **1.67–1.72** (`ttfs_repeat`: 1.83–1.89) | all compile |
| the same, a second loss closure, same shapes | 2.48 | 1.86–2.16 (`ttfs_detail`: 2.08–2.14) | **1.54–1.61** (`ttfs_detail`: 1.80–2.06) | all compile, no recompiling |
| second calls of anything | 0 | 0 | 0 | |
| allocations: Float32 / gradient / second loss | – | 395 / 470 / 449 MB | 304 / 355 / 340 MB | |
| full GC at the end of the session | – | 0.30–0.40 s | **0.12–0.16 s** | image objects are no longer marked |
| total GC in the session / max RSS | – | 1.55–1.69 s / 878–883 MB | **1.06–1.14 s / 791–812 MB** | |

| `typeof(integrator)` | 1.12.2 | 1.13.2 |
|---|---|---|
| Tsit5 | 3,553 chars, 75 parameter lists | **3,553, 75** |
| Tsit5 + `DiscreteCallback` | 3,683, 77 | **3,683, 77** |
| Rodas5 | 24,426, 708 | **24,426, 708** |

- **1.13 is 0–20% faster per step:** Float32 −15%, gradients −10 to −20%, second loss closure −15 to −25%. Rodas5's first solve is the same.
- **The structure is unchanged:**
  - every new callback closure recompiles the solver (0.7–0.8 s);
  - every new loss closure recompiles it under ForwardDiff (1.5–1.6 s; `Tag{typeof(loss)}`);
  - a new state type costs 1.6 s;
  - none of it is recompilation of invalidated code, all is fresh compilation.
- **These are the numbers TraitDifferentialEquations has to beat.**
- `ttfs_detail.jl` reads 5–15% above `ttfs_baseline.jl` for the same steps (`@timed` and the measurement order). Compare like with like.
- The Float32 solve prints SciML's `dt_epsilon` warning on both versions.

## 5. Errors (`errors/sciml_errors.jl`, `sciml_errors_implicit.jl`, run in place with `--project=solvers/env`; outputs moved out of the repository)

| case | 1.12.2 recorded: lines, bytes (REPL / full), frames, longest line | 1.13.2 |
|---|---|---|
| SciML, parameters never passed | 71, 5,602 / 10,583, 29, 3,789 | **72, 5,416 / 10,397, 30 (28 by the script's regex), 3,790** |
| SciML, `Float64` cache under `ForwardDiff.gradient` | 101, 6,559 / 13,811, 44, 5,574 | **104, 6,473 / 13,725, 44, 5,575** |
| SciML, the same cache under `Rodas5()` | 81, 4,704 / 89,627, 22, 33,673 | **81, 4,614 / 89,537, 22, 33,673** |
| `typeof(integrator)`, Tsit5 | 3,553 chars, 75 lists | 3,553, 75 |

- **The messages are the same size.** 1.13 changes only the display of repeated frames. 1.12 printed `[15] __init (repeats 2 times)`; 1.13 draws a box around frame 15 with "repeated 2 times" and numbers both frames. That adds a line per repeat group and numbers 30 frames where 1.12 numbered 29.
- **The scripts' frame regex misses the boxed lines,** hence "28".
- **Bytes are about 90–290 fewer** because of shorter `Base` paths and line numbers.
- **The 1.12.2 control,** run from a scratch copy with longer paths, agrees after path normalization.

## 6. What 1.13 changed (observed here)

- **Precompilation:** cold, in fresh depots, 4 tasks, `Pkg.precompile()` (excluding the standard-library pre-step a fresh depot needs, which took 74 s on 1.12):

  | set | 1.12.2 | 1.13.2 | load during the run |
  |---|---|---|---|
  | OrdinaryDiffEq stack, 139 packages | 197 s | **164 s (−17%)** | 2.2–6.0 |
  | interfaces env (Makie, CSV, DataFrames, trait stack), 312–314 packages | 555 s | **409 s (−26%)** | 3.1–6.0 |

  - **The quieter morning run agrees:** in `~/.julia`, 1.13.2's OrdinaryDiffEq precompile took 121 s for 131 packages. 1.12.2 took 158 s for 139 packages in a cold depot, partly in the TraitWorld-test window.
  - **Slowest packages on 1.13:** Makie 104 s, MakiePlots 34 s (README for 1.12: 80–120 s), DataFrames 33 s, CairoMakie 29 s, CSV 27 s.
  - **Size:** compiled output is about the same, 313 MB vs 314 MB for SciML and 741 MB vs 771 MB for interfaces.
  - **Two Makie warnings:** while precompiling it warns "downloading texture atlas failed, need to re-create from scratch". The sandbox blocks the download, so Makie builds the atlas and caches fonts locally.
- **Load:**
  - `using OrdinaryDiffEq` 1.73–1.77 s vs 1.80–1.84 s on the same machine (−4%). It compiles 0.06 s instead of 0.19 s and collects 0.22–0.26 s instead of 0.41–0.44 s.
  - The trait stack with CSV, DataFrames and MakiePlots loads in 4.3–4.5 s, against 5.4–5.8 s recorded for 1.12. That figure is not a same-day control.
- **GC:**
  - a full GC in a SciML session takes 0.12–0.16 s instead of 0.30–0.40 s;
  - total GC per solver session is 1.06–1.14 s instead of 1.55–1.69 s;
  - allocations during compilation are 20–25% lower.

  This is 1.13's permanently marked image objects.
- **Compilation itself:** 0–20% faster in the SciML steps. Nothing changed structurally: the same things compile per closure and per type.
- **Error messages:** repeated frames are boxed (above).
- **Injection:** works on stock 1.13.2 with the two world settings (`activate_codegen!`, require world), exactly as `runtime.md` §4.1 describes.

## Exact commands

Paths relative to `experiments/` unless absolute. `$S` is a scratch directory. `rep.sh` runs a command N times, niced, appending the load average before each run. Every timing below ran under it with N = 3.

```sh
export JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_OFFLINE=true
# environments (Manifest-v1.13.toml copied from Manifest.toml, then resolved)
cp world/env/Manifest.toml world/env/Manifest-v1.13.toml && julia +1.13.2 --project=world/env -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
#   likewise world/concrete/env, interfaces/env; solvers/env from ~/.julia/environments/v1.12/Manifest.toml
# TraitWorld pinned
git -C ../TraitWorld archive 2830a19 --prefix=TraitWorld-2830a19/ | tar -x -C $S
baseline-1.13/pin_env.sh world/env $S/pinned/world $S/TraitWorld-2830a19      # also world/concrete/env, interfaces/env
#   world scripts copied to $S/pinned/wscripts with env -> $S/pinned/world (bench_m1/m5 start subprocesses in @__DIR__/env)
nice -n 10 julia +1.13.2 --startup-file=no --project=env bench_m1.jl          # bench_m5.jl; defcheck_demo.jl skip|noskip
nice -n 10 julia +1.13.2 --startup-file=no --project=$S/pinned/concrete run.jl
nice -n 10 julia +1.13.2 --startup-file=no -O2 lens/lens_bench.jl
# x12
JULIA_TW_VIEWCACHE_DIR=$S/vc113 julia +1.13.2 --startup-file=no --project=$S/pinned/interfaces interfaces/scripts/x12_viewcache.jl record
JULIA_TW_VIEWCACHE=0 … x12_viewcache.jl lean|before|after                                         # no cache
JULIA_TW_VIEWCACHE_DIR=$S/vc113 … x12_viewcache.jl lean|before|after                               # stock, view cache
JULIA_TW_VIEWCACHE_DIR=$S/vc113 … runtime-injection/exp113/inject113.jl interfaces/scripts/x12_viewcache.jl lean|before|after
# x13
JULIA_TW_VIEWCACHE=0 julia +1.13.2 --startup-file=no --project=$S/pinned/interfaces interfaces/scripts/x13_makie_protected.jl [csvfirst]
JULIA_TW_VIEWCACHE=0 … runtime-injection/exp113/inject113.jl interfaces/scripts/x13_makie_protected.jl [csvfirst]
JULIA_TW_VIEWCACHE=0 JULIA_TW_PROTECT=$(cat baseline-1.13/makie_tree_113.txt) … inject113.jl interfaces/scripts/x13_makie_protected.jl [csvfirst]
# solvers (1.12.2 control: JULIA_DEPOT_PATH=$TMPDIR/depot112 julia +1.12.2 --project=$TMPDIR/solv112 …)
nice -n 10 julia +1.13.2 --startup-file=no --project=solvers/env solvers/ttfs_baseline.jl   # ttfs_repeat.jl, ttfs_detail.jl
# errors (run in errors/, the .txt outputs moved out afterwards)
nice -n 10 julia +1.13.2 --startup-file=no --project=../solvers/env sciml_errors.jl          # sciml_errors_implicit.jl
# cold precompile: a fresh JULIA_DEPOT_PATH whose packages/, registries/, artifacts/ link to ~/.julia
JULIA_DEPOT_PATH=$TMPDIR/cold_X nice -n 10 julia +1.13.2 --project=<env> -e 'using Pkg; @elapsed Pkg.precompile()'
```

## Failed or not done

- **TraitWorld's working tree failed to precompile** at 13:10 (another session's uncommitted state: `UndefVarError: ##R#151 not defined in TraitWorld._PC`, TraitWorld.jl:78). That is why everything uses the 2830a19 snapshot. The repository's `interfaces/env` with its `Manifest-v1.13.toml` points at the live tree, as before.
- **Not done, stopped to free the machine for the main session:**
  - the plain-Julia time to first PNG on 1.13 (x9 `plain` or an equivalent without SnoopCompile; 1.12: 27.4 s);
  - ComboCache end to end on 1.13 (1.12: 0.21–0.24 s after loading);
  - a 1.12.2 control of x12 at TraitWorld 2830a19, which would tell whether the stock `summarize` recompilation (71–74 ms vs 3.3 ms in session 21) comes from 1.13 or from TraitWorld;
  - tracing the 43 ms that a lean 1.13 session recompiles in `summarize` without a cache;
  - the solver baseline's x9-style blame, and juliac/JuliaC.jl builds (excluded by the task).
- **The fixed entry cost doubled (110 → about 210 ns) on both versions.** That is a TraitWorld regression to look at, not a 1.13 effect.

## Files

- `baseline-1.13.md` (this file); `baseline-1.13/pin_env.sh`; `baseline-1.13/makie_tree_113.txt` (the `JULIA_TW_PROTECT` list).
- `world/env/Manifest-v1.13.toml`, `world/concrete/env/Manifest-v1.13.toml`, `interfaces/env/Manifest-v1.13.toml`.
- `solvers/env/` (`Project.toml`, `Manifest-v1.13.toml`); `solvers/ttfs_detail.jl`.
- `runtime-injection/exp113/inject113.jl`: the 1.13 injection wrapper for any measurement script.
