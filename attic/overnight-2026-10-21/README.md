# W-39: overnight measurements (E-162–E-164)

The driver `run.sh` runs, one job after another, niced and through the shared lock:

- re-precompiling the NetworkDynamics environments on the new build (julia-1.13 2943086604, TraitWorld f06b82d);
- E-162: the NetworkDynamics workload, settings U, P0, N, P4, I, A0, five runs each, and order B, three runs each;
- E-163: the round of 2026-10-20 again (call benchmarks, the quick subset, the demonstrators' rows via `measure_demos.sh`, the full BaseBenchmarks in both modes and their comparisons);
- E-164: W-16's heterogeneous rows (`experiments/hetero-idiomatic/runall.sh night1`).

The questions and decision criteria are in the registry rows (`writeup/record/experiments.md`, E-162–E-164).

## How to run

Run it from a terminal outside Claude Code's sandbox, on an idle machine:

```sh
cd experiments/overnight-2026-10-21
setsid nohup bash run.sh > logs/nohup.log 2>&1 < /dev/null &
```

Or as a user unit, which also outlives the terminal: `systemd-run --user --unit=w39 bash run.sh`.

A job started from the sandboxed Bash tool does not outlive the command, even with `setsid nohup … &`: the sandbox ends every process it started when the command returns.

`logs/driver.log` gets a line per part, with the time and the load. Part selection: `bash run.sh "e162 e163"`.

## Runs

| Date | Outcome |
|---|---|
| 2026-10-27 09:44–11:24 | `bash run.sh "e163 e164"` from the session (`run_in_background`) on julia-1.13 26a407d988 (W-40, W-42, W-44 added), TraitWorld main bbfc130; load 0.65–1.3, 2.7 during the plain BaseBenchmarks' start. Results below. Two scripts failed and were run again the same day after the round, on the same build: the call benchmark (`factscompiler/step1/callbench.jl` still used the removed `dynamic_fn`; now `Dynamic{Callable{…}}`) and TraitDifferentialEquations' run-time rows (`measure_demos.sh` ran `scripts/runtime.jl` without OrdinaryDiffEq on the load path, as in the round of 2026-10-20; now the script's own load path). Python's environment for TraitReport (`/tmp/claude-1000/pyenv`) no longer exists: not run. |
| 2026-10-27 07:32–08:47 | Run from the session (`run_in_background`) on julia-1.13 0c589fd385 (W-41, W-43, W-52), TraitWorld main aac1694. Precompilation and E-162 done (`logs/driver.log`, `logs/e162-*.txt`; the summarizer fixed for a load label with spaces). Stopped by the session before E-163, to build and test W-40, W-42 and W-44; E-163 and E-164 to run later with `bash run.sh "e163 e164"`. E-162: every digest equal; P4's steady state regressed to 267.7 ms by W-52 (open issue 66). The logs of the failed launch of 2026-10-21 are in `logs-2026-10-21-failed/`. |
| 2026-10-21 21:52 | Not run. Launched from the sandboxed Bash tool; the job died at its first step (`logs/driver.log` holds only the first line; `logs/precompile-upstream.log` is empty). No measurements. |

## Results of E-163 (2026-10-27)

julia-1.13 26a407d988, TraitWorld main bbfc130, strict mode off. The round of 2026-10-20 (julia-1.13 3b8085c222, TraitWorld bed3782) is the comparison; its logs are in `../factscompiler/round/logs/`. The driver sets `OPENBLAS_NUM_THREADS=1`: BaseBenchmarks' `micro/randmatmul` is 5.1× slower than in the round in both modes for that reason alone (a 1000×1000 product: 6.1 ms with 8 BLAS threads, 30.5 ms with one).

**BaseBenchmarks, full** (4,342 benchmarks, one run each; `logs/compare-*.log`):

| Comparison | Geometric mean | Notes |
|---|---|---|
| `all` against plain, this build | 1.030 | the round: 1.037. Tails as in the round: `filter!` on `Vector{Any}` 26.9×, `Dict{Any}`/`IdDict{Any}` iteration 16–17×, `sumrange_view` 9.8×, reverse `issorted` 8.7–9.2× |
| plain, this build against the round's plain | 1.004 | |
| `all`, this build against the round's `all` | 0.998 | |

**The quick subset** (148 benchmarks): `all` against plain 1.641 (the round 1.710) (`logs/quick.log`).

**Calls** (`logs/callbench.log`, `logs/untyped-*.log`, `logs/sites-*.log`):

| What | This build | The round |
|---|---|---|
| a typed trait call (product / `all`) | 0.8 / 0.8 ns | 0.8 / 0.8 |
| an untyped trait call, an argument from a `Vector{Any}` (product / `all`) | 59.9 / 106.2 ns, 80 B | 28.8 / 30.8 ns, 16 B (then through the table of declared implementations) |
| the same in plain code (product / `all`) | 17.6 / 19.6 ns | 18.9 / 17.6 |
| a `Callable` in `DynamicCall` mode; with worlds alternating | 3.68; 4.09 ns | 3.95; 4.46 |
| a direct call; a dynamic call at `Any` | 0.87; 21.9 ns | 0.87; 20.3 |
| dynamic call sites in plain code, plain / `all`: monomorphic, 4 types asserted, 4 types untyped, `push!(::Vector{Any}, x)` | 14.0 / 14.6, 17.7 / 17.4, 35.3 / 34.0, 1.6 / 13.8 ns | 14.2 / 14.2, 17.5 / 17.2, 34.7 / 34.8, 1.6 / 13.6 |

**The control** (`logs/demos/control.log`): as in the round. Plain: PlainTables loses 14 of 212, upstream CSV+DataFrames 562 of 4,694 (work 3,251 ms first, 3,973 ms after the loads). `all`: PlainTables 0 of 200 (28.8 ms after the loads); upstream 2 of 3,337 (502 ms first, 431 ms after the loads).

**TraitDifferentialEquations' rows** (`logs/demos/tde-rows.log`; ms, the garbage collector's time subtracted; 2 runs per order; E-146 on TraitWorld 226db6a in brackets):

| Row | No loads | Loads before | Loads after |
|---|---|---|---|
| `using` | 0.52–0.54 s | 0.69 s (7.3 s in run 1) | 0.52 s |
| first Tsit5 solve | 16.1–16.6 (25–26) | 29.6–31.3 (25–26) | 16.1–16.2 (24–26) |
| a second model function | 16.7–17.1 (19–21) | 17.5–18.9 (19) | 35.4–37.0 (23–25) |
| a new problem type: `@implement` / first solve | 123–125 / 324–336 (66 / 340–371) | 130–165 / 334–335 (69–70 / 335–338) | 129–130 / 326–330 (70–74 / 338–350) |
| first Rodas5 solve | 25.2–25.3 (27–28) | 31.3–31.8 (30–32) | 30.4–30.7 (29–32) |
| a new callback closure / a second | 23.8–24.0 / 30.1–30.8 (21 / 9–10) | 24.3–24.7 / 31.6–32.3 (21–23 / 10) | 24.2–24.3 / 30.5–31.7 (22–23 / 10–11) |
| first gradient / second loss / third loss | 80.5–80.9 / 49.4–49.9 / 94.0–95.7 (68–70 / 45–48 / 89–94) | 94.1–95.6 / 48.9–50.3 / 95.1–98.1 (82–89 / 44–48 / 97) | 92.4 / 48.5–48.7 / 94.3–95.8 (85–88 / 41–43 / 91–92) |
| ForwardDiff's own tag | 773–795 (671–678) | 792–810 (696–703) | 785–786 (686–689) |
| a `Float32` state, first solve | 594–598 (439–441) | 602–610 (446–448) | 593 (449–461) |

**TraitDifferentialEquations, run time per step** (`logs/demos/tde-runtime.log`, rerun): Lorenz (n = 3) plain function 190 ns, problem type 169 ns, OrdinaryDiffEq 336 ns; a diffusion chain (n = 1,000) 7.86 / 7.82 / 6.15 µs.

**TraitMakie's rows** (`logs/demos/makie-rows.log`; ms; each row inside `@elapsed`, so without the call's own compilation, the garbage collector included; 2 runs per order; the round's rerun in brackets):

| Row | No loads | Loads before | Loads after |
|---|---|---|---|
| `using TraitMakie` | 516–521 (486–491) | 606–619 (559–573) | 518–521 (496–509) |
| first PNG | 21.1–21.2 (20.0–20.7) | 21.3–22.0 (20.4–21.2) | 20.8–21.6 (20.8–21.3) |
| a new data type (forwarding): `@implement` / first PNG | 47 / 109–110 (22 / 72–74) | 67 / 76–78 (45–47 / 81–84) | 66 / 78–79 (39–40 / 73–76) |
| a new colour type: `@implement` / first PNG | 46–47 / 76–77 (48 / 57) | 47–48 / 89–90 (88–89 / 55–58) | 47–48 / 78–80 (51 / 57–59) |
| render / to a vector / to `:purple` / to a gradient | 8.7–8.9 / 79–80 / 8.8–9.0 / 19.8–19.9 (8.8 / 81 / 8.6 / 17) | 8.7–9.2 / 80–82 / 8.8–9.0 / 186–188 (8.5–8.8 / 82–85 / 8.7–8.8 / 16) | 8.7–8.8 / 162–166 / 8.7–8.8 / 20.1–20.2 (8.5–8.8 / 81–82 / 8.5–8.9 / 16) |

**TraitReport** (`logs/demos/report-*.log`; 3 runs): form (t) wall 0.834–0.861 s (imports 0.564–0.572, plot + PNG 96–98 ms); form (pt) 0.740–0.757 s; the round: 0.794–0.805 and 0.771–0.775 s. Under loads, the trait module's work: 40.6 ms (none), 41.2 (REPL), 400 (OffsetArrays, StatsBase, Unitful), 343 (four packages), 333 (all nine); its plain twin's 242, 237, 2,507, 2,528, 2,991 ms. As in the round.

**The forks: not measured.** The forked CSV fails to precompile on TraitWorld bbfc130: its column family's member check refuses `Vector{Int64}` as a member of `Tables.ColumnCore.Column` (`levelcode` and `level` always throw there, so they are fallbacks, not implementations). The session then loads CSV without its image (imports 16 s); its times are not comparable. The forks are paused ([todo W-14](../../writeup/record/todo.md)).

