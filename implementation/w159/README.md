# W-159: the short round

Stage 7 of [the next iteration](../../../writeup/plans/2026-11-15-next-iteration.md) (§3, §4): a freeze, then only the rows a change claims to move, each against plain Julia (vanilla v1.13.2, or plain code on the same build), with the tag `prototype-2026-11` as the regression control. This directory holds the drivers of that round and its logs. **The round ran on 2026-11-22 at the freeze `round-2026-11-c`:** its results are [the round of 2026-11-22](#the-round-of-2026-11-22) below. The logs named `*-smoke*` are the smoke runs of the preparation (one cell each, not results). The registry rows (E-511 to E-528) are in the design repository.

## How to run

```sh
# once, after the freeze (W-158 merged, julia-next rebuilt with BUILD EXIT 0, a freeze tag):
bash trees.sh                       # the tag's worktrees that do not exist yet: wt/w159-tag/{TraitTables,TraitCSV,TraitReport,forks}
bash facts_head.sh                  # the head's copies of W-134's packages compiled by facts (the head's options)
bash prepare.sh H; bash prepare.sh B; bash prepare.sh V     # every image each setting needs, into the setting's depot
# the round, one row after another, one Julia job at a time:
bash run_round.sh <label>            # or: bash run_round.sh <label> g2_calls g4_plain …  (ALLOW_BINARY_MISMATCH=B only
                                     # for a tag's binary built from another commit: not needed since its rebuild)
# open issue 225, apart (a bisection of Julia builds):
bash rows/oi225.sh setup; bash rows/oi225.sh step 9b6dacf5c5; …   # or: bash rows/oi225.sh run
```

- **Settings** (`lib.sh`): `H` the head (default `julia-next`, `TraitWorld`, the demonstrators' trees), `B` the tag (`julia-unified`, `TraitWorld-base`, `wt/w161-tde-base`, `wt/w160-tm`, `wt/w151-base/NetworkDynamics`, `wt/w159-tag/*`), `V` vanilla (`julia-vanilla`, no trait tree). Every tree is a variable (`H_JULIA`, `H_TW`, `H_TDE`, `H_TM`, `H_TT`, `H_TC`, `H_TR`, `H_FORKS`, `H_ND`; `B_…`; `V_JULIA`).
- **Environments:** the harnesses' own (W-134's `env_up`, `env_facts`, `env_forks`, `env_lib`, `env_demo`; ndport's `env_unified_r5`, `env_unified`), copied per setting with the trees replaced (`mkenv.py`, into `envs/<S>/`, ignored by git). The head's and the tag's trees declare the same dependencies, so one manifest serves both; a missing tree is an error.
- **Depots:** `.julia-depot/agent-depots/w159/<S>` stacked before the shared depot: compiled caches are written per setting.
- **Every driver** (`rows/`): checks that the binary names its tree's HEAD and that no tree holds uncommitted changes; checks that every package a cell loads has a valid image (`preflight`, `Base.isprecompiled`); fails the row on "Precompiling" in a cell's output; one fresh process per cell, niced, one thread; `/proc/loadavg` before and after each cell and the row; every tree's commit in the log's header.

## The rows and their drivers

| Row | Driver | The harness it calls | Settings | Minutes |
|---|---|---|---|---|
| G-1 E-392 (E-376): nine unrelated loads | `rows/g1_loads.sh` | `w134/lost.jl` | H, B (env_up: the plain baseline) | 7 |
| G-1 E-391 (E-379's rows): an edit at the prompt | `rows/g1_edit.sh` | `w134/repl.jl` | H, B (Tp: the plain twin) | 5 |
| G-2 E-374: a call through a trait | `rows/g2_calls.sh` | `calls_head.jl` (H), `w145/calls/calls.jl` (B) | H, B (the plain twin in-process) | 3 |
| G-2 NetworkDynamics' workload | `rows/g2_nd.sh` | `ndport/scripts/workload.jl` | H, B; V upstream with `UPSTREAM=1` | 5 (8) |
| G-4 E-381: plain code's session | `rows/g4_plain.sh` | `w134/plain.jl` | V, H, B | 4 |
| G-4 E-382: a port's load, strict mode at a load | `rows/g4_loads.sh` | `w145/loads/load.jl` | H, B, V | 6 |
| G-4 an image's size and build time | `rows/g4_images.sh` | `image_build.jl` (new) | H, B | 8 |
| G-5 E-385: the fifteen mistakes, SciML's three cases | `rows/g5_messages.sh` | `w136/cases`, `w136/sciml/port.jl`, `w161/d4/summarize.py` | H, B, V | 6 |
| G-6 E-383 (and E-387's build) | `rows/g6_builds.sh` | `w166/build_c.sh`, `w135/summarize.py` | H (the tag's counts are E-509's) | 12 * |
| G-6 E-384: small programs, the check against the build | `rows/g6_small.sh` | `w139/apps`, `w166/build_app.sh` | H | 8 * |
| G-6 E-387's session, open issue 228's case | `rows/g6_sessions.sh` | `w120/session_marks.jl`, `w135/apps` | H, B (ode-plain: PlainODE, the baseline) | 3 |
| G-7 the annotations per port | `rows/g7_annotations.sh` | `w156/counts.sh`, `w151/count/annotations.jl` | git: the tag, `unified` | <1 |
| G-7 E-373: the suites (a gate) | `rows/g7_suites.sh` | `w156/suites.sh`, `w161/suites.sh nd` | H (julia-next only) | 25 * |
| open issue 228: the image at load | `rows/oi228.sh` | `w161/d2/image_instances.jl`, `rodas_image.jl` | H, B | 1 |
| open issue 225: plain code's first work bisected | `rows/oi225.sh` | `w134/plain.jl` | each commit's build, B, V | 3–9 builds × ~20 |

Rows marked * are over about ten minutes. The smaller vehicles:
- `g6_builds`: `APPS="table ode"` (the program that built and the one open issue 184 is about), about 5 minutes; the plot's and the report's counts are a hole of Base (E-509) that the freeze does not touch.
- `g6_small`: `APPS="typed_trait vector_trait dynamic_trait ft_union ft_plain_hole"`, about 3 minutes.
- `g7_suites`: if the freeze is the commit W-158's merge gate ran on, its summary stands for E-373; else `g7_suites.sh <label> tables csv tde makie digests`, about 10 minutes.

## The harnesses against the playbook's traps

"Caught" means the harness, run as it is for this round, would fall into the trap; the fix is the driver's unless a file is named.

| Harness | Trap | Verdict | The fix |
|---|---|---|---|
| every W-134 script, `w145/loads/run.sh`, `w136/run.sh`, `w120/sessions.sh`, `w104/suites.sh`, `w142/agree.sh`, ndport's `u_workload.sh` | a depot shared between settings | caught: they source `env.sh`, the shared depot, for the head and the tag alike (`w134/run.sh` 4; `plain.sh` 4) | a depot per setting (`lib.sh` `jl`) |
| `w161/d4/plain.sh`, `w160/nd/run.sh`, `w160/calls/run.sh` | a depot shared between settings | caught: one depot for the head, the tag and vanilla (`w161/env.sh` 5; `w160/nd/run.sh` 14) | the same |
| W-134's environments, `w145/loads/run.sh`, `w136/run.sh` | a working tree shared, one that moves | caught: every manifest names `../../../../TraitWorld`, the tree another agent changes (on branch `w158` today) | `mkenv.py`: the setting's trees, a missing one an error |
| `w161/d2/env_base_demo` (E-501's tag) | settings that differ in several things | caught: the tag's library with the head's TraitTables, TraitCSV, TraitMakie (Manifest lines 1725, 1749, 1767) | the tag's own worktrees (`trees.sh`) |
| every harness of the round | an image that is stale | caught: none fails on "Precompiling" (`u_workload.sh` and `w160/nd/run.sh` write a NOTE and go on; `build_c.sh` prints "from source" and goes on) | `preflight` before the cells; a cell that precompiles fails the row; `g6_builds.sh` notes a build that loaded from source |
| the tag's binary | the binary names another commit | **caught**: `julia-unified/julia` names `8fccf1e182*`, its tree is at `7b374f39ce`: it was built (21:41) before the commit (22:08) that added 27 lines to `Compiler/src/bootstrap.jl`; vanilla's and `wt/w158-julia`'s binaries are marked `*` with their trees clean | `check` refuses it unless `ALLOW_BINARY_MISMATCH=B`; the log says so. The main session decides (below) |
| `w134/plain.jl`, `repl.jl`, `lost_demo.jl`, `w120/session_marks.jl`, ndport's `workload.jl` | a timer that reads zero | clear: `cumulative_compile_timing(true)` (plain.jl 13; repl.jl 67; lost_demo.jl 45; session_marks.jl 10; workload.jl 79) | — |
| `w145/loads/load.jl` | a count that reads zero | clear since E-382's correction (it counts the log's MethodInstances); on the head a membership's invalidation is a method's, logged the same way: to be read on the first run | — |
| `w134/lost.jl` 44, `demo_session.jl` 38, 47, `repl.jl` 94, 104, ndport's `workload_steps.jl` 40, 85 | a digest made with `hash` | clear: each hashes a printed `String`, numbers, or tuples of `Int` (`(src(e), dst(e))`); `hash(typeof(nw))` (workload_steps.jl 154) is printed on an `N` line that `compare_digests.py` does not compare | — |
| `w136/run.sh`, `w136/sciml/report.jl` 19 | state carried between runs | caught: the outputs go into the harness's own committed `logs/`, and `summarize.py` reads every `*.out` there, a filtered run's with an older run's | `g5_messages.sh` writes per label and setting; `report.jl` takes `W136_LOGS` (the default unchanged) |
| `w134/lost.jl`, `plain.jl`, `w145/calls/calls.jl` | state carried between runs | clear: a fresh process per cell; `calls.jl`'s sink only accumulates; its answers asserted equal | — |
| `image_build.jl` (new) | a cache measured on the session that recorded it | clear: each image written anew into a scratch depot, removed after | — |
| ndport's workload, its upstream run | a check without a control; settings that differ in several things | caught: upstream on vanilla runs SciML's solvers, the port TraitDifferentialEquations | `g2_nd.sh`: the tag is the control and the digests are compared; upstream's numbers are stated beside, not as a baseline |
| `w156/counts.sh` | a criterion that cannot be decided | caught: on the head it counts the library's wrapper `compiled_for(` as a cast (it looks for `ByType: compiled_for`, gone with traits T-126) | `counts.sh` takes `WRAPPER=all` (the default unchanged) |
| `w160/calls/calls.jl` | runs on the head | **no**: `using TraitWorld.ByType` (gone) and `@trait_module first_seen = false` (an error now) | `calls_head.jl`: the two lines changed; smoke-run on the head |
| `w145/loads/run.sh`'s `makie` row | runs on the tag | no: `--project=TraitMakie`; the tag's tree `wt/w160-tm` has a manifest that names `../TraitWorld-unified` | `g4_loads.sh` loads TraitMakie from `env_demo` |
| `w166/build_c.sh`, `build_app.sh`, `w139/build.sh` | logs and binaries into the harness's directory; the shared depot | caught for the round | `build_c.sh` and `build_app.sh` take `LOGDIR`, `OUTDIR` (and `build_app.sh` `DEPOT`); defaults unchanged |
| every harness's header | "a number says what it measures" (rule 5) | partly: no load after the run (W-134's), no strict mode or setting named, the tag's trees named by the head's paths | `header` and `footer`: every tree's commit and `*`, the depot, product setting, strict mode off, one thread, load before and after each cell |

**The baselines.** Plain Julia per row: the plain twin in the same process (calls), plain code on the build (`env_up`; the twins PlainTables, PlainODE, PlainPlots), vanilla (plain code's session, the plain mistakes, upstream's load). Two rows have none that runs the same code: NetworkDynamics' workload (upstream's on vanilla is another solver stack) and the suites (a gate). The annotations are a count.

## Smoke runs (2026-11-21; not results)

Head: `wt/w158-julia` (`w158` 8b35e4b77c) with `wt/w158b-tw` (TraitWorld 81c04c3); the tag: `julia-unified` with `TraitWorld-base`. Load 4.7 to 7.8 of 128.

| Log | What it shows |
|---|---|
| `logs/g7-annotations-smoke.log` | the annotations at the tag and at `unified` (git only); before `WRAPPER=all` the head's wrappers counted as casts |
| `logs/g2-calls-smoke-stale.log` | the head without the library's image: the row stops at its preflight, "STALE OR MISSING IMAGE: TraitWorld" |
| `logs/prepare-H-smoke.log` | `prepare.sh H tw`: TraitWorld's image for the head, 7 s |
| `logs/g2-calls-smoke.log`, `g2-calls-smoke-B.log` | `calls_head.jl` on the head, `calls.jl` on the tag, at 10^6 calls: every row runs |
| `logs/g1-loads-smoke-B.log` | `lost.jl` order A in `env_up` on the tag: 424 of 4,693 own image instances lost, as E-392 |
| `logs/g5-messages-smoke.log`, `logs/g5-smoke/` | case 03b on the head (`MethodError`, 11 lines), the tag (`OperationError`, 3 lines), vanilla and the head's plain build (6 lines) |
| `logs/prepare-B-smoke.log`, `logs/oi228-smoke-B.log` | the tag's ODE port image written (26 s); its image holds 353 instances, two of `_rodas5_run`. The tag's demonstrator trees did not exist: the smoke named the head's TraitTables, TraitCSV, TraitReport for the environment only (`B_TT=TraitTables …`; not loaded) |

## Not verified

- Every row on the head after the merge: the drivers ran on `wt/w158-julia`, not on the rebuilt `julia-next`.
- `repl.jl`'s and `lost_demo.jl`'s calls into the head's demonstrators (TraitTables' `summary_text`, `floats`, TraitMakie's `hist`): read, not run; their images for the head were not written (CairoMakie's stack, several minutes).
- NetworkDynamics' workload on the head with the head's TraitMakie (E-438 used the tag's TraitMakie on both); the workload's scripts at ndport's head against the tag's NetworkDynamics.
- `g4_images.sh` (`Base.compilecache` into a scratch depot), `g6_builds.sh`'s comparison of the binary with the session, `g6_small.sh`, `g7_suites.sh`, `oi225.sh`: written, not run.
- Upstream's packages on vanilla for `g2_nd.sh UPSTREAM=1` (`ndport/env_upstream`) and for SciML's upstream case (`w136/sciml/upstream.jl` reads the home depot; not in `g5_messages.sh`).
- `trees.sh` was not run: the demonstrators' repositories were read only.

## The round of 2026-11-22

**The builds.** The head (H): julia `next` cf0f039f51 (`julia-next`, binary cf0f039f51*, tree clean), TraitWorld `unified` 42d60e1, TraitDifferentialEquations 06c28c3, TraitMakie 1888698, TraitTables e1ec1f4, TraitCSV 094dcb2, TraitReport ec34d12, forks a3a37d6, NetworkDynamics c2bbf0d, ndport 4fecc02 (every one at the tag `round-2026-11-c`). The tag (B, the regression control): `julia-unified` 7b374f39ce (its binary names 7b374f39ce* since its rebuild of 2026-11-21: `ALLOW_BINARY_MISMATCH` was not needed), TraitWorld-base e11c7cc, the demonstrators at `prototype-2026-11` (`wt/w161-tde-base` b730628, `wt/w160-tm` c862914, `wt/w151-base/NetworkDynamics` 6310040, `wt/w159-tag/{TraitTables c339175, TraitCSV 92c46d0, TraitReport a4bcf33, forks 439bae7}`). Vanilla (V): `julia-vanilla` v1.13.2 45b6d15e34. Every log's header names each tree's commit, the depot and the load before and after each cell.

**The setting of every row:** product setting, strict mode off (but where a cell says strict), one thread, a fresh process per cell, niced, one Julia job at a time, a depot per setting. The machine: 128 cores, 1-minute load 1.8 to 3.5 throughout (others' jobs; no row waited). Interleaved H, B (and V) per run as each driver does.

**Preparation** (`logs/prepare-*.log`): H 514 s, then `facts` again 178 s (below); B 776 s; V 256 s: 29 minutes in all, every image written into the setting's depot.

**What was changed to run it** (each in the commits of this round):
- `trees.sh` looked for the workspace one directory too far up (its own bug).
- **The head's packages compiled by facts:** `w134/pkgs-facts` carries `@compiler_options … dynamic=false first_seen=true`; both options are gone on the head ("unknown option"). `facts_head.sh` makes `pkgs-facts-head` with the head's one line, `facts=true bounded=false no_pirates=false` (a module that declares only facts; the porting guide 0.1), and `lib.sh` maps the head's `env_facts` to it. The tag keeps `w134/pkgs-facts`. The first `prepare H` failed on it (`logs/prepare-H.log`, lines 216-297); `logs/prepare-H-facts.log` is the run with the fix.
- `g6_builds.sh` builds the ODE program with callbacks (`w158/port/apps/ode_cb.jl`) and the four plain twins (`table-plain`: TABLE_PLAIN=1; `plot-plain`: `plot_plain.jl`; `report-plain`; `ode-plain`). Its first run passed `PKGS` as a word, not a variable: the three new builds did not start (`logs/g6-builds-r1.log`); they ran again as `r1b`.
- `g7_suites.sh` takes `ND=0` (NetworkDynamics' subset was run by the main session on these heads).
- `oi225.sh setup` copied an extracted source directory of `deps/srccache` (patchelf), and the first build stopped after 10 s at the build's `mkdir` (`deps/patchelf.mk:9`, BUILD EXIT 2; the step printed "9b6dacf5c5: build failed"): it copies the downloaded files only.
- New probes (`probes/`): `load_profile.jl` (where a load goes), `defs_timed.jl` (each top-level statement of a program timed, one profiled), `rodas_ci.jl` (open issue 228: code instances of an instance), `lib_ended.jl` (which of the library's instances a load ends, and through what).

### E-515: plain code's session (`logs/g4-plain-r1.log`; a warm-up and 3 runs, interleaved V, H, B; load 2.5–3.5)

Upstream CSV and DataFrames compiled plainly (`w134/plain.jl`). Median (range), n = 3.

| cell | `using CSV, DataFrames` (ms) | first work (s) | repeated, median (ms) | the library's load (ms) | ended by the late load | work after it (ms) |
|---|---|---|---|---|---|---|
| vanilla | 697 (652–1017) | **3.264 (3.252–3.281)** | 0.18 (0.18–0.18) | — | — | — |
| head, no library | 754 (749–1052) | **3.331 (3.316–3.342)** | 0.19 (0.18–0.19) | — | — | — |
| tag, no library | 758 (757–968) | 2.889 (2.885–2.893) | 0.19 (0.19–0.19) | — | — | — |
| head, the library first | 1076 (1073–1087) | 3.294 (3.287–3.298) | 0.18 (0.17–0.19) | 58 (58–80) | — | — |
| tag, the library first | 793 (785–794) | 2.958 (2.951–2.965) | 0.19 (0.18–0.20) | 62 (61–74) | — | — |
| head, the library late | 750 (749–752) | 3.334 (3.321–3.335) | 0.19 (0.18–0.19) | **168 (168–170)** | **0 of 120,780** | 1.05 (1.05–1.08) |
| tag, the library late | 758 (757–781) | 2.899 (2.885–2.900) | 0.19 (0.19–0.19) | 41 (41–41) | 209 of 120,566 (Base 94, DataFrames 80, Statistics 30) | 259 (258–262) |

- The criterion: the head's first work is above vanilla's range of the same hour (3.32–3.34 against 3.25–3.28 s), by 0.04 to 0.09 s: not within it, and not above it by more than 0.1 s. By the brief, open issue 225's first step was run (below).
- The tag's first work is 0.37 s below vanilla's, the head's 0.07 s above: the head is 0.44 s slower than the tag (open issue 225's question).
- The library loaded late ends no plain instance on the head (209 at the tag); its load takes 168 ms there against 58 ms loaded first (E-499 on `next` 5448a8b7bf: 35–49 ms late). Not profiled.

### E-511: nine unrelated loads (`logs/g1-loads-r1.log`; a warm-up and 2 processes per cell, H and B interleaved; load 2.6–3.1)

`w134/lost.jl`, order A (the work, the loads, the work again) and B (the loads, then the work). Own image instances of the eight packages lost, and the times, median (range), n = 2. The digest `ce94074fa1261ca2` is equal after the loads in every cell.

| environment | setting | first work (s) | work after the loads (s) | order B: the work after the loads (s) | own image instances lost |
|---|---|---|---|---|---|
| upstream, plainly (the baseline) | H | 4.46 (4.45–4.46) | 5.25 (5.19–5.32) | 6.21 (6.19–6.22) | 426 of 4,688 (9.1 %) |
| | B | 4.16 (4.15–4.16) | 5.13 (5.13–5.13) | 5.74 (5.73–5.74) | 424 of 4,693 (9.0 %) |
| upstream by facts, one line per module | H | 1.79 (1.75–1.83) | **1.46 (1.45–1.46)** | 2.47 (2.46–2.48) | **14 of 3,490 (0.4 %)**: DataFrames 10, CSV 4 |
| | B | 1.91 (1.90–1.91) | 1.73 (1.73–1.73) | 2.50 (2.41–2.60) | 14 of 3,490 (0.4 %) |
| the forks | H | 0.19 (0.19–0.19) | **2.27 (2.19–2.34)** | 2.43 (2.41–2.46) | **150 of 5,705 (2.6 %)**, facts 149 of 4,303: CSV 137, DataFrames 12, PooledArrays 1 |
| | B | 0.19 (0.19–0.19) | 2.23 (2.23–2.24) | 2.33 (2.33–2.33) | 48 of 4,799 (1.0 %), facts 47: CSV 35, DataFrames 12, PooledArrays 1 |

- By facts: 0.4 % lost (criterion 1 %), and the work after the loads 1.46 s against plain's 5.25 s: G-1's standing holds.
- The forks: the work after the loads is 12 times their first work (GT-8's line: twice): GT-8 stands. Against the tag they lose three times as many own instances (CSV 137 against 35), of more instances in the image (5,705 against 4,799); the times are the same within the spread. Among all packages loaded for the work the head also loses 16 of TraitWorld's own instances (0 at the tag).
- Plain code's first work is 0.30 s slower on the head than at the tag (4.46 against 4.16 s), as in E-515.

### E-512: at a demonstrator's prompt (`logs/g1-edit-r1.log`; a warm-up and 2 processes per kind; load 2.4–2.9)

`w134/repl.jl`. Median of 2 (the two runs within 1 % but where a range is given).

| kind, step | head: first (ms) | head: defining (ms) | head: ended | tag: first | tag: defining | tag: ended |
|---|---|---|---|---|---|---|
| table, a new cell type (Int32) | 522.8 | 0.0 | 0 | 508.8 | 0.0 | 0 |
| table, a new column struct | 145.3 | 65.8 | 0 | 144.3 | 32.6 | 0 |
| table, an edit of `summarize` | 101.5 | **234.7** | 0 | 108.9 | 689.2 (686.6–691.8) | 0 |
| table, the same edit again | 102.5 | **9.3** | 0 | 112.3 | 510.6 (509.0–512.2) | 0 |
| plain twin (Tp), a new cell type | 534.5 | 0.0 | 0 | 530.1 | 0.0 | 0 |
| plain twin, a new column struct | 144.1 | 4.8 | 0 | 156.1 | 5.0 | 0 |
| plain twin, the edit of `summarize` | 156.6 | 70.5 | 6 | 129.0 | 73.5 | 5 |
| plain twin, the same edit again | 157.2 | 6.7 | 4 | 120.0 | 7.8 | 3 |
| ODE, a new closure (the RHS) | 54.3 | 0.0 | 0 | 56.8 | 0.0 | 0 |
| ODE, a new parameter struct | 293.3 | 4.8 | 0 | 203.7 | 5.0 | 0 |
| ODE, an edit of `save_step!` | 314.6 | 82.2 | 126 | 336.2 (333.8–338.7) | 105.8 | 86 |
| ODE, the same edit again | 307.2 | 12.8 | 40 | 344.4 (339.9–348.8) | 13.2 | 22 |
| ODE, an edit of `initdt` | 281.5 | 18.0 | 22 | 347.5 | 21.6 | 19 |

- A new type, struct or closure ends no library instance on either build. The digests are equal after each edit.
- GT-12: the first edit's definition takes 0.23 s (criterion: under 0.35 s, "smaller"), the second 9.3 ms against the plain twin's 70.5 ms and 6.7 ms. At the tag 0.69 s and 0.51 s.
- Worse than the tag: a new column struct's definition 65.8 against 32.6 ms; the ODE session's new parameter struct 293 against 204 ms (57 instances compiled against 41); the edit of `save_step!` ends 126 instances against 86.

### E-513: a call through a trait (`logs/g2-calls-r1.log`; 10^7 calls, the minimum of 7, 2 processes each, interleaved)

H runs `calls_head.jl`, B `w145/calls/calls.jl`. ns a call, median of the two processes' minima (range).

| row | form | head | tag |
|---|---|---|---|
| an operation at a known type | trait / plain | 0.79 / 0.79 | 0.79 / 0.79 |
| a method at the trait, known type | trait / plain | 0.79 / 0.79 | 0.79 / 0.79 |
| a trait that erases by default | as it is | 8.66 (8.63–8.68) | 7.88 (7.65–8.10) |
| | `compiled_for` / plain | 2.38 / 2.38 | 2.38 / 2.38 |
| | a box held | 7.15 | — |
| an element of a vector, two types | `Vector{Shape}` | 2.87 (2.86–2.87) | 2.87 (2.86–2.87) |
| | plain: abstract / union / one type | 2.70 / 3.19 / 2.34 | 2.70 / 3.19 / 2.28 |
| a field | `::Dynamic{Shape}` / plain abstract | 5.56 / 0.79 | 5.56 / 0.79 |
| a `Callable` argument | `compiled_for(f)` | 0.79 | 1.34 |
| | the default (boxed) / a box held | 25.25 (25.19–25.31) / 25.25 | — |
| | the tag's `with_dynamic(f)` | — | 328.8 (323.2–334.4) |
| | plain | 0.79 | 0.79 |

- Where the type is known, no row is slower than plain (criterion 0.1 ns): G-2's claim holds.
- Against the tag: "as it is" 0.8 ns slower (8.66 against 7.88; the tag's two runs spread 0.45 ns); `compiled_for` of a `Callable` 0.79 against 1.34 ns.

### E-514: NetworkDynamics' workload (`logs/g2-nd-r1.log`, `logs/g2-nd-r1-<S>-<i>.out`; a warm-up and 2 sessions, interleaved)

| setting | session (s) | first pass, summed (s) | `again`, the steady state, summed (ms) | params (ms) | changed (ms) | graphtype (s) |
|---|---|---|---|---|---|---|
| head | 43.6, 44.1 | 20.2, 19.5 | **313, 312** | 519, 506 | 704, 718 | 8.19, 7.94 |
| tag | 44.6, 44.0 | 19.8, 19.8 | 436, 418 | 619, 636 | 834, 766 | 8.39, 8.32 |

- The digests: 32 of 32 equal, H against B, in both pairs of runs.
- The steady state is 0.11 s faster on the head than at the tag, beyond the spread (the tag's runs differ by 18 ms).
- The warm-ups (run 0) overlapped with three short probes of this agent (E-521's decomposition): they are not counted. Upstream on vanilla (`UPSTREAM=1`) was not run: `ndport/env_upstream` has no images in V's depot.

### E-516: a port's load (`logs/g4-loads-r1.log`; a warm-up and 3 runs per row, walk; load 2.6–3.3)

`using`, median (range) in ms; the instances in Julia's invalidation log.

| row | head | tag | log, head | log, tag |
|---|---|---|---|---|
| TraitWorld | 59.6 (58.7–60.5) | 61.6 (60.7–63.6) | 9 | 23 |
| TraitTables with TraitCSV | 153.4 (153.0–153.7) | 174.2 (172.2–175.5) | 9 | 23 |
| the same, strict mode | **215.2 (215.2–216.4)** | 239.6 (238.8–241.2) | 9 | 23 |
| the ODE port | **508.2 (505.9–509.2)** | 300.6 (299.9–301.4) | 643 | 630 |
| TraitMakie | 246.1 (245.3–256.6) | 269.7 (266.6–269.9) | 37 | 51 |
| the forks | 1,195.7 (1,186.4–1,206.1) | 1,146.2 (1,097.4–1,497.7) | 695 | 1,233 |
| upstream by facts | 587.1 (586.8–588.5) | 596.9 (595.9–611.0) | 666 | 1,185 |
| upstream plainly | 749.6 (748.0–751.6) | 764.6 (755.2–771.3) | 940 | 1,458 |
| upstream on vanilla | 654.4 (652.1–660.6) | | 908 | |
| NetworkDynamics | 1,968.4 (1,961.8–2,052.2) | 1,787.2 (1,779.4–1,916.1) | 1,574 | 1,578 |

- GT-2: strict mode adds 62 ms (40 %) to TraitTables with TraitCSV (criterion: under 10 % closes): it stands. At the tag 65 ms (38 %).
- The compiler's instances ended by upstream's load: head 132, tag 615, vanilla 122 (GT-3's count).
- TraitWorld's own instances ended by a port's load: 15 at the ODE port's, the forks' and NetworkDynamics' loads on the head, 0 at the tag. The cause (`probes/lib_ended.jl`, `logs/probe-lib-ended-ode-H.txt`): a method of `promote_rule` added by the port's dependencies ends Base's `string(::Integer)`, `promote(::Int64, ::Integer)` and `sprint(showerror, …)` broadcast over a `Vector{Any}`, which the library's hooks call (`_definition_hook`, `_strict_at_load!`, `_module_end_hook`, `_code_name`, `_written_method`, a `showerror` of `PirateAtLoadError`): they are compiled again in the session, 0.20 to 0.24 s at the ODE port's load.
- The ODE port's load is 0.21 s slower than at the tag. The profile of the load (`logs/probe-load-profile-{H,B}.txt`): on the head the image's restore spends its samples in `jl_memberships_activated`, `jl_membership_dispatch_walk` and the library's `_image_methods_hook`, and a third of the samples are code generation at load (the recompiled hooks); at the tag neither the walk nor the hook appears.
- No load of a package that names no trait ends more than on vanilla but the compiler's 10 (132 against 122) and Base's 22 (505 against 483) at upstream's load.

### E-517: images and the build (`logs/g4-images-r1.log`, `logs/g4-images-r1-buildlogs.txt`; each image written once anew into a scratch depot)

| package | head: seconds | head: .so bytes (.ji) | tag: seconds | tag: .so bytes |
|---|---|---|---|---|
| TraitWorld | 6.21 | 6,883,472 (346,435) | 5.55 | 5,484,920 |
| TraitTables | 1.99 | 1,266,816 (12,537) | 3.69 | 3,963,936 |
| PlainTables (twin) | 1.60 | 1,453,648 (10,229) | 1.69 | 1,481,296 |
| TraitCSV | 8.59 | 14,694,168 (9,377) | 11.29 | 15,170,688 |
| TraitDifferentialEquations | 15.37 | 4,495,400 (12,978) | 27.26 | 9,698,416 |
| PlainODE (twin) | 3.23 | 3,718,056 (34,482) | 3.56 | 3,759,648 |
| TraitMakie | 5.92 | 4,633,152 (116,048) | 5.89 | 4,860,744 |
| PlainPlots (twin) | 2.45 | 2,445,640 (26,020) | 2.63 | 2,478,296 |

- The criterion (a trait package's image larger than its plain twin's): TraitTables no (1.27 against 1.45 MB); the ODE port yes (4.50 against 3.72 MB, +21 %, and 15.4 against 3.2 s); TraitMakie yes (4.63 against 2.45 MB). The twins are smaller programs than the ports (fewer solvers, fewer plot kinds): this is not like for like; E-380's comparison (a member's instances) was not repeated.
- Against the tag: the ODE port's image is half (4.50 against 9.70 MB) and written in 15 s against 27 s; TraitTables' a third.
- The system image: head 212,164,208 bytes, tag 219,567,144, vanilla 194,307,784 (+9.2 %).
- Julia's build (one build each, `-j64`): Base's stage 32.37 s against vanilla's 32.48 s (criterion 10 %: no); the compiler's stage (`basecompiler-o.a` to its link) 387 s against 326 s, +19 %, at a load of 1.5 against vanilla's 8.0; the whole build 829 s against 790 s.

### E-518: the fifteen mistakes and SciML's three cases (`logs/g5-messages-r1.log`, `logs/g5-r1/<S>/summary.md`; one process per case)

- Each trait case reports at the line it reported on `next` 5448a8b7bf (E-498); 03b: `MethodError` with the contract's hint, 11 lines, 752 bytes. Its text is E-498's (`w161/d4/logs/after/`) word for word; the 9 bytes are the path (`experiments/unification` became `experiments/implementation`).
- **Case 05 under strict mode:** `PirateError` at the user's line 13, 3 lines, 486 bytes ("strict mode refuses `uppercasefirst(::String)` … It would win at the call … which code compiled by facts makes"). The tag refuses it too (484 bytes). Without strict mode: the pirate's warning, and the program runs.
- The plain forms on the head's build print what vanilla prints (exception, lines and bytes alike in each of the twelve plain cases).
- No case where plain Julia reports earlier than the trait form.
- SciML's three cases, bytes with types limited as the REPL prints them: the port 2,609; 5,184; 4,886, its plain twin 2,478; 5,564; 4,063. At the tag: 2,298; 4,857; 4,622 and 2,438; 5,504; 4,003.

### E-519: the demonstrators' programs, trimmed (`logs/g6-builds-r1.log`, `logs/g6-builds-r1b.log`, build logs in `logs/g6-r1*/`; one build each, the images written first, `--trim=safe`)

| program | errors | bytes | runs, output equal to a session's |
|---|---|---|---|
| table | 0 | 2,724,576 | yes |
| plot | 0 | 4,951,728 | yes (stdout; the PNGs not compared) |
| report | 0 | 5,393,960 | yes (stdout; the PNGs not compared) |
| ODE | 0 | 4,292,960 | yes |
| ODE with callbacks it knows (`ode_cb`) | 0 | 4,083,552 | yes |
| table's plain twin (PlainTables) | 6 | — | — |
| plot's plain twin (PlainPlots) | 80 | — | — |
| report's plain twin (PlainTables, PlainPlots) | 86 | — | — |
| ODE's plain twin (PlainODE) | 8 | — | — |

Every build loaded its packages from images (`from source: none`). Vanilla's counts are E-383's (table 12, plot 88, report 98). The builds took 5 to 15 s each.

### E-520: the small programs (`logs/g6-small-r1.log`; the smaller vehicle)

Seven programs: `typed_trait`, `typed_plain`, `vector_trait`, `vector_plain`, `dynamic_trait`, `ft_union`, `ft_plain_hole`. The session's `fully_typed` agrees with the build on all seven: six fully typed, build and run with the session's output (2,062,432 to 2,223,416 bytes; `typed_plain` 1,923,592); `vector_plain` has 1 site in the session and 2 errors in the build. The other six programs of the full list were not run.

### E-521 and open issue 228: the table and the ODE sessions (`logs/g6-sessions-r1.log`, traces `logs/g6-sessions-r1-*.trace`; a warm-up and 3 runs, interleaved)

| session | setting | wall (s) | load mark (ms) | first run (ms), of it compiling | the last run's compiles |
|---|---|---|---|---|---|
| table | head | 0.68 (0.67–0.71) | 356 | 54.6, 53.7 | 19, 169 ms |
| | tag | 0.74 (0.74–0.75) | 413 | 60.4, 59.8 | 20, 182 ms |
| ODE | head | **2.71 (2.68–2.72)** | **2,059–2,096** | 347–350, 344–347 | 77, 871 ms (session 306, recompile 236, own image 61, composition 26, Julia 243) |
| | tag | 1.25 (1.25–1.72) | 586–868 | 386–400, 382–396 | 66, 650 ms (session 319, recompile 29, own image 12, composition 31, Julia 259) |
| ODE, plain twin (PlainODE) | head | 0.85 (0.85–0.85) | 207 | 376.5, 373.4 | 48, 550 ms |
| | tag | 0.94 (0.94–0.98) | 219 | 444.5, 441.3 | 49, 630 ms |

- **The ODE session's load mark, decomposed** (`probes/defs_timed.jl`, two runs each, `logs/probe-defs-timed-ode.txt`, `logs/probe-defs-profile-H.txt`): the `using` block 650–654 ms on the head (compiling 319, recompiling 241) against 341–380 ms at the tag (compiling 68, recompiling 0); `include("verify.jl")` 1,350–1,361 ms against 220–222 ms. With `VERIFY=0` the branch is not taken, but Julia compiles the top-level block (it holds a loop) and so infers `TraitWorld.verify_main(main, (Vector{String},); entrypoints = true)` at the session's `main`: the profile is inference under `typeinf_ext_toplevel`. That is the harness's file, not the port's load.
- Open issue 228 (criterion: the first run compiles no instance of TraitRodas or ODECore): not closed. The first run compiles ODECore's `_problem_of` (8.1 ms) and `_problem` (7.5 ms) at the session's types, besides the session's own functions; no TraitRodas instance is compiled on its own (`_rodas5_run` is inferred inside `main`, 201.5 ms).

### E-528: the ODE port's image at load (`logs/oi228-r1.log`, `logs/oi228-r1-{H,B}.txt`, `logs/probe-rodas-ci.txt`)

- The image holds 509 instances with code in TraitDifferentialEquations, ODECore and TraitRodas on the head, 353 at the tag.
- `_rodas5_run` at the session's integrator: on the head a `MethodInstance` with **no code instance** (0, valid or invalidated; `probes/rodas_ci.jl`); at the tag valid code. Not "invalidated at load". A `MethodInstance` without code is serialized when another serialized item names it, so the writing process reached the call; whether it had code there is the next step (the writing process's list), not run.
- In the tag's image and not the head's: the problem's constructors at `Callable{…}` and ODECore's callback records (`FunctionCallback`, `ParamCallback`, …): the port's signatures changed (`ODEFunction` in place of `Function`).

### E-522 and E-526: the annotations per port (`logs/g7-annotations-r1.log`; git at `prototype-2026-11` and at `unified` = `round-2026-11-c`)

| port | casts + module options + wrappers + `@default_dynamic` (choosing), tag → head | boxes | `unwrap` | `@implement Callable` | `@nospecializeinfer` |
|---|---|---|---|---|---|
| TraitTables | 4 → 5 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| TraitCSV | 1 → 1 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| TraitReport | 2 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| TraitMakie | 1 → 1 | 29 → 29 | 0 → 0 | 0 → 0 | 0 → 12 |
| forks | 5 → 6 | 2 → 4 | 10 → 10 | 0 → 0 | 0 → 0 |
| TraitDifferentialEquations | 24 → 30 | 78 → 85 | 7 → 18 | 0 → 19 | 16 → 7 |
| NetworkDynamics (its tool's "choosing") | 3 → 1 | 0 → 0 | 0 → 0 | 0 → 1 | 3 → 3 |

At the tag every `compiled_for(` of `ByType` counts as a cast, on the head as the library's wrapper (`WRAPPER=all`): the column "choosing" adds them. Three ports need more choosing annotations than at the tag (TraitTables +1, the forks +1, the ODE port +6), two fewer (TraitReport −2, NetworkDynamics −2).

### E-523: the suites (`logs/g7-suites-r1.log`; the summaries in `../w156/logs/w159-r1-summary.log`, the logs `../w156/logs/w159-r1-*.log`)

| suite | run by | result |
|---|---|---|
| TraitTables (`Pkg.test`) | this round | 3 testsets, pass |
| TraitCSV | this round | 2 testsets, pass |
| TraitMakie | this round | 8 testsets, exit 0 |
| the forks' session digests against upstream's | this round | equal at 26 steps |
| the forks' Tables suite | this round | 14 of 15 in `ByRow`, 1 error: `ByRow(Dict)`, a type passed as a constructor is no `Callable` member (open issue 240, known since E-504; the forks keep the failing test) |
| the library (118 testsets), the documentation's examples (33, 126, 10), the ODE port (35), NetworkDynamics' six files (the two known failures) | the main session, 2026-11-21 (`../w158/README.md`, session note item 33) | as stated there |

Not run: TraitReport's check and session, TraitMakie's session, the ODE port's session, the forks' CSV (8 minutes) and DataFrames (36 minutes) suites.
