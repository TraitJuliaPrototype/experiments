# W-92: the forks' invalidated plain code, and the facts route (E-238)

W-92 asks whether the plain code that the forks' REPL session compiles again after the loads (E-233: 0.48 s in the steps) could be code of the facts owner, which unrelated loads do not invalidate ([facts §2.2](../../attic/writeup/reference/facts.md#g2)). Registry row: [`experiments.md`](../../writeup/record/experiments.md) E-238. The note with the choice: [`../../writeup/plans/2026-10-29-w92-forks-invalidation.md`](../../writeup/plans/2026-10-29-w92-forks-invalidation.md).

## How to run

Every Julia job runs under `experiments/tools/jl` or the shared lock, niced, under a kill timeout.

- `bash census.sh <tag> [env] [runs]`: the forks' session (`forks/scripts/session.jl`) in a real REPL on a pseudo-terminal, the REPL's typing hints off, with two logs on from before the REPL starts: Julia's method-insertion log (`jl_debug_method_invalidation`) and the compiler's log of image code that fails validation at load (`Base.Compiler.ReinferUtils.debug_method_invalidation`); the compile trace with timing. `census.jl` writes, at the end:
  - `census-<i>.txt`: every MethodInstance the method insertions invalidated (the REPL's start, the imports, the session), its cause, and whether the session compiled it again;
  - `roots-<i>.txt`: each compile root of the steps (between the imports' mark and the last mark), classified: rejected at load (image code whose edges failed validation, with the methods that broke them), invalidated by a method insertion, "not invalidated" (the trace's `# recompile` with no invalid plain code: another owner's code existed), or a first compile; and the image code rejected at load by package and cause.
- `rejections.jl [Pkg,…]`: the image code rejected while the packages load, by failed edge: the edge, the methods that now match there, the owners and packages of the code.
- `recompile_cis.jl`: the CodeInstances of the largest `# recompile` roots after the imports and after the step that compiles them.
- `session_script.sh <out>`: the session as a script with the REPL's display mirrored (`show` with `MIME"text/plain"` to an `IOContext` over `REPL.LimitIO`), each step's compile time and new CodeInstances by owner and package.
- `testfiles.jl <dir> <files…>`: DataFrames' test files, with `env_testdeps` (the test dependencies, offline) stacked under a forks tree's `env_forks`.
- `logformat.jl`: a look at the method-insertion log's entries (not a measurement).
- The session's timings: `../phase2-round/session.sh time <tag> 2` with `HINTS=0` (E-233's harness; `JFLAGS` added for the test bed `all`).

The wrapped DataFrames is the forks' branch `w92-wrapped` (0f0c518), run from a worktree `forks-w92` beside `forks/`.

## E-238, 2026-10-29

julia-1.13 bfca89decc, TraitWorld ca92f22 (not edited), forks main ba71341 (the package code of e4093e4) and `w92-wrapped` 0f0c518. Product setting, strict mode off, unless `all` is named. The REPL's typing hints off. A warm-up, then 1 census run or 2 timed runs; load average 1.9–2.5 before the runs (other agents' slot jobs; the timed runs held the lock). Measures plain code of a package whose kernels are trait code (`main`), and the same package's public layer as trait-module code (`wrapped`).

### 1. The census (`logs/census-main/`, `logs/rejections-forks.log`, `logs/recompile_cis.log`)

**The trace's `# recompile` does not mean invalidated.** Julia marks a root `# recompile` when its MethodInstance already has a CodeInstance with machine code, of any owner (`src/gf.c:3998`). So E-233's "plain code invalidated by the loads and compiled again, 38 roots 484 ms" mixes three kinds. The roots of the steps marked `# recompile` (38, 446 ms in this run):

