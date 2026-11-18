# W-166: the demonstrators' programs build again as trimmed binaries (E-507)

**The question** (registry row E-507): do the demonstrators' programs build as trimmed binaries on the head once the
equations' functions answer at the kept forms (traits T-130, lowering L-67) and the loops hand a member over as the
wrapper `compiled_for(x)` (open issue 242)? Does the ODE program's build reach its verifier once code that runs while
a build loads is compiled as in a session (open issue 241)? What would change the design: a loop that the wrapper does
not serve in a build, or a session that pays for the wrapper.

## How to run

```sh
source experiments/implementation/w166/env.sh        # the workspace's env.sh, a depot of this work's own, $JN, $W156
cd experiments/implementation/w166
(cd ../../../TraitWorld && $JN --project=. ../experiments/implementation/w166/probes/t130.jl)   # stage 1's probe
$JN --project=$W156/env_demo probes/kept_tables.jl      # TraitTables' column code at a plain column, a box, a wrapper
bash suites.sh <label> tables csv report …               # W-156's suites.sh with this directory's depot and logs
bash sessions.sh <tag> 3                                 # W-156's regression control (report, table session)
bash small.sh <label> [tree]                             # E-384's eight small trait programs: build, run, compare
JULIA_TREE=julia-next NAME=w166-<name> bash ../w135/build.sh table $W156/env_demo   # a demonstrator's program
python3 ../w135/summarize.py ../w135/logs/w166-<name>.build.log
```

- `probes/t130.jl`: `eltype` (value and type), `zero(eltype(t))`, `Vector{eltype(t)}` and the inferred result at a
  plain member, a box, a box of a subtrait, the wrapper; `keytype`/`valtype` of `Keyed`; a box of an intersection.
- `probes/kept_tables.jl`: W-156's probe, with the library's `compiled_for`.
- `small.sh` builds with `../w139/build.sh`; its build logs are `../w139/logs/w166-<label>-<app>.build.log`.
- The programs' build logs are `../w135/logs/w166-*.build.log` (`build.sh` writes there).
- Builds run with `ulimit -c 0`: a crashed build leaves no core file.

