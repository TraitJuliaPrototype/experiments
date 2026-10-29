# E-255 (U7): how often inference folds a negative membership

Registry row: `writeup/record/experiments.md` §12, E-255. Exploration: `writeup/explorations/abstract-types-as-traits.md` §13.1, §13.4, §13.6.

**Question.** Candidate (c) of §13.4 never folds a negative answer `S ∉ X` for a set `X` that may get late members. Would that cost anything measurable? Counted: negative answers that inference fixes into code, against all negative answers. **Would change the plan:** under 1 % of negative folds and none in a hot loop: (c) is free and goes into P1. Hot folds in a demonstrator's loop: §13.3's edges or a `closed` mode.

## Answer

**By the row's criterion, (c) is free.** Two findings change §13.4's reasoning, though.

- **Folds that rest on a membership in an open set (T1)** are 0.003 % to 0.9 % of all negative folds in every run. At the sites that change code (branch sites) they are 0.03 % to 1.07 %.
- **The open sets in them are Base's families** (`AbstractArray`, `AbstractDict`, `AbstractString`, `Dates.Period`), asked in Base's own code: printing, strings, `typeinfo_prefix`. A package or `Main` could declare at most 3 of them in any run (T2). None sits in a loop of a demonstrator's code. The ones in loops are in Base's string and regex code.
- **No trait is ever on either side of a negative fold** (0 in all 11 runs of the suites and images). Today's code does not type values with traits.
  - The values of a trait are `Kept{X}`, `Compiled{X}` or `Dynamic{X}`. Under the unified model (§5.2), `Kept{X}` and `Compiled{X}` become `X`. So their folds stand in for the trait folds of the unified model (proxy P1).
  - P1 is 0.03 % to 0.9 % of all negative folds in the suites, and 6.6 % in TraitMakie's image code. At branch sites it is up to 4.6 % in the suites and 27 % in TraitMakie's images.
  - Almost all of them are TraitWorld's own tests of the wrapper form: `t isa Compiled`, `t isa Kept` (`entry.jl:226`, `attributes.jl:301–309`). The unified model replaces those with a test of the closed `Dynamic{X}`.
  - **Outside TraitWorld's machinery, P1 at branch sites is 0 to 23 answers per run, none in a loop.** Examples: `ip === nothing` on a kept interpolant (`ODECore/src/core.jl:832`, `TraitRodas/src/rodas5.jl:167`), and `pos isa Matrix{Float64}` on a `Positions` field (`TraitMakie/src/PlotCore.jl:352, 377, 501`). This supports §13.4's "where does trait code ask a negative? Rarely".
- **Finding 1, which changes §13.4: item 3 also reaches the compiler's bookkeeping.** About 90 % of all negative folds are at sites that only feed the compiler's bookkeeping. They ask whether a value could be:
  - a `Module` (`tfuncs.jl:2570`, effects: `inaccessiblememonly`);
  - a `Type` (`tfuncs.jl:2018`, `tuple_tfunc` widens to `Union{x, Type}`);
  - a `Bool` (`abstractinterpretation.jl:1300`, after irinterp);
  - a builtin or an opaque closure (`abstractinterpretation.jl:2979/2982`).

  For a value whose type is a trait (P1), most of its negative folds are these: 1,539 of 2,646 answers in TraitWorld's suite, 580 of 1,129 in TraitMakie's images. Item 3 as written makes `typeintersect(S, X)` non-empty for every `S` that is not a known member. These answers would then stop folding.
  - That costs precision of effects.
  - At `abstractinterpretation.jl:2979` it costs the call: a callee whose type is an open set "might be a builtin". Inference then returns `Any` with no method table (`Could not identify method table for call`). This matters for `Callable`-typed values.
  - **Proposal:** Core's kinds are never late members of a set: `DataType`, `UnionAll`, `Union`, `Module`, `TypeVar`, the builtin and opaque-closure types, and the memory types. Then these folds stay sound, and item 3 applies only to types that can be members. Whether `Type{T}` (a type as a value) may be a member is the one case to decide.
- **Finding 2: negatives on Base's families come with no cost from ownership.** Nobody outside Core and Base can declare a Core type a member of a Core-owned family (traits §10.1). The T1 folds with only Core, Base and stdlib types (T2 = 0) can stay folded under any rule. A `closed` default for the sets Core and Base own (§13.5) loses nothing measured here.

## What is counted, and how the counting differs from the row

