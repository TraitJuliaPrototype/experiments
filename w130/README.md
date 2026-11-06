# Open issue 130: a call with keywords reaches the fallback (TraitWorld branch `w130`)

Open issue 130 is built on TraitWorld's branch `w130` (worktree `../../TraitWorld-w130`). The design: [traits §5.7](../../attic/writeup/reference/traits.md#57-keywords-defaults-and-varargs), [lowering §10](../../attic/writeup/reference/lowering.md#10-keywords-defaults-and-varargs), deviation L-48.

## How to run

Every Julia job under `experiments/tools/jl`, with a kill timeout.

- `repro.jl`: NetworkDynamics' case in small. `NWState(int::(IntegratorView, HasSystem))`, a bounded constructor without keywords, beside `NWState(thing; ufill, guess)` and the inner `NWState(thing, uflat::AbstractVector)`; the same shape as a function, `nwstate`.
  `jl --name w130 julia-1.13/julia --project=<TraitWorld> experiments/w130/repro.jl`. Logs: `repro-main.log` (TraitWorld main 4579236), `repro-w130.log` (the branch).
- `mixed.jl`: bounded methods of one shape, one with keywords and one without, in both orders (refused on the branch, lowering L-48).
- `checks.sh <tag> <scratch>`: the branch's checks, from `../w93/checks.sh`. The scratch directory holds `demos/` (copies of TraitTables, TraitCSV, TDE and TraitMakie whose TraitWorld paths name the worktree, absolute) and `forks-w130/` (a copy of `forks/env_forks` likewise). Logs: `../checks/logs/w130/<tag>/`.

## Results, 2026-10-29

julia-1.13 bfca89decc; TraitWorld main 4579236 (before) and `w130` f270262 (after).

`repro.jl`:

| call | main | w130 |
|---|---|---|
| `NWState(nw; ufill = 3.0)`, `NWState(nw; guess = true)` | `MethodError` | the untyped constructor |
| `nwstate(nw)` (calls `NWState(thing; ufill, guess)`) | `MethodError` | the untyped constructor |
| `nwstate(int)`, `nwstate(Dynamic{IntegratorView}(int))` | the bounded method | the bounded method |
| `nwstate(int; ufill = 3.0)` | `MethodError` | the untyped method, as in Julia (it then raises: `extract_nw` has no method for the integrator) |
| `NWState(int)` | `UndefRefError` | `UndefRefError` |

- The keyword part of NetworkDynamics' case works on the branch.
- A bounded method of a type's constructor does not, on main or the branch: the machinery keys entries by `typeof(f)` (`UnionAll` for `NWState`) and reads the function as `F.instance`. A separate case.

`mixed.jl` (`mixed-main.log`, `mixed-w130.log`): on main, with the method without keywords first, every call with keywords raises `MethodError`; with the method with keywords first, a value of the other trait raises `TraitUseError`, with keywords or without. On the branch both orders are refused at definition (`TraitBoundError`, L-48).

## The branch's checks, 2026-10-29

julia-1.13 bfca89decc; TraitWorld `w130` f270262; TDE 282edb3, TraitMakie c0d5c36, TraitTables 438ac2b, TraitCSV 9c6477b, forks 943b065 (scratch copies). `../checks/logs/w130/branch/`, summary `../checks/logs/w130/branch-summary.log`:

- TraitWorld's suite passes in the product setting and under the facts image (the facts depot first); the acceptance suite 35 of 35 in both.
- TraitTables, TraitCSV, TDE and TraitMakie: `Pkg.test()` passes.
- TDE's session: the 9 `RESULT` lines identical to `../w81/x1/session-x1-one-function.log`.
- The forks' session: digests equal at 26 steps; the REPL 20 marks, 0 errors.
- The new test set alone, on main and on the branch: `../checks/logs/w130/newtests-main.log` (12 of 20 fail or error), `newtests-branch.log` (an earlier state of the branch; the suite logs above hold the final one).
