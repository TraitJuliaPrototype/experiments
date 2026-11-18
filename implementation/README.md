# The implementation's gates, acceptance cases and experiments

What checks and measures the implementation. Until 2026-11-18 the directory was `experiments/unification/`; logs name it so.

- **The registry rows** are in `../../writeup/record/experiments.md`; a row's "Where" names a directory here.
- **What to run after a change:** `../../writeup/record/playbook.md` §3.

## How to run

```sh
source env.sh                                             # from the design repository
experiments/implementation/gates/run_all.sh julia-next    # every gate in force, then every stage gate
experiments/implementation/gates/run_all.sh julia-next 'n20_*'   # a pattern selects
experiments/implementation/e262_suites.sh julia-next next # Base's four test files; and: julia-vanilla vanilla
```

- Each gate prints `<name>: OK` and exits 0, or asserts. One Julia process per gate, 4 cores. `run_all.sh` ends with one tally for the gates in force and one for the stage gates, and exits 1 if any failed.
- The gates are listed in [`gates/README.md`](gates/README.md); the stage gates in `gates/stage_gates.txt`. Files that are not gates in force are in `gates/not-in-force/`.
- The static check of GC roots for a change to the runtime's C code: [`w163/README.md`](w163/README.md).
- The acceptance cases of the facts mode: `test/acceptance/`, run by `test/runtests.jl`.
- The measurement round's method and harness: [`w145/README.md`](w145/README.md).

## The directories

- `gates/`, `test/acceptance/`, `src/` (a stub library for the gates), `audit/` (probes: what the build does beside what the reference intends), `stack/` (the checks of the commit stack), `workloads/`.
- `w<n>/`: the experiments of work item W-n. `e<n>/`: of experiment E-n. `x<n>/`, `c<n>/`, `i<n>/`, `l<n>/`, `s0a/`, `c7count/`: single questions. Each has a README, or its registry row says what it holds.

## History: the first layout

What follows describes the directory as it was set up, with the first stages' gates.

## Layout

| Path | What | Stage that runs it |
|---|---|---|
| `Project.toml`, `src/Traits.jl` | a stub library: `@trait`, `@implement` (with a parametric form), three `ccall`s into the runtime's membership functions. No contract checks, no fields, no operations | every gate (`--project=experiments/implementation`) |
| `gates/m1_*.jl` (10) | the type system: late memberships and worlds, compiled `isa`/`<:` before and after a membership (nested sets: the structural exclusion), positive folds and `min_world`, `Type{S}` members, parametric sets and members, the Core wrappers | stage 1, W-98 |
| `gates/m2_*.jl` (12) | dispatch: the typemap's linear placement, C7 in `type_morespecific_`, match world ranges at fixed, vararg and union positions, a caller compiled before a membership (the stopgap, compiler C-18), set-in-set answers, the ambiguity report, inference at the query world, the stopgap's volume | stage 2, W-99 |
| `gates/m3_*.jl` (9) | the facts policy and the record: run-time sites and effects, the record's kinds, the G2 bit and counts, fold records, an image round trip, the ambiguity report with dominance, the test bed `all` | stage 3, W-100 |
| `gates/util.jl` | shared probes (a function's CodeInstances, the current world) | — |
| `test/acceptance/AC_*.jl` (21) | the facts mode's acceptance cases in the unified form: a policy-compiled twin against a plain twin, values equal, each also under the test bed `all` (`ac_finish`); a marked function's methods carry the method flag "always facts". E-276 (2026-11-07, `w100` 95fe10427c): 18 pass in both settings. E-277 (`w100` 9a601902a0): 20 pass; `AC_18` and `AC_20` re-judged to the record's positive membership, the entry itself (compiler §3.1); `AC_16` waits for `@enforce_fully_typed` (W-114) | stage 3, W-100 |
| `c7count/` | E-260: the C7 placement count on the patched build; `attempt/` holds the earlier attempt's TSVs | stage 0, W-97 |
| `audit/probes.jl` | the audit's probes: what the branch does beside what compiler §7 intends, without asserting | stage 0, W-97; gates once fixed |
| `e262_suites.sh` | E-262 (3): Base's `subtype`, `core`, `ambiguous` and `worlds` test files on a tree, wall time each, then `detect_ambiguities(Base)` | stage 0 and every stage's gate |
| `s0a/` | E-261 (W-S0a): `s0a.jl` counts, per step of a session, the invalidated code the code slot would keep (compiler §7.7); `run.sh` runs the forks' session and the `g2all`-shaped session on `julia-1.13`; `selftest0.jl`/`selftest1.jl` a case with a known answer (part (A): 2 of 4 CodeInstances kept, `f1` and `h1`; part (B) is not self-tested) | stage 0, W-97 |

**What will change in them:**
- The `m1_*` and `m2_*` gates were written against memberships that `isa`, intersection and dispatch compose but `<:` does not, and a single world bump. Under transitive membership and the method-insertion protocol ([decisions](../../writeup/record/decisions.md) §5, 2026-11-06), the lines that pin `<:` as non-transitive (`m2_set_in_set.jl` line 19) and the task's world set from C (`m1_late_implement.jl`, `m1_worlds_minworld.jl`) are re-pinned in stages 1 and 2. `m1_typevalue_isa.jl` and `m2_set_in_set.jl` lines 17–18 pin a defect (the audit's A1) and are re-pinned too.
- The `m3_*` gates call `Compiler.mark_facts!` and `Compiler.mark_concrete!`, session marks; the policy is the module option and the method flag saved with the method (decision 6). The `AC_*` cases are adapted (E-276): `mark!` sets the method flag, the child runs under `JULIA_COMPILE_BY_FACTS=1`, and the assertions that pinned the earlier attempt's representation (per-split edge pairs, a CodeInstance per type value, a neutral helper compiled by facts in the product setting) assert G1 and the reference's facts instead. The earlier suite's G1 cases (`experiments/facts/acceptance_compiler.jl`) map to them by the attempt's disposition table (`attic/oc-notes/m3-editplan.md` §E).

