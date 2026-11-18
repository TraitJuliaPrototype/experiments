# W-156, first part: the demonstrators follow the design (traits T-128; E-504)

**The question** (registry row E-504): do the demonstrators keep their suites, their session's time and what the session compiles when their casts become the box, the wrapper, a subtrait or an operation? What would change the design: a cast that none of the four replaces without a workaround.

**The design** (traits §7.4 to §7.8, §8): a value is compiled as Julia compiles it. Code compiled once holds the box `Dynamic{X}(x)`; a trait that erases by default boxes at a method's entry; code compiled per type takes the wrapper `compiled_for(x)`. Nothing beside a call decides how an argument is compiled.

## How to run

```sh
source experiments/implementation/w156/env.sh      # the workspace's env.sh, and a depot of this work's own
cd experiments/implementation/w156
bash census.sh [file]                    # the attribute's surface in the demonstrators, with file and line
bash counts.sh <rev>                     # the annotations per demonstrator at a revision (unified, w156)
bash suites.sh <label> tables csv report report-session makie makie-session tde tde-session forks-tables digests examples
bash sessions.sh <tag> [N]               # the regression control: the report and the table session, a warm-up and N runs
julia --project=env_demo probes/forms.jl        # at a dynamic call: a plain member, the wrapper and Julia's cast, first_seen on and off
julia --project=env_demo probes/kept_tables.jl  # TraitTables' column code given a plain column, a box and a wrapper
julia --project=env_session probes/byrow.jl     # the forks' byrow with its function plain, wrapped and boxed; ByRow(Dict)
cd ../../../forks/DataFrames/test && julia --project=$W156/env_join $W156/probes/join_tests.jl   # DataFrames' join.jl alone
```

- `census.sh` lists three kinds: `surface` (a name of the attribute's surface), `cast` (`compiled_for(` in code of a file that does not bind the wrapper's function), `prose` (a comment, docstring or README line that describes casts or a value kept "with its attribute").
- `suites.sh` runs each demonstrator's suite or check on `julia-next`, one job at a time, niced; a line per suite in `logs/<label>-summary.log`. The REPL sessions of TraitMakie and TraitDifferentialEquations run with `env_makie_session/` and `env_tde_session/` (their `scripts/env/Project.toml` with the paths from here, resolved), since the trees' `scripts/env/` hold no manifest.
- `sessions.sh` is W-120's harness as E-389 ran it (`../w120/session_marks.jl` on `../w135/apps/report.jl` and `table.jl`), on `julia-next`, with `instances.jl` for the compiled instances the session's packages hold after one run.
- Logs: `logs/`. The demonstrators' changes: branch `w156` of each repository.

## Results, 2026-11-18

`next` 02139b2168, TraitWorld 3e64ede. Before: the demonstrators' `unified` heads (TraitTables 7eb82b7, TraitCSV f296d0e, TraitReport 2a81de6, TraitMakie efc3ec0, TraitDifferentialEquations 0816231, forks b8cab0b). After: their branch `w156` (TraitTables 3f3e5a9, TraitCSV 57ccb3c, TraitReport a41c595, TraitMakie 4ef82e1, TraitDifferentialEquations a4bc47d, forks 2176f57). Product setting, strict mode off, one thread; load 6 to 9 of 128 for the suites, 45 to 100 for the sessions (another user's jobs).

**The census** (`census.sh`): 88 lines before (`census-before.txt`: 40 surface, 12 cast, 29 prose), 24 after (`census-after.txt`: 15 surface, 5 cast, 4 prose). What is left:
- the module option `first_seen = false` in eleven trait modules (TraitTables' `TableCore`, TraitCSV's `CSVCore`, every module of TraitDifferentialEquations) and the README lines that explain it: the library's `@trait_module` sets `first_seen` unless it is written (traits T-127). The line goes when the library's default follows the design.
- lines that say the library's exported `compiled_for` is still Julia's cast (traits T-126);
- `compiled_for(d)` in two scripts of the forks' closed experiments (`scripts/d3_refcodes.jl`, `scripts/m7_stage_split.jl`; E-214, E-217): they call the library's export, which becomes the wrapper with T-126.

**The annotations** (`counts.sh`; code lines; the forks' `unwrap` is Tables' own function of DataValues):