- `build_app.sh <tree> <app.jl> <name> [project]`: a trimmed build of any app file (the command of `../w139/build.sh`);
  log `logs/<name>.build.log`. The apps of `apps/`:
  - `loadrun_trait.jl`, `loadrun_many.jl`, `loadrun_plain.jl`: trait code (and a plain control) run while the build loads
    the program (open issue 241);
  - `loadrun_lapack.jl`, `loadrun_lapack_init.jl`: a LAPACK call while the build loads (plain Julia: the build's process
    does not run OpenBLAS_jll's and LinearAlgebra's `__init__`), and the same with them called first;
  - `ode_blas.jl`: E-361's ODE program with BLAS forwarded first (a probe: past plain Julia's limit to the verifier);
  - `hookcheck.jl`: whether the build defines a method at an erasing trait as a session does (the library's hooks).

## Results, 2026-11-18

Julia `julia-next` (`next` 4bf381040c) for stages 1 and 2; `wt/w166-julia` (branch `w166`: 521c1faced, 803060c332) for
stage 3. TraitWorld `w166` a8d11af (stage 1), 1c6cca4 (stage 3); TraitTables `w166` a69eb6c; TraitCSV `w166` 8c307d0.
Before: TraitWorld `unified` 6ad7098, TraitTables 729f3ad, TraitCSV c95c67c. Product setting, strict mode off, one
thread, one build at a time; load 2 to 12 of 128.

**Stage 1, the equations' functions at the kept forms** (traits T-130, lowering L-67; `logs/s1-*`).
- `probes/t130.jl`: `eltype` of a box of `Iterable{Float64}`, of a box of `MutableIndexable{Float64}`, of a box of
  `All{Iterable{Float64}, Indexable{Float64}}` and of the wrapper is `Float64`, at the value and at the type;
  `zero(eltype(t))` is `0.0` and inferred `Float64` at each; `keytype`, `valtype` of a box of `Keyed{String, Int}` and of
  the wrapper of a `Dict` answer as for the `Dict`.
- `probes/kept_tables.jl`: `take`, `sortby` of a boxed or wrapped `Vector{Float64}` column give a `Vector{Float64}`
  (W-156's run: `Vector{Any}`).
- The library: 92 testsets pass (one new). The gates on julia-next: 72 of 72, 9 of 9 stage gates.

**Stage 2, the loops hand a column over as the wrapper** (open issue 242; `logs/s2-*`, `logs/sessions-*`).

| | before (`unified`) | after (`w166`) |
|---|---|---|
| TraitTables' suite | 26 pass, 3 testsets | 27 pass, 3 testsets |
| TraitCSV's suite | 16 pass, 2 testsets | 16 pass, 2 testsets |
| the test "a column's code per column type", w166's tests on `unified`'s loops | — | fails (`s2-discriminate-*.log`) |
| the table program, `--trim=safe` on julia-next | 28 errors | 6 errors (`../w135/logs/w166-table-s2.build.log`) |
| the same, `--trim=unsafe-warn` | — | 2,480,216 bytes; stops: `MethodError: fillcolumn(::Compiled{Vector{Int64}}, …)` |
| the report's, the plot's program | — | segfault while Colors loads, the same with the library at `unified` (`w166-plot-ctl-unified`) |
| E-384's eight small trait programs | — | build, run, output equal; 2.06 to 2.24 MB (`s2-small.log`) |

The 6 errors are 3 calls, each reached twice: `floats(φ::Compiled, skipmissing)` (TraitTables.jl:51),
`summarize(φ::Compiled, …)` (TableCore.jl:189), `fillcolumn(φ::Compiled, s, spans)` (CSVCore.jl:126). The wrapper's
constructor branches over the program's five column types (`Vector{Int}`, `Vector{Float64}`, the two with missing
cells, `Vector{String}`), and the call that takes the wrapper is at the join of the branches, widened to `Compiled`:
nothing splits it. E-384's `barrier_trait` (two members) builds: the join stays a union of two.

The sessions' control (`sessions.sh`, a warm-up and 3 runs each, fresh processes, julia-next; load 2.4 to 4.2):

| | before | the library alone (`w166`, the loops of `unified`) | after |
|---|---|---|---|
| the table session: wall | 0.651–0.659 s | 0.656–0.662 s | 0.685–0.692 s |
| its load; first run, of it compiling | 347–351 ms; 54.0–54.3 ms, 53.3–53.5 ms | 352 ms; 54.0–54.3, 53.3–53.6 | 362–365 ms; 55.9–56.3, 54.9–55.4 |
| its compiles | 19, 169 ms | 19, 169 ms | 19, 178 ms |
| the report: wall; load | 1.018–1.043 s; 557–585 ms | 1.026–1.149 s; 570–683 ms | 1.028–1.073 s; 567–585 ms |
| its first run, of it compiling; compiles | 109–117 ms, 51.2–51.5 ms; 25, 217 ms | 109–112, 51.3–52.5; 25, 220 ms | 113–117, 51.2–53.1; 25, 233 ms |
| instances TraitTables, TraitCSV, TraitWorld (table) | 103, 29, 382 | 104, 29, 396 | 131, 34, 417 |

The table session's load is 10 to 13 ms longer with the wrapper: the images hold the instances at `Compiled{…}` of the
column code and of the operations' forwarding methods (`cell`, `nrows`, `parsecell!` at the wrapper:
`s2-kept-instances-table.txt`, 57 at a kept form).

