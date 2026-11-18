# Lowering L-50 (TraitWorld branch `l50`)

Lowering deviation L-50: a bounded method of a type's constructor at the signature of an ordinary constructor (one of Julia's default constructors, or an untyped inner one). It is built on TraitWorld's branch `l50` (worktree `../../TraitWorld-l50`), from `main` 4961de8. The design: [lowering §8.1](../../attic/writeup/reference/lowering.md#81-the-rewrite), [traits §5.5](../../attic/writeup/reference/traits.md#55-dispatch-types-first-then-traits).

The mechanism: when the entry is defined, the constructor at its signature and that constructor's keyword sorter are taken out of the method table (`Base.delete_method`). A tagged method takes each one's place, `S(::Untyped, args…)` and `Core.kwcall(nt, ::Type{S}, ::Untyped, args…)`. It calls the constructor by `invoke` with the method itself.

## How to run

Every Julia job runs under `experiments/tools/jl`, with a kill timeout.

- `probe/DelCtor`: does Julia let a package's precompilation take out a method that the package itself defined? Run it as a package: `JULIA_LOAD_PATH=probe:@stdlib jl --name l50 julia-1.13/julia -e 'using DelCtor'`. Log: `../checks/logs/l50/probe-delctor.log`.
- `session.jl`: the cases in a session: Julia's default constructor (`A(x)` converting, parametric `B(x::T)`), an untyped inner constructor with keywords, an inner constructor with a typed argument, a bounded method with keywords, a typed caller. `jl --name l50 julia-1.13/julia --project=<TraitWorld> session.jl`.
- TraitWorld's `test/constructors.jl`, run alone. Logs: `../checks/logs/l50/constructors-test.log` (branch), `constructors-test-before.log` (the same file against `main`).
- `../w130/repro.jl`: NetworkDynamics' `NWState` case. Log: `../checks/logs/l50/repro-w130.log`.
- `checks.sh <tag> <scratch> [demos]`: the branch's checks, from `../w131/checks.sh`. The scratch directory holds `demos/` and `forks-l50/`, copies whose TraitWorld paths name the worktree. Logs: `../checks/logs/l50/<tag>/`.

## Results, 2026-10-29

julia-1.13 bfca89decc; TraitWorld `main` 4961de8 (before), `l50` 33dd55e.

The probe (`probe-delctor.log`): `Method deletion is not possible during Module precompile`.

The probe: Julia refuses both ways while it writes a package image. `Base.delete_method` raises `Method deletion is not possible during Module precompile` (`jl_method_table_invalidate`, `src/gf.c`). Replacing a method at the same signature raises `Method overwriting is not permitted during Module precompilation` (`method_overwrite`). So in a package image the bounded method is still refused when it is defined (L-50 stays, narrowed to images). The image writer already writes a disabled method entry as dead (`staticdata.c`, "garbage newentry"), so a Julia change that lets a package take out a method it defined itself in this session looks small.

In a session (`session.jl`, the test file's new test sets): every case works, the default constructor's conversion included (`A(2.0) == A(2)`, `A(2.5)` raises `InexactError`).

| test set | `main` | `l50` |
|---|---|---|
| open issue 131: a bounded constructor (27 tests) | 27 pass | 27 pass |
| lowering L-50: the constructor at the entry's signature is its fallback (26) | the module refused (`KA`'s default constructor) | 26 pass |
| a bounded constructor compiled ahead in a package image (3) | not reached | 3 pass |
| lowering L-50: refused while Julia writes a package image (2) | not reached | 2 pass |

`repro.jl`: every line as on `w131` (`../w131/repro-w131.log`).

The checks (`checks.sh branch`, `l50` 33dd55e; TDE e9e07ed (its suite and session rerun on a fresh copy; first run on w131's copy at 282edb3, also passing), TraitMakie c0d5c36, TraitTables 438ac2b, TraitCSV 9c6477b, forks 943b065, scratch copies on disk; `../checks/logs/l50/branch/`, summary `../checks/logs/l50/branch-summary.log`):

| check | result |
|---|---|
| TraitWorld's suite, product setting and the test bed `all` | pass, pass |
| acceptance suite, both settings | 35 of 35, 35 of 35 |
| TraitTables, TraitCSV, TDE, TraitMakie (`Pkg.test()`) | pass |
| TDE's session | 9 `RESULT` lines identical |
| the forks' session digests | equal, 26 steps; 20 marks, 0 errors |
