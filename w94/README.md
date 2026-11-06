# W-94: facts code "rejected at load" by another package's implementation (E-243)

Open issue 126 asks why the member-fold `conformance(::As{Column}, ::Vector{…})` CodeInstances of the facts owner that E-238 counted as rejected at load are rejected when CSV's `@implement CSVColumn A where {A <: Vector}` loads, and whether [facts §2.2](../../attic/writeup/reference/facts.md#g2) needs an exception. Registry row: [`experiments.md`](../../writeup/record/experiments.md) E-243. The analysis: [`../../writeup/plans/2026-10-29-w94-facts-rejected-by-implementation.md`](../../writeup/plans/2026-10-29-w94-facts-rejected-by-implementation.md).

## How to run

Every job through `experiments/tools/jl --name w94`, under a kill timeout.

- `validity.jl [Pkg,…]` (`--project=forks/env_forks`): loads the packages with the compiler's validation log on (`Compiler.ReinferUtils.debug_method_invalidation`), and counts the log's `insert_backedges_callee` entries by the kind of edge, against whether the named CodeInstance is valid after the loads (`max_world` typemax).
- `diag.jl [Pkg,…]`: for each logged fold, the fold's value at load against the stored value, and the member's image records (`_member_record`): found, holding, which signature selects other methods.
- `diag_atload.jl [Pkg,…]`: a tracing copy of `TraitWorld._member_fold_at_load` (in the session only): what each fold evaluated at load does (registry hit, from the record, fixed again).
- `repro.jl` (`--project=TraitWorld`): the minimal case. Package FamT declares `Col` with a family implementation over `AbstractVector` and a workload whose trait code folds the member `Vector{Int}`; package SubT declares `SubCol <: Col` and implements it for every `Vector`. A fresh session loads FamT, then SubT, and reports the log's entries, the validity of the fold's CodeInstance, the `verify_methods` entries (code rejected), and whether the first call compiles it again.
- `patch_verify.jl`: with `W94_PATCH=<julia-1.13-w94>/Compiler/src/reinfer.jl`, `validity.jl` and `repro.jl` run the branch `w94`'s image validation without a build: its `verify_method` evaluated into the running Julia, validation called in the latest world, and `Base._require_world_age` moved so that `require` sees the copy.

## E-243, 2026-10-29

julia-1.13 bfca89decc (and the branch `w94`, unbuilt, by `patch_verify.jl`), TraitWorld main d22ec7b (not edited), forks main 943b065. Product setting, strict mode off. Loads only, no timing; 1 run each.

| Run | Log | Result |
|---|---|---|
| `validity.jl Tables,CSV` | `logs/validity-forks.log` | fold entries 12, all 12 CodeInstances valid; binding entries 5, all valid; 1 call edge, invalid |
| `validity.jl CSV,DataFrames,Statistics,Dates` (E-238's loads) | `logs/validity-forks-session.log` | fold entries 37, all valid; binding entries 33, all valid; call edges 53 (5 MethodInstance, 48 signature), all invalid |
| `diag.jl Tables,CSV` | `logs/diag-forks.log` | each logged fold gives the stored value again (egal); each member's record holds |
| `diag_atload.jl Tables,CSV` | `logs/diag-atload-forks.log` | each fold at load: a registry hit (a builder saved with the declaring image) or fixed from the image's record; none fixed again |
| `repro.jl` | `logs/repro.log` | FamT's own load logs its fold (before SubT exists); SubT's load logs SubT's fold; both valid; no `verify_methods` entry; the first call compiles nothing for `conformance(As{Col}, Vector{Int})` |
| `repro.jl`, `W94_PATCH` | `logs/repro-patched.log` | no fold entry logged; the rest as above |
| `validity.jl` E-238's loads, `W94_PATCH` | `logs/validity-forks-session-patched.log` | no fold entry; bindings 33 (valid), call edges 53 (invalid), as before |
| `repro.jl` on julia-1.13 00dcc9994c (`w94` merged and built, 2026-10-29, TraitWorld 33dd55e) | `logs/repro-built.log` | no fold entry logged; the rest as above |

**Finding.** Nothing is rejected. Image validation logs an `insert_backedges_callee` entry for every edge whose validity bound is not `typemax(UInt)` (`julia-1.13/Compiler/src/reinfer.jl:286`). A fold that holds is given the validation world as its bound (`reinfer.jl:246`), so every fold is logged, holding or not; a binding without partitions likewise (Julia's own code). E-238's `rejections.jl` and `census.jl` counted every such entry as a rejection: 70 of the 1,010 CodeInstances (37 by a fold, 33 by a binding), among them the 30 of Tables' methods and the 5 of CSV's that open issue 126 names. The 940 others are rejected: each failed call edge's CodeInstance is invalid after the loads, and validation writes a `verify_methods` entry only for code it made invalid (`reinfer.jl:346`).
