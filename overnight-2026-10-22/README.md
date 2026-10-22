# The night of 2026-10-22/23: the W-41/W-43 build, the checks, W-39's measurements

`tonight.sh` runs, alone on the machine, one step after another:

1. the full Julia build of julia-1.13 fa4e7f5798 (W-41: concrete and semi-concrete evaluation from plain code into facts code; W-43: union splitting in tuple arguments by Julia's cost), through `julia-1.13/tw-build.sh` (niced, `-j4`, memory guard);
2. the facts system image (`experiments/factscompiler/scripts/build_facts_sysimage.sh`);
3. every suite and check (`experiments/checks/run_all.sh w41-w43`), with the acceptance suite's new G1.30 (a plain caller concretely evaluates a facts callee) and G1.31 (tuple-argument unions by Julia's cost);
4. W-39's measurements, E-162–E-164 (`experiments/overnight-2026-10-21/run.sh`), on the new build.

A failed build, facts image, TraitWorld suite or acceptance suite stops the night before step 4.

## How to run

From a terminal outside Claude Code's sandbox (a job started from the sandboxed Bash tool dies when the command returns):

```sh
cd ~/Repos/julia-trait-bound/experiments/overnight-2026-10-22
setsid nohup bash tonight.sh > logs/nohup.log 2>&1 < /dev/null &
```

Then check `logs/driver.log`: a line per step, with the time and the load. Do not start other Julia jobs while it runs.

## Runs

| Date | Outcome |
|---|---|
| | |
