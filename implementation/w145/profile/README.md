# E-388: where a session's time goes, by profile (W-145, part 9)

The question: in each phase of a session, which mechanism takes the time?

## How to run

```
bash run.sh [tag] [table ode forks upstream upstream-vanilla nd]     # -> logs/<session>[-tag].log
python3 summarize.py logs/<session>.log …                            # -> markdown, each phase's time split
julia chain_position.jl                                              # the compiler's CodeInstance chains
```

- `prof.jl <session.jl>` cuts a session file at lines `#@ name` into phases. Each phase is evaluated at top level under Julia's profiler (0.5 ms, C frames), one process, one thread.
- Every sample of the main thread goes to one class: the first class in `CLASSES` (in `prof.jl`) with a function on the stack. So a collection inside inference counts as inference.
- "Compiling while inferring" is code compiled below an inference frame: the compiler's own methods, a generator, a call that inference evaluates.
- The profiler slows a phase 1.5 to 9 times where stacks are deep. `PROF=0` runs the phases without it; `run.sh` does both after a warm-up. `summarize.py` applies the shares to the unprofiled times.
- `sessions/`: the table report with an edit, the ODE session, the frames session (the forks' and upstream's CSV and DataFrames), NetworkDynamics' workload as one phase.
- `chains.jl`, `chain_position.jl`: the length of the chains the runtime walks at an `invoke`, and the position of the code that runs.

## Results, 2026-11-14

`unified` 21c9b33e39 (binary 86deee2f98*), TraitWorld 2072e75, tag `round-2026-11-b`; vanilla 45b6d15e34; product setting, strict mode off, one thread; one profiled run after a warm-up and an unprofiled run; load 0.3 to 1.3 of 128. The table: [`logs/summary.md`](logs/summary.md). Current numbers: [the evidence](../../../../writeup/design/evidence.md).

- **A load** is an image's validation (30 to 45 %), its restore (25 to 36 %), file system calls (10 to 18 %) and the activation of the image's methods (8 to 14 %). The memberships' activation is 2 to 6 %, the walk at most 1 %.
- **The first edit's check** (2.57 s): 2.10 s compiles the check's own code; 0.46 s infers. The second edit (0.44 s) is inference alone.
- **The ODE session's first solves:** code generation 37 to 57 %, inference 26 to 28 %, compiling while inferring 13 to 35 %.
- **The forks' session:** the first `describe` (0.80 s) is 0.64 s of code generation and 0.12 s of inference: code the load ended, compiled again.
- **Plain code on the unified build against vanilla** (upstream CSV and DataFrames, the eight steps): inference 3.57 s against 2.08 s; code generation 6.23 s against 7.56 s. On the unified build, 20 to 30 % of inference's samples are in the runtime's lookup of an instance's compiled code at an `invoke` (`jl_method_compiled_callptr`, `ci_policy_is`, the call's stub).
- **Why that lookup is slow:** in the world inference runs in, 455 of the compiler's 2,816 compiled instances have their code beyond position 4 of the chain (to 19); 451 have more than one compiled CodeInstance. On vanilla: none beyond 3, none doubled (`logs/chain_position.log`).
- **NetworkDynamics' workload** (44.0 s): code generation 58 %, inference 26 %, compiling while inferring 6 %, the work 4 %, the loads 6 %.