## How to run

```sh
source env.sh                                              # from the design repository
experiments/implementation/gates/run_all.sh julia-unified     # the m1_* and m2_* gates
experiments/implementation/gates/run_all.sh julia-unified 'm1_*'
experiments/implementation/c7count/run_all.sh                 # E-260, on julia-1.13 (about 10 minutes)
experiments/implementation/e262_suites.sh julia-unified unified   # E-262 (3); and julia-vanilla vanilla
experiments/implementation/s0a/run.sh                         # E-261, on julia-1.13
julia-1.13/julia --startup-file=no experiments/implementation/s0a/s0a.jl selftest work:experiments/implementation/s0a/selftest0.jl work:experiments/implementation/s0a/selftest1.jl
```

Each gate prints `<name>: OK` and exits 0, or asserts. One Julia process per gate; 4 cores.

The environments E-260 and E-261 load must be instantiated in the workspace depot first (`Pkg.instantiate(); Pkg.precompile()` per environment; logs in `logs/instantiate/`).

## Results

| Date | Build | What | Result |
|---|---|---|---|
| 2026-11-06 | `unified` c3f0b4bc11 | the 22 `m1_*`/`m2_*` gates (E-262) | 22 of 22 pass (`logs/e262-gates-unified-c3f0b4bc11.log`) |
| 2026-11-06 | `unified` c3f0b4bc11 | the audit's probes (`audit/probes.jl`) | P1, P2, P3, P4, P5, P6 differ from compiler §7 (`logs/audit-probes-c3f0b4bc11.log`; [the audit](../../attic/writeup/reviews/2026-11-06-oc-build-audit.md)) |
| 2026-11-06 | julia-1.13 00dcc9994c | E-260, the C7 count (`c7count/run_all.sh`) | equal to the attempt's in every session; flag 92–99.6 % of the specializations, `type_morespecific_` the `::Any` methods' and the members' (`logs/e260-c7count-00dcc9994c.log`) |
| 2026-11-06 | julia-1.13 00dcc9994c | E-261, the slot's estimate (`s0a/run.sh`) | forks: 341 of 1,233 invalidated CodeInstances kept, facts callers 67 of 120; `g2all`: 1,622 of 6,430, 91 of 100 (`logs/e261-s0a-*.log`) |
| 2026-11-06 | `unified` c3f0b4bc11 and vanilla `45b6d15e34` | E-262 (3), Base's four test files | pass on both; 16.1/67.7/8.6/8.6 s against 15.7/65.4/8.1/8.4 s; `detect_ambiguities(Base)` 0 on both |
