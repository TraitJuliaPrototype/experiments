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
| 2026-10-27 07:32–08:47 | Run from the session (`run_in_background`) on julia-1.13 0c589fd385 (W-41, W-43, W-52), TraitWorld main aac1694. Precompilation and E-162 done (`logs/driver.log`, `logs/e162-*.txt`; the summarizer fixed for a load label with spaces). Stopped by the session before E-163, to build and test W-40, W-42 and W-44; E-163 and E-164 to run later with `bash run.sh "e163 e164"`. E-162: every digest equal; P4's steady state regressed to 267.7 ms by W-52 (open issue 66). The logs of the failed launch of 2026-10-21 are in `logs-2026-10-21-failed/`. |
| 2026-10-21 21:52 | Not run. Launched from the sandboxed Bash tool; the job died at its first step (`logs/driver.log` holds only the first line; `logs/precompile-upstream.log` is empty). No measurements. |
