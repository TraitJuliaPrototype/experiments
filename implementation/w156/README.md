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
