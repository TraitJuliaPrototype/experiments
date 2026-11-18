# W-165: two instances of one set meet where a member is in both (E-503)

The question (registry row E-503): with two instances of one set meeting where they differ only in inputs
(compiler §4.9, C-147), does a call at a member of both report its ambiguity, and does anything else change: Base's
`subtype`, `core`, `ambiguous`, `worlds`, `detect_ambiguities(Base)`, the gates, the suites? And C-148: the lookup that
drops a match met only at an unmet intersection reports no ambiguity with it.

The build: branch `w165` of the julia repository (worktree `wt/w165-julia`), three commits on `next` a5bd871cce:
`7397ab6f70` (the rule), `a29ffdd428` (C-148), `02139b2168` (the one-instance check). The binary reports `02139b2168*`.

## How to run

From the workspace root, `source env.sh` first; one Julia job at a time.

| File | What it does | Run |
|---|---|---|
| `suites.sh` | the brief's checks on a built tree: Base's four test files, `detect_ambiguities(Base)`, the library's suite, the ODE library's, TraitMakie's, NetworkDynamics' subset, the forks' digests, the three example scripts (the commands of `w161/suites.sh` and `e262_suites.sh` with the tree's binary; a depot of its own) | `bash experiments/implementation/w165/suites.sh wt/w165-julia <label> [names]` |
| `census.jl` | pairs of methods of one function and arity that put two different instances of one parametric set at the same argument; per pair `Base.isambiguous` and the signatures' intersection | `<julia> --project=<env> census.jl [Package ...]` |
| `census_sanity.jl` | the census's control: two pairs it must find | `<julia> census_sanity.jl` (from this directory's parent: the path is relative to it) |
| `hasproperty.jl` | the library's `HasProperty{N, R}` (`N` an input): a type at two names, at one name, two instances at one name | `cd TraitWorld && <julia> --project=. ../experiments/implementation/w165/hasproperty.jl` |
| `probe_c148.jl`, `probe_final.jl` | the lookup at `(Callable, Int)` and at a bare `Z`; the final-pair test for (`AbstractString`, `Callable`) and (`AbstractString`, `Z`) | `<julia> --project=experiments/implementation <probe>` |
| `probe_specific.jl` | specificity and intersection of `Callable`'s instances | same |
| `probe_unmet_instances.jl` | the lookup at `HP{:a, Int}` with a method at `HP{:b, String}` met only at the unmet intersection, against two different sets | same |
| `probe_bare_entry.jl` | out of scope (open issue 238): an entry at the bare name of a set whose parameter is no input | same |

## Results

| Date | Build | What | Result |
|---|---|---|---|
| 2026-11-18 | `next` a5bd871cce (`julia-next`) | the census, Base and every port (`logs/census-*-head.log`) | 0 pairs in Base and Core, the library, the ODE library (with ODECore, TraitNonlinearSolve, TraitRodas), TraitMakie with TraitTables and TraitCSV, the forks (DataFrames, CSV, Tables), NetworkDynamics; the control finds its 2 (`logs/census-sanity-head.log`) |
| 2026-11-18 | `w165` 02139b2168 | the census again (`logs/census-*-w165.log`) | 0 pairs everywhere; the control's `apply` pair now ties (`PAIR true`), its pair with a method at the intersection does not |
| 2026-11-18 | `next` a5bd871cce | `hasproperty.jl` (`logs/hasproperty-head.log`) | `HasProperty{:a, Int} ∩ HasProperty{:b, String}` is `Union{}`; `prop` at a type at both names selects the method at `:b` silently |
| 2026-11-18 | `w165` 02139b2168 | `hasproperty.jl` (`logs/hasproperty-w165.log`) | the intersection is `All{HasProperty{:a, Int}, HasProperty{:b, String}}`; `isambiguous` true, the call a `MethodError`; a type at `:a` only keeps its method; `HasProperty{:a, Int} ∩ HasProperty{:a, String}` stays `Union{}`; a method at the intersection resolves the tie |
| 2026-11-18 | `w165` 02139b2168, load 3 to 5 of 128 | `../gates/run_all.sh wt/w165-julia` (`logs/gates-w165.log`) | gates in force 72 of 72, stage gates 9 of 9; the two flipped gates fail on the head (`logs/gates-head-flipped.log`) |
| 2026-11-18 | `w165` 02139b2168, load 3 to 5 of 128 | `suites.sh wt/w165-julia w165` (`logs/w165-summary.log`, a log per check) | Base's subtype, core, ambiguous, worlds: SUCCESS (16, 69, 8, 8 s; vanilla v1.13.2: SUCCESS, `../logs/e262-suites-vanilla.log`); `detect_ambiguities(Base)` 0; the library 93 testsets; the ODE library 35, passed; TraitMakie 8; NetworkDynamics as on the head (diffusion 1 fail 1 error, inhomogeneous 1 error, the same counts in `../w161/logs/*-summary.log`); the forks' digests equal, 26 steps; the examples: intro 24 pass, tutorial 94, strict 5, 0 fail |
| 2026-11-18 | `w165` 02139b2168 | Julia's static check of GC roots over `subtype.c`, `datatype.c`, `jltypes.c` (`../w163/sagc.sh julia-next wt/w165-julia …`; `logs/sagc-02139b2168.log`) | 0 findings |
| 2026-11-18 | both | `probe_unmet_instances.jl` (`logs/probe_unmet_instances-*.log`) | on the head the caller at `HP{:a, Int}` is static (the instances disjoint); on `w165` the lookup keeps the match at `HP{:b, String}` met only at the unmet `All{HP{:a, Int}, HP{:b, String}}` and reports an ambiguity, so the call is dynamic (its result still `:a`), as for two different sets `X1`, `Y1` on both builds: no final pair exists for two sets |
| 2026-11-18 | both | `probe_bare_entry.jl` (`logs/probe_bare_entry-*.log`) | unchanged: `S` at the bare `Z` is in `Z{1}` and `Z{2}`, `Z{1} ∩ Z{2}` is `Union{}` (`P` no input), `h(S())` selects `h(::Z{2})` without a report |