| demonstrator | casts before → after | module options | boxes | wrappers | `@default_dynamic` | `unwrap` |
|---|---|---|---|---|---|---|
| TraitTables | 4 → 0 | 0 → 1 | 0 → 0 | 0 → 0 | 0 | 0 |
| TraitCSV | 1 → 0 | 0 → 1 | 0 → 0 | 0 → 0 | 0 | 0 |
| TraitReport | 2 → 0 (`Kept{`) | 0 | 0 | 0 | 0 | 0 |
| TraitMakie | 1 → 0 (`Kept{`) | 0 | 29 → 30 | 0 → 1 | 0 | 0 |
| forks | 5 → 5 (the closed experiments' scripts) | 0 | 2 → 4 | 0 → 1 | 0 | 10 → 10 |
| TraitDifferentialEquations | 5 → 0 | 9 → 9 | 78 → 80 | 24 → 27 | 1 | 11 → 11 |

**The suites** (`logs/before-summary.log`, `logs/after-summary.log`):

| | before | after |
|---|---|---|
| TraitTables | 25 pass, 3 testsets | 26 pass, 3 testsets |
| TraitCSV | 15 pass, 2 testsets | 16 pass, 2 testsets |
| TraitReport `check.sh` | 3 of 3 ok | 3 of 3 ok |
| TraitReport REPL session | 7 of 8: the `Kept{Column}` check fails | 8 of 8 |
| TraitMakie | 8 testsets pass | 8 testsets pass |
| TraitMakie REPL session | 7 of 10: the recipe at `Kept{ColorSpec}` is refused | 10 of 10 |
| TraitDifferentialEquations | 35 testsets pass | 35 testsets pass |
| its REPL session | 14 checks ok, results equal the plain session's | the same |
| the forks' Tables | 1 error: upstream's `ByRow(Dict)` | the same error |
| the forks' session digests | equal at 26 steps | equal at 26 steps |
| DataFrames' `join.jl` (the joins changed) | not run | 1,465,119 pass |
| TraitMakie `scripts/errors.jl` | stops at its third case: the library's `@trait_module` takes options only, not `@trait_module module … end` | the same (`logs/makie-errors-*.log`) |
| `docs-examples` intro, tutorial, strict | not run | 24, 94, 5 pass; 3, 1, 0 known deviations |

The new tests of TraitTables and TraitCSV fail with their trait module at `first_seen = true` (`logs/discriminate-tables.log`, `logs/discriminate-csv.log`).

**The regression control** (`sessions.sh`, a warm-up and 3 runs each, fresh processes; `logs/sessions-before2.log`, `logs/sessions-after2.log`, run back to back at load 64 to 45):

| | before | after |
|---|---|---|
| the report (TraitCSV, TraitTables, TraitMakie): wall | 1.087–1.146 s | 1.065–1.070 s |
| its first run of `main`, of it compiling | 123–126 ms, 53–56 ms | 113 ms, 53 ms |
| compiles in the session | 25, 234 ms | 25, 231 ms |
| the table session (TraitCSV, TraitTables): wall | 0.691–0.697 s | 0.689–0.694 s |
| compiles in the session | 19, 178 ms | 19, 178 ms |
| instances with code the packages hold (TraitTables, TraitCSV) | 96, 27 | 103, 29 |

The 7 and 2 instances more are all at the box: the definition-time check's instances (traits §7.3) of the column code at `Dynamic{Column{Float64}}` and `Dynamic{CSVColumn{Float64}}`, held by the images (`logs/instances-kept-after.log`). None is compiled in the session. An earlier pair at load 6 to 100 (`logs/sessions-before.log`, `logs/sessions-after.log`) gave the same counts.

**The probes.**
- `probes/forms.jl` (`logs/probe-forms.log`): in a trait module with `first_seen` on, a plain member at a dynamic call compiles the method once at the trait; the wrapper compiles it for `Compiled{T}`; Julia's cast for the member's type. With `first_seen` off, a plain member compiles for its type.
- `probes/kept_tables.jl` (`logs/probe-kept-tables.log`): TraitTables' code given a box or a wrapper of a `Vector{Float64}` column gives the same summaries, but `take` and `sortby` return a `Vector{Any}` column where the plain column gives a `Vector{Float64}`: `eltype` of a kept form is `Any` (traits T-130).
- `probes/byrow.jl` (`logs/probe-byrow.log`): the forks' `byrow` gives the same results for a plain function, a wrapper and a box, and is compiled once at `Callable{Tuple{Int64}}` for all three: the compiler resolves `Callable`'s default at a call, for the wrapper too (compiler C-112). `Dict` is no `Callable`, so upstream's `Tables.ByRow(Dict)` finds no method.

# W-156, second part: the attribute's surface leaves the library (traits T-126, T-127)

**The question:** when the library offers only the design's forms (the box, the wrapper `compiled_for(x)` as its exported function, `@default_dynamic`; no cast, no `keep`, no `Kept`, no module option `dynamic` or `first_seen`, no `@default_compiled`), do the library's tests, the gates, the examples and the demonstrators' suites hold, and does a session compile more where a trait module relied on `first_seen` (a trait argument at a call whose caller does not know the value's type, compiled once at the trait)? What would change the design: a site whose growth no box at a door, no trait that erases by default and no per-type code answers.

