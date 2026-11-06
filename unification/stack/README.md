# The checks of the restructured `unified` stack

The stack of self-contained commits on v1.13.2 (`writeup/design/julia-changes.md` §7.1) was checked here on 2026-11-06. This is a check of builds, not an experiment.

## How to run

```sh
source env.sh
experiments/unification/stack/tests.sh julia-unified <label> core subtype worlds ...   # Base's test files, one at a time
julia-unified/julia --startup-file=no experiments/unification/stack/core_by_expr.jl julia-unified/test/core.jl <out.tsv>
```

- `tests.sh`: Base's test files on a built tree, one core, niced. Logs: `logs/<label>-<test>.log`.
- `core_by_expr.jl`: Base's `test/core.jl` one top-level expression at a time. For each expression it writes the line, the seconds, the live heap and the maximum RSS (MB), to find where one build spends more than another.

## Results (2026-11-06; load 3–11 of 128)

| Build | What ran | Result |
|---|---|---|
| commit 12 (the twelve general commits, before the bound on exact-type entries) | `core`, `subtype`, `worlds`, `ambiguous`, `reflection`, `reinterpretarray`, `Compiler/inline`, `Compiler/inference`, `ccall`, `precompile` (`logs/general-*.log`) | all pass; `core` 73.8 s inside the test, 13.8 GB allocated, 4.4 GB maximum RSS, against vanilla's 59.2 s, 12.6 GB, 2.2 GB (`../logs/e262-vanilla-core.log`) |
| the first top, 54fffd7b12 (not kept: a7ab25d01a without the bound) | the gates (`logs/top-gates.log`), E-262's four files (`logs/top-suites.log`) | gates 22 of 22; the files pass; `core` 73.9 s, as at commit 12 |
| 54fffd7b12 with commits 11 and 12 reverted | `core` (`logs/noinliner-core.log`) | 74.6 s: the inliner commits are not the cause |
| vanilla and 54fffd7b12, `core_by_expr.jl` | `core.jl` per expression (`logs/core-by-expr-*.tsv`) | 60.8 s and 391 MB live at the end against 77.7 s and 1,612 MB. Line 5406 alone: 7.8 s against 22.6 s, and its heap is never freed. The line splats about 1.2×10⁸ arguments into a varargs method. Commit 4 made an exact-type entry for that call: a type with one parameter per argument, kept alive by the call cache. |
| the top a7ab25d01a, with commit 4 bounded as Julia's compilation signatures are | `core` (`logs/top2-core.log`), the gates (`logs/top2-gates.log`), E-262's four files (`logs/top2-suites.log`, `../logs/e262-stack2-*.log`), E-270's questions (`../x4/out/run6-unified.txt`), the six other files (`logs/top2-*.log`) | `core` 58.9 s, 12.6 GB, 2.2 GB, as vanilla; gates 22 of 22; the four files at vanilla's wall times (`ambiguous` 8.6 against 8.1 s, the others within 1 %); E-270 as on fd800b27b9; the six other files pass |