- **The fork.** `setup.sh` copies `julia-1.13/Compiler`, adds `u7count.jl` and routes the sites through it (`compiler.patch`). `prelude.jl` loads the copy as the package `Compiler` (as `experiments/factscompiler` did) and calls `activate!(; reflection = true, codegen = true)`. It needs no Julia build.
- **A negative fold** (the denominator, "all negative folds") is any of these:
  - `isa_tfunc` or `subtype_tfunc` answering `Const(false)`. `isa(x, Union{})` is not counted.
  - `tmeet` of a constant answering `Bottom`.
  - `typeintersect` answering `Union{}`, or `hasintersect` answering `false`, for two non-empty types. This holds at all 63 call sites in Compiler's own files (`abstractinterpretation`, `abstractlattice`, `tfuncs`, `typelattice`, `typelimits`, `facts`, `ssair/passes`). Not counted: `EscapeAnalysis`, `verifytrim` and `reinfer`, which are separate modules, and the C side's intersections in method matching, which is dispatch (§5.5's question, not §13's).
  - Each answer is counted once per evaluation. Re-inference counts again. "Statements" counts distinct (site, method instance, statement).
- **Branch sites against bookkeeping sites.**
  - Branch sites: the `isa` and `<:` tfuncs, `tmeet` (type assertions, `PiNode`s, conditionals), `===` (`tfuncs.jl:381`), `invoke` and opaque-closure signatures, global assignment, `setfield!` and `memoryrefset!` value types, and SROA's φ edges. There a negative answer drops a branch, types a call as throwing or narrows a type.
  - Bookkeeping sites: all others (`BRANCH_SITES` in `prelude.jl`).
- **Open sets** (counted at either side: `x::X isa S` and `x::S isa X` both rest on `S ∈ X`):
  - every abstract type below `TraitWorld.Trait`, which is every trait, user traits in `Main` included;
  - `TraitWorld.Callable`;
  - every abstract type that an `@implement … where {A <: F}` ranges over. `families.jl` reads them from TraitWorld's `implementation` and `projection` methods after loading each demonstrator: `Core.AbstractArray` (which covers `AbstractVector`), `Base.AbstractDict`, `Core.AbstractString`, `Dates.Period`, `LinearAlgebra.Factorization`.
  - The demonstrators declare no family of their own. Each report checks that no family was declared during the run. `AbstractGraph` is in none of these demonstrators.
