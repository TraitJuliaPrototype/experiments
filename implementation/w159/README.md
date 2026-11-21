# W-159: the short round, prepared

Stage 7 of [the next iteration](../../../writeup/plans/2026-11-15-next-iteration.md) (§3, §4): a freeze, then only the rows a change claims to move, each against plain Julia (vanilla v1.13.2, or plain code on the same build), with the tag `prototype-2026-11` as the regression control. This directory holds the drivers of that round. **Nothing here has been run as a measurement:** the logs in `logs/` are smoke runs (one cell each) that show a driver starts, fails loudly on a stale image, and writes its log. The registry rows are written in the design repository before the round runs.

## How to run

```sh
# once, after the freeze (W-158 merged, julia-next rebuilt with BUILD EXIT 0, a freeze tag):
bash trees.sh                       # the tag's worktrees that do not exist yet: wt/w159-tag/{TraitTables,TraitCSV,TraitReport,forks}
bash prepare.sh H; bash prepare.sh B; bash prepare.sh V     # every image each setting needs, into the setting's depot
# the round, one row after another, one Julia job at a time:
ALLOW_BINARY_MISMATCH=B bash run_round.sh <label>            # or: bash run_round.sh <label> g2_calls g4_plain …
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
