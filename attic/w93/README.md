# W-93: TraitWorld fixes the ports found (E-244, and the branch's checks)

W-93 builds open issues 128, 124, 127, 121, 120 and 123 and retires lowering L-46 on TraitWorld's branch `w93` (worktree `../../TraitWorld-w93`). Registry row: [`experiments.md`](../../writeup/record/experiments.md) E-244. Current numbers: [the evidence](../../writeup/design/evidence.md).

## How to run

Every Julia job under `experiments/tools/jl` (slots, a private depot stacked before `~/.julia`), with a kill timeout.

- `rejections_df.jl [Pkg,…]`: loads the packages (default `CSV,DataFrames,Statistics,Dates`) with the compiler's validation log on and counts the image CodeInstances rejected at load, by package of the code and by the methods that broke the edge (E-238's reading, without the entries for folds and bindings that hold, E-243). The last line counts DataFrames' code rejected by methods TraitWorld's `@trait` defines.
  `jl --name w93 julia --project=<env> rejections_df.jl`, with `<env>` a copy of `forks/env_forks` whose paths are absolute and whose TraitWorld is main or the worktree.
- `checks.sh <tag> <scratch>`: the branch's checks. TraitWorld's suite (product setting and the test bed `all`), the acceptance suite (both), TraitTables, TraitCSV, TDE and TraitMakie (`Pkg.test()`) from scratch copies of the demonstrators beside a link `TraitWorld -> ../TraitWorld-w93`, TDE's session (`RESULT` lines against `../w81/x1/session-x1-one-function.log`), the forks' session digests (`forks/scripts/check_session.sh` with the scratch env). Logs: `../checks/logs/w93/<tag>/`.

## E-244, 2026-10-29

julia-1.13 bfca89decc, forks 943b065; TraitWorld main d22ec7b (before) and `w93` from d749ec9 (after). Product setting, strict mode off. The loads only, 1 run each (`logs-rejections-main.log`, `logs-rejections-w93.log`).

| | before (d22ec7b) | after (w93) |
|---|---|---|
| image CodeInstances rejected at load | 949 | 719 |
| rejected through a method `@trait` defines (CSV's subtraits on `Column`'s `vector`, `nrows`, `cell`): DataFrames / Base / Statistics | 176 / 160 / 23 | 0 / 0 / 0 |
| DataFrames' code rejected in all | 225 | 185 |

- A CodeInstance is counted once, by one broken edge. Most of DataFrames' 176 have another broken edge to an ordinary method: after the change they are counted by CSV's `propertynames` (111) and DataStrings' `convert` (74).
- PrettyTables' 450 are unchanged (CSV's `eltype`, PooledArrays' `convert`).

## The branch's checks, 2026-10-29

julia-1.13 bfca89decc; TraitWorld `w93` 4579236; TDE 388cb33, TraitMakie c0d5c36, TraitTables 438ac2b, TraitCSV 9c6477b, forks 943b065 (scratch copies). `../checks/logs/w93/branch2/`, summary `../checks/logs/w93/branch2-summary.log`:

- TraitWorld's suite passes in the product setting and under the facts image; the acceptance suite 35 of 35 in both.
- TraitTables, TraitCSV, TDE and TraitMakie: `Pkg.test()` passes. TraitMakie's precompilation under `--depwarn=yes` prints no deprecation warning (208 of Cairo's on main, `../checks/logs/merge-w91/TraitMakie.log`).
- TDE's session: the 9 `RESULT` lines identical to `../w81/x1/session-x1-one-function.log`.
- The forks' session: digests equal at 26 steps; the REPL 20 marks, 0 errors.

An earlier run (`branch/`, 68239d6) linked `TraitWorld` into the copies; Pkg's test sandbox refuses that path, and TDE's suite then showed that a wrong result's error path behind an inference barrier hid the member check's refusal (fixed in 4579236).
