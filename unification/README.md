# Unification: the gates and acceptance cases of the unified build

The tests of the unified build ([compiler §7](../../writeup/reference/compiler.md#7-traits-in-the-type-system); [the synthesis plan](../../writeup/plans/2026-11-05-unification-synthesis.md); W-97 to W-104). Registry rows: E-260 to E-262 ([experiments §12](../../writeup/record/experiments.md)).

Copied on 2026-11-06 from the earlier attempt (`attic/oc-traits/`, `attic/oc-notes/c7count/`) unchanged, except for the run scripts. The audit (W-97) judges each gate as code; a gate is changed only with a note in this file.

## Layout

| Path | What | Stage that runs it |
|---|---|---|
| `Project.toml`, `src/Traits.jl` | a stub library: `@trait`, `@implement` (with a parametric form), three `ccall`s into the runtime's membership functions. No contract checks, no fields, no operations | every gate (`--project=experiments/unification`) |
| `gates/m1_*.jl` (10) | the type system: late memberships and worlds, compiled `isa`/`<:` before and after a membership (nested sets: the structural exclusion), positive folds and `min_world`, `Type{S}` members, parametric sets and members, the Core wrappers | stage 1, W-98 |
| `gates/m2_*.jl` (12) | dispatch: the typemap's linear placement, C7 in `type_morespecific_`, match world ranges at fixed, vararg and union positions, a caller compiled before a membership (the stopgap, compiler C-18), set-in-set answers, the ambiguity report, inference at the query world, the stopgap's volume | stage 2, W-99 |
| `gates/m3_*.jl` (9) | the facts policy and the record: run-time sites and effects, the record's kinds, the G2 bit and counts, fold records, an image round trip, the ambiguity report with dominance, the test bed `all` | stage 3, W-100 |
| `gates/util.jl` | shared probes (a function's CodeInstances, the current world) | — |
| `test/acceptance/AC_*.jl` (21) | the facts mode's acceptance cases in the unified form: a policy-compiled twin against a plain twin, values equal, each also under the test bed `all` (`ac_finish`) | stage 3, W-100 |
| `c7count/` | E-260: the C7 placement count on the patched build; `attempt/` holds the earlier attempt's TSVs | stage 0, W-97 |
| `audit/probes.jl` | the audit's probes: what the branch does beside what compiler §7 intends, without asserting | stage 0, W-97; gates once fixed |
| `e262_suites.sh` | E-262 (3): Base's `subtype`, `core`, `ambiguous` and `worlds` test files on a tree, wall time each, then `detect_ambiguities(Base)` | stage 0 and every stage's gate |
| `s0a/` | E-261 (W-S0a): `s0a.jl` counts, per step of a session, the invalidated code the code slot would keep (compiler §7.7); `run.sh` runs the forks' session and the `g2all`-shaped session on `julia-1.13`; `selftest0.jl`/`selftest1.jl` a case with a known answer (part (A): 2 of 4 CodeInstances kept, `f1` and `h1`; part (B) is not self-tested) | stage 0, W-97 |

**What will change in them:**
- The `m1_*` and `m2_*` gates were written against memberships composed through chains and a single world bump. Under explicit memberships and the method-insertion protocol (decisions 4 and 5, [decisions](../../writeup/record/decisions.md) §5), the gates that pin composed answers (`m2_set_in_set.jl`, `m2_future_min_worlds.jl`, parts of `m1_late_implement.jl` and `m1_worlds_minworld.jl`) are re-pinned in stage 1 and 2.
- The `m3_*` gates and `AC_*` cases call `Compiler.mark_facts!` and `Compiler.mark_concrete!`, session marks; the policy is the module option and the method flag saved with the method (decision 6). They are adapted in stage 3. The earlier suite's G1 cases (`experiments/facts/acceptance_compiler.jl`) map to them by the attempt's disposition table (`attic/oc-notes/m3-editplan.md` §E).

## How to run

```sh
source env.sh                                              # from the design repository
experiments/unification/gates/run_all.sh julia-unified     # the m1_* and m2_* gates
experiments/unification/gates/run_all.sh julia-unified 'm1_*'
experiments/unification/c7count/run_all.sh                 # E-260, on julia-1.13 (about 10 minutes)
experiments/unification/e262_suites.sh julia-unified unified   # E-262 (3); and julia-vanilla vanilla
experiments/unification/s0a/run.sh                         # E-261, on julia-1.13
julia-1.13/julia --startup-file=no experiments/unification/s0a/s0a.jl selftest work:experiments/unification/s0a/selftest0.jl work:experiments/unification/s0a/selftest1.jl
```

Each gate prints `<name>: OK` and exits 0, or asserts. One Julia process per gate; 4 cores.

The environments E-260 and E-261 load must be instantiated in the workspace depot first (`Pkg.instantiate(); Pkg.precompile()` per environment; logs in `logs/instantiate/`).

## Results

| Date | Build | What | Result |
|---|---|---|---|
| 2026-11-06 | `unified` c3f0b4bc11 | the 22 `m1_*`/`m2_*` gates (E-262) | 22 of 22 pass (`logs/e262-gates-unified-c3f0b4bc11.log`) |
| 2026-11-06 | `unified` c3f0b4bc11 | the audit's probes (`audit/probes.jl`) | P1, P2, P3, P4, P5, P6 differ from compiler §7 (`logs/audit-probes-c3f0b4bc11.log`; [the audit](../../writeup/reviews/2026-11-06-oc-build-audit.md)) |