| Kind | roots | ms | who enters it |
|---|---|---|---|
| **DataFrames' image code rejected at load**: `manipulate`'s body and its two keyword sorters, `innerjoin`'s sorter, `combine` | 5 | 226 | the REPL, through DataFrames' plain API (`select`, `subset`, `transform`, `innerjoin`, `combine`) |
| the compiler's `typeinf_code`, rejected at load (cause not logged) | 1 | 50 | TraitWorld's `Callable` entry, inferring the user's function (`PlainRTInterp`) |
| the compiler's closures (`get_infer_result`, `abstract_call`, `findsup_mt`): not invalid, compiled again plainly | 5 | 86 | the same |
| Base's methods on the columns (`length`, `getindex`, `copy` of `Vector{Union{Missing,Float64}}`, `StringVector`…): not invalid; a copy of the facts owner existed, the plain copy had no machine code | 27 | 83 | DataFrames' plain code, at run-time dispatch |

- **No code invalidated by a method insertion was compiled again in the steps.** The insertions invalidate 1,884 MethodInstances (602 at the REPL's start, by REPLCompletions' interpreter methods; 1,282 during the imports, by DataStrings, SentinelArrays, LaTeXStrings, InlineStrings and others); the session compiled none of them again.
- **Image code rejected at load: 1,010 CodeInstances.** By package of the code: PrettyTables about 450 (by CSV's `eltype(::Type{CSV.File})`, PooledArrays' and DataStrings' `convert`, CSV's `Tables.rowcount`), DataFrames 237, external Base code about 230, Tables 35, Statistics 23.
- **DataFrames' API code is rejected by a trait package's declarations.** The failing edges are DataFrames' plain untyped calls of `Column`'s operations: `vector(::Any)`, `nrows(::Any)`, `cell(::Any, ::Int)`, `take(::Any, ::AbstractVector{Int})`. They now match CSV's methods `vector(dyn::HeldValue{X}, args...) where X<:CSVColumn` (and `TextColumn`): TraitWorld lowers a subtrait (`@trait CSVColumn{T} <: Column`) to one method per supertrait operation on the subtrait's kept forms (`TraitWorld/src/trait.jl:540`), a method of Tables' function. DataFrames' image was built without CSV, so plain inference's edge on `vector(::Any)` lists fewer methods.
- **The facts owner's code rejected at load:** 30 `conformance(::As{Column}, ::Vector{…})` of Tables' image and 5 of CSV's, whose member-fold records changed when CSV's `@implement CSVColumn A where {A <: Vector}` loaded.
- **Correction (2026-10-29, E-243, [`../w94/`](../w94/README.md)):** the bullets on image code rejected at load (and `logs/rejections-forks.log`, `logs/census-main/`) count every entry `insert_backedges_callee` of the validation log as a rejection. Validation also writes one for every fold that holds and every binding without partitions, whose code stays valid. Of the 1,010 CodeInstances, 70 are such entries (37 by a fold, 33 by a binding) and are not rejected: the 30 `conformance` of Tables' methods and the 5 of CSV's among them. Image code rejected at load: 940; by package Tables 5, CSV 0, Base's external code about 195; the others as above. The roots of the steps are unaffected.
- **At the imports' step,** the REPL's `ansi_write` (163–172 ms) is compiled again: invalidated by DataStrings' `convert(::Type{String}, ::DataString)`. Julia's own plain code, entered by the REPL.

### 2. The facts route: DataFrames' public layer as trait-module code (`w92-wrapped`)

Porting 0.1a applied to the fork: the whole `DataFrames` module inside `@trait_module` (ColumnKernels stays a trait submodule); `Base.vcat(dfs::AbstractDataFrame...)` names its first frame; `@nospecialize(args...)` spelled `@nospecialize(args::Vararg{T})` at 22 definitions, since TraitWorld refuses `@nospecialize` on an ordinary vararg as if it were bounded (`trait_module.jl:874`: `_classify` names a vararg by its expression, kind `:vararg`).

