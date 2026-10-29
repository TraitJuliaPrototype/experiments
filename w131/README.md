# Open issue 131 and lowering L-49 (TraitWorld branch `w131`)

Open issue 131 (a bounded method of a type's constructor) and lowering deviation L-49 (a bound's `where` variable read as a module global) are built on TraitWorld's branch `w131` (worktree `../../TraitWorld-w131`), from `w130`. The design: [lowering §8.1](../../writeup/reference/lowering.md#81-the-rewrite), [traits §5.5](../../writeup/reference/traits.md#55-dispatch-types-first-then-traits), deviation L-50.

## How to run

Every Julia job under `experiments/tools/jl`, with a kill timeout.

- `../w130/repro.jl`: NetworkDynamics' case in small, `NWState(int::(IntegratorView, HasSystem))` beside `NWState(thing; ufill, guess)` and the inner `NWState(thing, uflat::AbstractVector)`.
  `jl --name w131 julia-1.13/julia --project=<TraitWorld> experiments/w130/repro.jl`. Log: `repro-w131.log` (before: `../w130/repro-main.log`, `../w130/repro-w130.log`).
- `../w34-sciml/r118/probe_shadow.jl`: L-49's case. Log: `probe-shadow-w131.log` (before: `../w34-sciml/r118/logs/probe-shadow-1.log`).
- The new tests, TraitWorld's `test/constructors.jl` and `test/wherevars.jl` (its last test set), run alone. Logs: `constructors-test-w130.log`, `wherevars-test-w130.log` (the files against `w130`), `newtests-w131.log` (both against `w131`).
- `checks.sh <tag> <scratch>`: the branch's checks, from `../w130/checks.sh`. The scratch directory holds `demos/` (copies of TraitTables, TraitCSV, TDE and TraitMakie whose TraitWorld paths name the worktree, absolute) and `forks-w131/` (a copy of `forks/env_forks` likewise). Logs: `../checks/logs/w131/<tag>/`, summary `../checks/logs/w131/<tag>-summary.log`.

## Results, 2026-10-29

julia-1.13 bfca89decc; TraitWorld `w130` f270262 (before), `w131` ea897b1 (open issue 131) and 4961de8 (L-49).

`repro.jl`: `NWState(int)` raised `UndefRefError` on `w130`; on `w131` it calls the bounded method, `(Net(2), [1.0, 2.0])`. `NWState(nw; ufill = 3.0)`, `NWState(nw; guess = true)` and `NWState(nw, [5.0, 6.0])` reach the ordinary constructors, as on `w130`. The other lines are unchanged.

`probe_shadow.jl`: `ixof(A())` with the `where` variable `I` beside LinearAlgebra's `I` raised `TraitBoundError` (`Ix{LinearAlgebra.UniformScaling{Bool}(true)}`); on `w131` it returns `Symbol`.

The new tests:

| test set | `w130` | `w131` |
|---|---|---|
| open issue 131: a bounded constructor (29 tests) | 10 pass, 5 fail, 14 errors | 29 pass |
| a bounded constructor compiled ahead in a package image (3) | not reached | 3 pass |
| lowering L-49: a where variable shadows a module global (4) | 1 pass, 3 errors | 4 pass |

The image test's check of the workers' machine code fails when compiling ahead is turned off (`JULIA_TW_AHEAD=0`: `NATIVE 0 0`), so it measures compiling ahead.

The checks (`checks.sh branch2`, `w131` 4961de8; TDE 282edb3, TraitMakie c0d5c36, TraitTables 438ac2b, TraitCSV 9c6477b, forks 943b065, scratch copies; `../checks/logs/w131/branch2/`, summary `../checks/logs/w131/branch2-summary.log`):

| check | result |
|---|---|
| TraitWorld's suite, product setting and the test bed `all` | pass, pass |
| acceptance suite, both settings | 35 of 35, 35 of 35 |
| TraitTables, TraitCSV, TDE, TraitMakie (`Pkg.test()`) | pass |
| TDE's session | 9 `RESULT` lines identical |
| the forks' session digests | equal (26 steps, 20 marks, 0 errors) |

The first run (`branch`) passed the suites and the acceptance suite; its demonstrators' runs failed in `Pkg.test` because the scratch copies' Manifests still named the `w130` worktree (Pkg's `AssertionError` on the path), not a test.