**Stage 3, code a build runs while it loads** (open issue 241; `logs/s3-*`, `logs/loadrun-*`, `logs/ode-blas-*`).
- `loadrun_trait.jl` (E-364's loop run at the top level): julia-next stops at load, `MethodError: no method matching
  label(::Rect)`; `w166` builds, 2,227,720 bytes, runs. `loadrun_many.jl` (six members) builds on both.
- The library's hooks: a trimmed build runs no package's `__init__` while it loads (Julia runs them when the binary
  starts), and the runtime called no library hook in an output that is not incremental. `hookcheck.jl`: a method at
  `Callable{Tuple{Int}, Int}` is 1 method in the build, 3 in a session; with 803060c332 and TraitWorld 1c6cca4, 3.
- The ODE program as written (`../w135/logs/w166-ode-s3b.build.log`): a segfault while TraitNonlinearSolve's workload
  runs, a LAPACK call through a null pointer (`logs/s3-gdb-nls.log`: `getrf!`). Plain Julia's: `loadrun_lapack.jl`
  crashes the same on vanilla v1.13.2; the build's process does not run OpenBLAS_jll's and LinearAlgebra's
  `__init__` (`loadrun_lapack_init.jl` builds once they are called).
- `ode_blas.jl` (the ODE program, BLAS forwarded first): reaches the verifier, 13 errors
  (`logs/ode-blas-w166-julia-b2-lib.build.log`): 7 in `OpenSpecFun_jll.__init__` (Artifacts' `invokelatest`, Base's
  `issorted` with an `Lt`/`By` order), 6 in the program: `_problem_of(f::Dynamic{Callable{…}}, getfield(f, :object)::Callable{…}, …)`
  (ODECore `frontend.jl:69`, from `ODEProblem` for `lorenz!` and `robertson!`) and the two `solve` calls that take its result.
  On julia-next the same probe stops at load (`MethodError: solve_nl(…)`).
- Checks on `wt/w166-julia`: the gates 72 of 72, 9 of 9; Base's subtype, core, ambiguous, worlds, Compiler/inline,
  Compiler/inference SUCCESS, `detect_ambiguities(Base)` 0; the library 92 testsets; the static check of GC roots on
  `gf.c` 0 findings; the table program 6 errors (`../w135/logs/w166-table-s3.build.log`); E-384's eight programs build
  and run, equal (`s3-small.log`; each build 16 s where it took 10: the hooks run while the build loads).

**At the end** (julia-next, TraitWorld 1c6cca4, the demonstrators' `w166`; `logs/final-*`): the gates 72 of 72, 9 of 9;
TraitTables 27 pass, TraitCSV 16; TraitReport `check.sh` 3 of 3, its session 8 of 8; TraitMakie 8 testsets, its
session 10 of 10; TraitDifferentialEquations 35 testsets, its session 14 checks ok, results equal the plain session's;
the forks' Tables 1 error (`ByRow(Dict)`, open issue 240); the forks' digests equal at 26 steps; the examples: intro 26,
tutorial 95, strict 5 pass, 1, 0, 0 known deviations; NetworkDynamics' subset: the known failures only
(`final-nd-summary.log`).

## The second part: a call that takes the wrapper branches over the members (compiler §7.6, C-150), 2026-11-18

**The question** (registry row E-508): does a closed build that splits a call taking the wrapper of a value known
only by its trait over the members' wrappers build the table program with 0 errors, with nothing changed for a
session or for plain code?

**What was wrong.** The wrapper's constructor `Compiled(x)` at `x::X` branches over `X`'s members in a closed build.
The join of its branches, `Compiled{M1}` … `Compiled{M5}`, went through Julia's limit on a union's length
(`tmerge_types_slow`, `MAX_TYPEUNION_LENGTH = 3`) and was widened to the wrapper's bare type `Compiled`, which no
longer names `X`. The call that took it was left to dispatch. With two members the join stays a union, and Julia's
union split serves the call.

**The change** (`wt/w166-julia`, branch `w166`, f5328f94c5; `Compiler/src/abstractinterpretation.jl` only):
- a closed split over a set's members whose branches each return the wrapper of a member of `X` is typed
  `Compiled{<:X}` where the join is wider (the join met with `Compiled{<:X}`, checked per branch in
  `abstract_call_gf_by_type`); a union of up to three wrappers stays a union;
- a call that takes an argument typed `Compiled{<:X}` is split by `closed_member_split`, as the constructor's call:
  one branch per member's wrapper `Compiled{M}` (`closed_member_types`, at most 64), past them `MethodError`. A box or
  a wrapper gives no branch, since the constructor unwraps both;
- an instance with such a call is noted for the build's rounds, as one with a call at a set argument.
Only `closed_build(interp)` reads it. Tried first in a session with `../w156/tools/cc_patch.jl` (`probes/b_patched.jl`).

**How to run.**
```sh
source env.sh
(cd ../../../TraitWorld && $TW_ROOT/wt/w166-julia/julia --project=. ../experiments/implementation/w166/probes/b_join.jl)  # five members
PATCH=1 $JN --project=$W156/env_demo probes/b_table_check.jl     # the table's main, the build's check in a session
bash build_app.sh wt/w166-julia apps/wrap5.jl b-wrap5-w166-julia  # five members, trimmed
JULIA_TREE=wt/w166-julia NAME=w166b-table bash ../w135/build.sh table $W156/env_demo
```

**Results.** Julia `wt/w166-julia` f5328f94c5 (on `next` 803060c332), control `julia-next` 803060c332; TraitWorld `w166`
9d4f782; TraitTables a69eb6c, TraitCSV 8c307d0. One thread, one job at a time, load 3 to 12 of 128.

| | julia-next | w166 |
|---|---|---|
| the table program, `--trim=safe` | 6 errors (`../w135/logs/w166-table-main.build.log`) | 0 errors, 2,724,000 bytes, object 26 s (`../w135/logs/w166b-table.build.log`) |
| its binary on the 500-row file | — | exit 0, 0.05 s, output equal to the tag's (`../w135/logs/table-binA.bin.out`): `logs/b-table-bin.out` |
| the build's report | — | 1 round; `Column`, `CSVColumn` 5 members each (`../w135/logs/w166b-table-report.build.log`) |
| `apps/wrap5.jl` (five members, `compiled_for` in a loop) | 4 errors: `scaled`, `ar5` at the wrapper | 0 errors, 2,174,736 bytes, runs, output equal to the session's |
| `probes/b_join.jl`: `verify_main` holes, `fully_typed` | 1 hole, not fully typed | none, fully typed (`logs/b-probe-join-*.log`) |
| the table's `main`, the build's check in a session | 3 calls | 0 (`logs/b-probe-table-check-w166-julia.log`) |
| the library's test "the wrappers of five members" | 2 of 4 fail (`logs/b-verify-julia-next.log`) | 4 pass |

- The wrappers are forgotten at `Compiled{<:Column}` and `Compiled{<:CSVColumn}` (the report lists them); they do not
  become members of either set.
- E-384's eight small programs on w166: build with 0 errors, run, output equal (`logs/b-small.log`).
- Checks on w166: the gates 72 of 72, 9 of 9 stage gates (`logs/b-gates.log`); Base's core, subtype,
  Compiler/inline, Compiler/inference SUCCESS (`logs/b-base-summary.log`); the library 93 testsets (one new,
  `logs/b-library.log`); TraitTables 27 pass, TraitCSV 16 (`logs/b-TraitTables.log`, `logs/b-TraitCSV.log`).
- The sessions (`sessions.sh`, a warm-up and 3 runs, `logs/sessions-b-*.log`): compiles and instances equal.

| | julia-next (`b-before`, `b-before2`) | w166 (`b-after`, `b-after2`) |
|---|---|---|
| table: compiles; instances TraitTables, TraitCSV, TraitWorld | 19, 169–178 ms; 131, 34, 417 | 19, 168–170 ms; 131, 34, 417 |
| table: load; first run, of it compiling | 353–367 ms; 53.4–55.3 ms | 350–353 ms (`b-after2`); 53.1–54.4 ms |
| report: compiles; load | 25, 217–232 ms; 573–596 ms | 25, 218–241 ms; 571–575 ms (`b-after2`) |

  The first run on w166 (`b-after`) loaded in 394–421 ms (table) and 796–1013 ms (report): the images the warm-up had
  just written; `b-after2`, run at once after, is at julia-next's times.

**Not covered.** A value `Compiled{Dynamic{X}}` or `Compiled{Compiled{M}}` (made with the inner constructor
`Compiled{T}(x)`, never by `Compiled(x)`) reaching a call typed `Compiled{<:X}` takes the split's `MethodError` in a
build (reasoned from the code, not run). A call that takes two wrappers splits over the first; the second stays
`Compiled{<:Y}` in each branch's instance, whose own calls at it split: `probes/b_two.jl` is fully typed in the
build's check in a session (`logs/b-probe-two-w166-julia.log`); not built as a binary.