- **The rejection is gone:** no running code of DataFrames is rejected at load (`logs/rejections-forks-wrapped.log`: what remains of DataFrames' is `:facts_plain_return_type` and TraitWorld's check results). The steps' `# recompile` roots: 1 rejected at load (the compiler's `typeinf_code`, 48 ms), 10 not invalid (123 ms, 7 of them the compiler's), none of DataFrames' API (`logs/census-wrapped/`).
- **But the session compiles the facts owner's copies of what the public layer reaches,** where no image holds them: the display at the REPL's I/O type (DataFrames' `show`, PrettyTables), `describe`, the `ByRow` paths, and the Base methods under them. In the script mirror (`logs/script-wrapped.log`): `show` 46 new CodeInstances of the facts owner (30 of Base), `describe` 172 (103 of Base), `select_filter` 180 (102 of Base), `user_function` 131 (98 of Base).

### 3. The session, timed (`logs/session/`; `../phase2-round/session.sh time`, `HINTS=0`, 2 runs after a warm-up)

Seconds, wall / of it compiling.

| | main (plain public layer) | wrapped (trait-module public layer) | main under `all` (facts system image) |
|---|---|---|---|
| start | 0.36 | 0.61 (the REPL's bimodal start) | 0.61 |
| imports | 1.39–1.40 / 0.46–0.47 | 1.46–1.50 / 0.56–0.58 | 1.26–1.29 / 0.29–0.30 |
| show | 0.20 / 0.19 | 0.39 / 0.38 | 0.18 / 0.17 |
| describe | 0.19 / 0.16 | 0.26–0.27 / 0.25 | 0.24 / 0.21 |
| select_filter | 0.73–0.74 / 0.71–0.72 | 0.57–0.59 / 0.55–0.57 | 0.34 / 0.30–0.31 |
| user_function | 0.35 / 0.33–0.34 | 0.44–0.45 / 0.42–0.43 | 0.37 / 0.33 |
| join | 0.18 / 0.04 | 0.15–0.17 / 0.01 | 0.16 / 0.01 |
| write | 0.08 / 0.07 | 0.08–0.09 / 0.08 | 0.05 / 0.05 |
| **steps** | **2.08–2.10 / 1.59–1.60** | **2.26–2.31 / 1.78–1.80** | **1.89–1.90 / 1.16** |
| **wall without the start** | **3.60** | **3.84–3.94** | **3.27–3.30** |

- **The facts route as built costs 0.24–0.34 s:** it saves 0.15–0.17 s in `select_filter` and 0.02 s in `join`, and pays 0.19 s in `show`, 0.08 s in `describe`, 0.09–0.10 s in `user_function` and 0.07–0.10 s at the imports.
- **Under `all` the same code is 0.31–0.34 s faster than the product setting:** the facts system image and every package image hold the facts owner's code, so the facts copies come from images; the steps compile 1.16 s instead of 1.59 s, but run about 0.3 s slower (run-time sites).

### Checks of the branch `w92-wrapped`

- `forks/scripts/check_session.sh ../julia-1.13/julia env_forks`: digests equal at 26 steps, the REPL session 20 marks, 0 errors (`forks/logs/w92/check-session.log`).
- D2 (`forks/scripts/d2_pooled.jl`): output equal to `forks/logs/d2/pooled.log` (`forks/logs/w92/d2-wrapped.log`).
- DataFrames' test files for the code touched (`testfiles.jl`): `cat.jl` 233, `insertion.jl` 1,210, `subset.jl` 2,218, `select.jl` 4,192 passed (`forks/logs/w92/testfiles-wrapped.log`).

### Limits

- One census run per side; the census' logs slow validation at load, so its times are not the session's.
- The REPL's start is bimodal (0.36 or 0.61 s, E-233); the table compares the session without it.
- The trace records only top-level compile requests; code of the facts owner compiled under them is in their time. The script mirror's display is `REPL.LimitIO` over an `IOBuffer`, not the terminal.
