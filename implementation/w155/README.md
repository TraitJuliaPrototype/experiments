# W-155: the facts side of the next iteration without the library (D-5, D-6, D-7)

The plan's rows D-5 (G2 is the deep class), D-6 (a call that only throws) and D-7 (the code slot retired), built in `julia-next` (branch `next`), each commit with its gate. Registry: E-416 to E-419 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md` §1, "The deep class on `next`". The agent's session note: `session-notes/2026-11-15-agent-w155.md`.

## How to run

```
source env.sh        # the workspace's env.sh, a depot of this agent's own in front of the shared one, $JN, $CSVFILE, $LOADS
$JN --project=env_forks deep.jl $CSVFILE $LOADS      # E-416, E-417: the deep class on E-392's session (the forks)
$JN --project=env_facts deep.jl $CSVFILE $LOADS      # the same, upstream CSV and DataFrames compiled by facts
$JN gate_deep.jl                                     # D-5's gate: the bit as the deep class, on small cases
bash suites.sh julia-next <label> [gate tests library digests]   # Base's core, subtype, Compiler/inline,
                                                     # Compiler/inference; the library's suite; the forks' digests
bash runs.sh julia-next <label> 2                    # E-393's control (W-134's lost.jl), E-419
JULIA_DEBUG_EXTERNAL_CIS=1 $JN --project=<library tree> image.jl   # TraitWorld's image: size, what it keeps
```