## How to run

```sh
source experiments/implementation/w156/env.sh
cd experiments/implementation/w156
bash forks_session.sh <tag> [N]          # the forks' session: a warm-up and N runs; then one run that lists the instances
python3 compare_instances.py logs/b-before-instances.tsv logs/b-after-instances.tsv [--trace logs/b-forks-after.trace] [-v]
bash sessions.sh <tag> [N]               # the report's and the table's sessions (the first part's harness)
bash suites.sh <label> tables csv report report-session makie makie-session tde tde-session forks-tables digests examples
bash ../w161/suites.sh <label> nd        # NetworkDynamics' test subset
bash census.sh [file]                    # the attribute's surface left in the demonstrators
(cd ../../../TraitWorld && $JN --project=. ../experiments/implementation/w156/probes/first_seen_discriminates.jl)
```

- `forks_session.sh` runs `forks_session.jl`: the forks' session (`forks/scripts/session_check.jl`, its 26 steps as digests) in one process, timed: the load and the session, of it compiling (`Base.cumulative_compile_time_ns`), the number of compiles (`--trace-compile`), the digests against upstream's (`forks/env_upstream`, made once: `logs/b-digests-upstream.txt`). A last run, not timed, writes every instance with code in the forks' packages to `logs/b-<tag>-instances.tsv`. Log: `logs/b-forks-<tag>.log`; the last timed run's compiles: `logs/b-forks-<tag>.trace`.
- `compare_instances.py` is the audit's tool: the forks' compiled instances before and after, by method, largest growth first, each with the instances it gained and lost. With `--trace`, the session's compiles of a function that before had an instance at a trait's own type (the sign that `first_seen` compiled it once there): the sites that now compile per type in the session.
- `census.sh` now reads `compiled_for(` as the library's wrapper wherever a file binds the library (`using TraitWorld`, an import list with the name, a REPL entry's `"using …, TraitWorld"`, a package's module file for the files it includes); `ByType` is a name of the surface. It covers NetworkDynamics (`ndport/pkgs/NetworkDynamics-unified`) and `ndport/README.md` too.
- `probes/first_seen_discriminates.jl`: the library's test of a trait module (`TraitWorld/test/trait_modules.jl`, "trait modules") fails where Julia's option `first_seen` is set by hand (`logs/b-probe-first-seen.log`).

## Results, 2026-11-18

`next` 02139b2168. Before: TraitWorld `unified` 3e64ede, the demonstrators' `unified` heads (TraitTables 3f3e5a9, TraitCSV 57ccb3c, TraitMakie 2c560cb, forks 2176f57). After: branch `w156` of each (TraitWorld ea72682, TraitTables 729f3ad, TraitCSV c95c67c, TraitMakie 106bed9, TraitDifferentialEquations 7956907, forks a3a37d6, NetworkDynamics 82513ee, ndport 0825fee). Product setting, strict mode off, one thread (NetworkDynamics' subset two). Fresh processes, niced.

**The library** (`logs/b-library-3.log`): 90 testsets pass (93 before: the testsets of the casts, of the `detect_` functions and of `detect_kept_storage` deleted; `keep` and `Kept` rewritten to the struct parameter and to storage). One `@test_broken`: `verify_main`'s holes for the wrapper of a value known only by its trait, which the build's own check refuses (compiler C-114).

**Gates and examples:** `run_all.sh julia-next`: 72 of 72 in force, 9 of 9 stage gates (`logs/b-gates.log`). The examples: intro 26 pass, 1 deviation (no row); tutorial 95 pass; strict 5 pass (`logs/b-examples-*.log`).

**The suites** (`logs/b-after-summary.log`, `logs/b-nd-summary.log`):

