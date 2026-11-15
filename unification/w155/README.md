# W-155: the facts side of the next iteration without the library (D-5, D-6, D-7)

The plan's rows D-5 (G2 is the deep class), D-6 (a call that only throws) and D-7 (the code slot retired), built in `julia-next` (branch `next`), each commit with its gate. Registry: E-416 to E-419 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md` §1, "The deep class on `next`". The agent's session note: `session-notes/2026-11-15-agent-w155.md`.

## How to run

```
source env.sh        # the workspace's env.sh, a depot of this agent's own in front of the shared one, $JN, $CSVFILE, $LOADS
$JN --project=env_forks deep.jl $CSVFILE $LOADS      # E-416, E-417: the deep class on E-392's session (the forks)
$JN --project=env_facts deep.jl $CSVFILE $LOADS      # the same, upstream CSV and DataFrames compiled by facts
```

- **Environments.** `env_forks` and `env_facts` are W-134's (`../w134/`), with the library at `TraitWorld-base` (the baseline tag) or the agent's library worktree, so that no gate loads `TraitWorld-unified`, which another agent changes. `env_facts` reads W-134's copies in `../w134/pkgs-facts/`. `env_session` is the forks' own environment (`forks-unified/env_forks`) for the session's digests.
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