`chain_*.sh` are the sequences run after each build (they wait for `julia-next/tw-build.log`'s `BUILD EXIT`). `scratch/` (not committed) held the files of the code slot's removal while a build ran.

- **Environments.** `env_forks` and `env_facts` are W-134's (`../w134/`). `env_forks` and `env_session` load the library from `TraitWorld-w155` (the baseline tag with strict mode by the class, branch `w155`; E-416 ran with `TraitWorld-base`), so that no gate loads `TraitWorld`, which another agent changes. `env_facts` reads W-134's copies in `../w134/pkgs-facts/`. `env_session` is the forks' own environment (`forks/env_forks`) for the session's digests.
- **`deep.jl`** extends W-152's tool (`../w152/p3/deep.jl`, E-395). Each instance's class three ways: the G2 bit as the build sets it; a walk over the CodeInstance edges with that bit; the walk with E-395's correction (an instance whose edges are bindings only counts as having the bit). Then the throw-only refinements (an edge to a callee whose result is `Union{}` not followed, from code compiled by facts only or from every caller), the edges that name a callee by MethodInstance alone, and what the nine loads end by class. On a build where the bit is the deep class (D-5), the bit and the walk agree, and the corrected walk is not needed.

## Results

### E-416 (2026-11-15): the baseline on `next`, and the questions for the rules

`next` at 7b374f39ce (the baseline), TraitWorld-base e11c7cc, forks 439bae7; product setting, strict mode off, one thread, one process per row; load 0.6 to 3.7 of 128. `logs/e416-deep.log`, `logs/e416-deep-b.log`.

| own image instances | the forks | upstream by facts |
|---|---|---|
| all; with the G2 bit as built | 4,799; 4,667 | 3,490; 3,438 |
| deep by the walk, the bit as built | 1,367 (28 %) | 1,030 (30 %) |
| deep by the walk, corrected (E-395's class) | 1,983 (41 %) | 1,382 (40 %) |
| corrected, calls that only throw without an edge from code compiled by facts | 1,986 (41 %) | 1,383 (40 %) |
| corrected, calls that only throw without an edge from every caller | 2,917 (61 %) | 2,215 (63 %) |
| ended by the nine loads; of them deep (any of the classes above) | 49; 0 | 14 (and 5 the work made); 0 |

- E-395's counts are reproduced.
- Reached instances without the bit whose edges are bindings only: 2,564 and 1,791 (open issue 187).
- Instances deep by the walk that name a callee by its MethodInstance or Method: 141 and 3; none whose callee's code is outside the class now.
- Throw-only callees called directly from facts code: 35 and 27; 20 and 8 of them throw by way of a further callee.
- **Reading:** the throw-only rule's gain lies in plain code (Base's callers of its throwing helpers). As the plan scoped it, to code compiled by facts, it moves 3 and 1 instances. D-6 is not built: open issue 194, GT-21.

### E-417 (2026-11-15): D-5's gate, the G2 bit as the deep class

`next` b54eab8c17 (the commit's first build), then 7063158f42 with D-7 in the tree; TraitWorld-w155 e682482 (strict mode by the class), forks 439bae7. `logs/e417-*`, `logs/e417b-deep.log`; the gate `gate_deep.jl` (`logs/e417-gate-deep-baseline.log` on the baseline).

| | the forks | upstream by facts |
|---|---|---|
| own image instances; with the bit (the deep class) | 4,772; 1,786 (37 %) | 3,464; 1,373 (40 %) |
| reached instances where the bit and the walk disagree | 0 | 0 |
| reached instances with binding edges only and no bit | 0 | 0 |
| ended by the nine loads; with the bit | 49; 0 | 14 (and 5 the work made); 0 |
| below the own code: ended; with the bit | 287; 0 | 109; 0 |

- The gate passes, 11 of 11 checks; the baseline fails 5 (the one-level bit: a caller of a callee outside the class, cycles, instances on bindings alone).
- The first build had two faults, fixed in the commit: another CodeInstance of the same instance exempted as the instance itself; an absence edge at a parametric pair not counted in.
- TraitWorld's image keeps 209 external instances by the bit where the one-level bit kept 237; machine code 5.33 MB against 5.48 MB (`image.jl`).
- E-416 (e): on the baseline, E-395's corrected walk with an edge that names a callee by MethodInstance alone counted outside gives 1,787 for the forks, the build's 1,786.

### E-419 (2026-11-15): D-7's gate, the code slot removed

Before: `next` b54eab8c17 (the slot built). After: 7063158f42 with the removal in the tree (committed as 9b6dacf5c5). `runs.sh` (W-134's `lost.jl`, order A, a warm-up and 2 runs), `image.jl`, Base's `precompile` test. `logs/e419-*`.

| | before | after |
|---|---|---|
| upstream by facts: own image instances ended; the work's | 14 of 3,464; 4 | 14; 5 |
| upstream by facts: first work; after the loads | 1.88 s; 1.55–1.73 s | 1.78–1.80 s; 1.46–1.47 s |
| the forks: own image instances ended | 48 of 4,772 | 49 |
| the forks: first work; after the loads | 0.18–0.19 s; 2.18–2.19 s | 0.136–0.138 s; 2.01–2.12 s |
| Base's `precompile` test | 232 s | 224 s |
| TraitWorld's image: machine code; build | 5.33 MB; 7.9 s | 5.29 MB; 7.2 s |

Load 6 to 7 before, 10 to 16 after. Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` pass on both; the forks' digests equal upstream's. The library's suite then failed strict mode's test of a pirate at `abs2`: an operation's split named an inlined branch by its MethodInstance (fixed, `next` 3037289af6; the checks on the head below).

### The head (2026-11-15): `next` 9b6dacf5c5

D-5 7063158f42, the split's branch edge 3037289af6, D-7 9b6dacf5c5; TraitWorld-w155 ca006e1. `logs/final-*`.

- `gate_deep.jl` passes. Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` pass. The forks' digests equal upstream's at 26 steps.
- The deep class: the forks 1,798 of 4,773 own image instances (38 %), upstream by facts 1,373 of 3,464 (40 %); the bit and the walk agree; the nine loads end 49, and 14 and 5, none with the bit.
- TraitWorld's image: 5.29 MB of machine code, 209 external instances kept by the bit.
- The library's suite passes on its branch `w155` ca006e1 (`logs/final-library-b.log`). Its test of a deleted pirate had a pirate whose body converts (`Int8(7)`), which rests on `Core.throw_inexacterror`, outside the class; strict mode secures the class only, so the test's pirate now computes in the class (open issue 194). `logs/final-library.log` is the run before that change.