- **T1, "rests on a membership".** An open set stands at the top of one side (or of a `Union`'s member), or at the same position of two `Tuple`s. An open set only inside a `Tuple`, against a non-`Tuple` such as `Module`, is not T1. No membership can change that answer.
- **T2.** T1, and a type or set involved is owned by a package or by `Main`. Only then could a declaration that is not loaded yet change the answer.
- **T3.** T1 with a type from `Main`, which Lemma M does not cover. T2 and T3 are upper bounds: a type's parameters count as owners (`Vector{GIdx}`).
- **P1, the proxy, an addition to the row.** It is the T1 test with `Kept{X}` and `Compiled{X}` in place of the open sets. `Dynamic{X}` is not open: it stays a closed concrete type under the unified model.
- **The code being compiled** is the inferred method instance and its statement, or the optimizer's method instance. **"In a loop"** means the statement lies in a cycle of that method's control-flow graph. This is not a measure of hotness. Whether the method is itself called in a loop is not known.
- **Image code, an addition to the row.** In the product setting, code from package images was inferred by the plain compiler while the image was written, and a suite counts only what its session compiles. `reinfer.jl` loads the packages, clears the counts, and infers every method instance of every method the packages define once more (`code_typed_by_type`; the reflection compiler is the counting one). Those are the `*-reinfer` rows.
- **Artifacts of the fork.**
  - 32 of TraitWorld's 1,169 tests fail under the copied Compiler: `verify_main`'s holes, typed `Like` results, printing by attribute, rule 2 of attributes. TraitWorld's hooks work with `Base.Compiler`, and the session compiles with the copy. So some trait code takes another path (`Dynamic` where `Compiled` was expected).
  - The other suites pass.
  - The demonstrators run through `Pkg.test` (`--check-bounds=yes`, the test environment). TraitWorld's suite runs inside one outer test set, so that a failure does not end the run.

## How to run

```bash
cd experiments/w83/u7
./setup.sh                                   # the counting Compiler (Compiler/, not committed; compiler.patch is)
../../tools/jl --name NAME ../../../julia-1.13/julia --project=env -e 'using Pkg; Pkg.instantiate()'
./runall.sh A      # TraitWorld's suite, its images, TraitTables' and TraitCSV's tests
./runall.sh B      # TraitDifferentialEquations' and TraitMakie's tests, the demonstrators' images
./runall.sh all    # TraitWorld's suite in the test bed `all` (the facts system image)
```

`families.jl` writes `families.tsv`: `julia --project=<pkg> families.jl <Pkg>…`. `run.jl <tag> <script>` runs any script under the counting Compiler (`smoke.jl` is the smallest). Each run writes these logs:
- `logs/<tag>-summary.txt`;
- `logs/<tag>-all.tsv`: every negative fold by site, kinds and context;
- `logs/<tag>-open.tsv`: every fold with an open side, with its tier, the open set, the other side, owners, the method, `in_loop`, and the full types;
- `logs/<tag>.log`.

## Results, 2026-10-29

- Builds: julia-1.13 `00dcc9994c`; TraitWorld `33dd55e`; TraitTables `438ac2b`; TraitCSV `9c6477b`; TraitDifferentialEquations `e9e07ed`; TraitMakie `c0d5c36`.
- The setting is the product setting, unless the row says `all` (`-J julia-1.13/usr/lib/julia/facts/sys.so`).
- Strict mode is off. Each figure is from one run. Counts do not depend on the machine's load: two of the agent's jobs ran at once, in slots shared with other agents.
- These numbers measure trait code and its interop as the suites exercise them, today's code. The unified model's trait questions appear only through P1.

| run | all negative folds (answers) | at branch sites | T1 (% of all) | T1 at branch sites (% of branch) | T2 | T3 | T1 in a loop | P1 (% of all) | P1 at branch sites (% of branch) | P1 at branch sites, value types, outside TraitWorld (in a loop) |
|---|---|---|---|---|---|---|---|---|---|---|
| TraitWorld suite, product | 287,420 | 28,589 | 219 (0.076 %) | 35 (0.122 %) | 2 | 0 | 5, Base only | 2,646 (0.921 %) | 1,092 (3.82 %) | 5 (0) |
| TraitWorld suite, `all` | 248,035 | 24,382 | 102 (0.041 %) | 21 (0.086 %) | 2 | 0 | 2, Base only | 2,100 (0.847 %) | 1,116 (4.58 %) | 6 (0) |
| TraitWorld images | 51,705 | 6,902 | 33 (0.064 %) | 14 (0.203 %) | 0 | 0 | 1, Base only | 96 (0.186 %) | 10 (0.145 %) | 0 |
| TraitTables tests | 24,861 | 2,573 | 1 (0.004 %) | 1 (0.039 %) | 0 | 0 | 0 | 7 (0.028 %) | 4 (0.155 %) | 0 |
| TraitTables images | 22,242 | 2,382 | 2 (0.009 %) | 2 (0.084 %) | 0 | 0 | 0 | 151 (0.679 %) | 69 (2.90 %) | 0 |
| TraitCSV tests | 12,949 | 1,397 | 116 (0.896 %) | 15 (1.07 %) | 0 | 0 | 12, Base only | 5 (0.039 %) | 0 | 0 |
| TraitCSV images | 9,848 | 956 | 2 (0.020 %) | 2 (0.209 %) | 0 | 0 | 0 | 4 (0.041 %) | 0 | 0 |
| TraitDifferentialEquations tests | 180,858 | 19,074 | 56 (0.031 %) | 24 (0.126 %) | 3 | 3 | 1, Base only | 936 (0.518 %) | 574 (3.01 %) | 23 (0) |
| TraitDifferentialEquations images (6 packages) | 57,267 | 6,073 | 2 (0.003 %) | 2 (0.033 %) | 0 | 0 | 0 | 336 (0.587 %) | 124 (2.04 %) | 4 (0) |
| TraitMakie tests | 27,897 | 2,929 | 9 (0.032 %) | 2 (0.068 %) | 0 | 0 | 0 | 137 (0.491 %) | 96 (3.28 %) | 12 (0) |
| TraitMakie images | 17,042 | 1,983 | 2 (0.012 %) | 2 (0.101 %) | 0 | 0 | 0 | 1,129 (6.63 %) | 536 (27.0 %) | 2 (0) |

- Images re-inferred: TraitWorld 1,880 method instances; TraitTables 262; TraitCSV 92; TraitDifferentialEquations with its five packages 1,541; TraitMakie 792. All were inferred without an error.
- The open sets in T1 are families only: no trait, no `Callable`.
- **The most frequent T1 folds at branch sites:**
  - `isa:disjoint AbstractString vs AnnotatedChar` (`strings/annotated.jl:243`, in a loop, Base);
  - `x isa AbstractDict` in `typeinfo_prefix` (`arrayshow.jl:578`);
  - `x isa AbstractVector` in TraitIndexing's generated code (`none:0`, not in a loop).
- **The most frequent P1 folds** at bookkeeping sites, against compiler kinds:
  - `tfuncs.jl:2570` against `Module`: 2,465 answers over all runs;
  - `tfuncs.jl:2018` against `Type`: 415;
  - `abstractinterpretation.jl:1300` against `Bool`: 349;
  - `abstractinterpretation.jl:2979/2982` against `Builtin`/`OpaqueClosure`: 28 each.