| | after |
|---|---|
| TraitTables | 26 pass, 3 testsets |
| TraitCSV | 16 pass, 2 testsets |
| TraitReport `check.sh`; its REPL session | 3 of 3 ok; 8 of 8 |
| TraitMakie; its REPL session | 8 testsets pass; 10 of 10 |
| TraitDifferentialEquations; its REPL session | 35 testsets pass; 14 checks ok, results equal the plain session's |
| the forks' Tables | 1 error: upstream's `ByRow(Dict)` (open issue 240) |
| the forks' session digests | equal at 26 steps |
| NetworkDynamics' subset | massmatrix 6, doctor 26 pass; diffusion 1 fail, 1 error; inhomogeneous 1 error (the known failures) |

**The regression control** (a warm-up and 3 runs each):

| | before | after |
|---|---|---|
| the forks' session: wall | 7.10–7.37 s | 6.66–6.72 s |
| its load and session, of it compiling | 6773–7055 ms, 4181–4424 ms | 6346–6425 ms, 4034–4070 ms |
| compiles in the session | 236 | 224 |
| instances with code in the forks' packages after the session | 4768 | 4836 |
| the report: wall; first run, of it compiling | 1.030–1.108 s; 114.7–116.1 ms, 51.4–54.7 ms | 1.027–1.043 s; 113.2–115.6 ms, 51.4–51.7 ms |
| its compiles | 25, 218 ms | 25, 217 ms |
| the table session: wall; compiles | 0.650–0.681 s; 19, 179 ms | 0.651–0.699 s; 19, 169 ms |
| instances TraitTables, TraitCSV, TraitMakie (report) | 103, 29, 305 (44 at a kept form) | 103, 29, 318 (54 at a kept form) |

Load: the forks' session 17.4 → 14.2 before, 22.9 → 12.9 after; the report and table sessions 11.9 → 11.5 before, 10.3 → 10.1 after (of 128). Logs: `logs/b-forks-before.log`, `logs/b-forks-after.log`, `logs/b-sessions-before.log`, `logs/b-sessions-after.log`. (The before run kept no trace of its compiles; `logs/b-forks-after.trace` is the after run's.)

**The audit of the forks** (`logs/b-audit-before-after.txt`). Before, 13 methods of the forks had 33 instances with an argument at a trait's own type (`Column{T}`, `TextColumn`, `CSVSource`, …; a container typed by the trait not counted): code compiled once there by `first_seen`. After:
- **The join's kernels** (`innerrows`, `_innerjoin_sorted`, `_innerjoin_unsorted`, `_innerjoin_dup`, `_innerjoin_unsorted_int`, `_innerjoin_dup_int`, `_issorted`, `_next_range`, `_extrema_missing`, `semirows`, `jointcodes!`, …, `DataFrames/src/other/kernels.jl`): compiled at the box `Dynamic{Column{T}}`, once per cell type, as the join's door intends (`_erased`, `DataFrames/src/join/core.jl`). Before, `first_seen` compiled them at the bare `Column`, under the door. 77 more instances in DataFrames, all held by the images: the session compiles none of them.
- **The door `_erased`** (`core.jl:239`): compiled per column type (13 of its 14 instances), where it was compiled at `Column{T}` once per cell type (10 of 13). A one-line function: nothing to do.
- **`CSV.ColumnParsers.filltext!`** (`ColumnParsers.jl:139`): compiled per text column type. The session's one new compile: `filltext!` for `Vector{String15}` (step 3, `stringtype = String15`). A kernel over a column's cells: per-type code is what the design wants there (traits §7.10).
- **`CSV.ColumnParsers.readfile`** (`ColumnParsers.jl:39`): per source type (`IOBuffer`, a path), in the images; one instance at `Dynamic{CSVSource}`. Nothing in the session.
- `CSV.ColumnParsers.stagecells!` (`ColumnParsers.jl:151`) keeps its one instance at `Column`, before and after: not the option's.

So no site needed a door or a trait that erases by default: the session compiles 12 fewer signatures than with the option, and its digests equal upstream's.

**The census** (`logs/b-census-after.txt`): no name of the surface in the demonstrators' code. Left: three dated rows of `ndport/README.md`'s results table (history), and the word "casts" in a comment of NetworkDynamics' `coreloop.jl` (a number's conversion). The two scripts of the forks' closed experiments (`forks/scripts/d3_refcodes.jl`, `m7_stage_split.jl`; E-214, E-217) call `compiled_for(d)`, which is now the wrapper, not the cast they were written for: kept as history, not run.
