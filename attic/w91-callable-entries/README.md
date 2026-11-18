# W-91: `Callable` entries a package image can keep (E-241)

[The note](../../writeup/plans/2026-10-29-w91-callable-entries-cacheable.md) has the cause and the choice. Registry row: [`experiments.md`](../../writeup/record/experiments.md) E-241. Current numbers: [the evidence](../../writeup/design/evidence.md).

## How to run

Every Julia run in a private depot (`W91_DEPOT`, stacked before `~/.julia`), against scratch environments: copies of `forks/env_forks` whose paths point to a worktree of the forks at e4093e4 and to TraitWorld, either at ca92f22 (before) or on the branch `w91` (after); the `_wl` copies also develop `W91Workload`.

- `census.jl`: included into a session. `census_snap()` at the load mark; `census()` lists TraitWorld's specializations without a hash made after it, and counts the other modules'; `census_entries()` lists the CodeInstances of `enter_callable` and `_callable_result` made after it.
- `forks_steps.jl`: the forks' session as a script, then the census (`DATA=../../forks/data julia --project=<env> forks_steps.jl`). `imports_census.jl`: the same over the imports alone.
- `W91Workload/`: a stand-in for a forks' workload: the session's two `ByRow` steps over columns with missing values, with functions of its own, precompiled.
- `session.sh <mode> <tag> <env> [runs]`: the forks' REPL session, E-233's harness (`../phase2-round/session.sh`) with the typing hints off. Modes: `time`; `wl` (with `W91Workload` loaded with the imports); `count` (as `wl`, with the census after the session). A warm-up, then `runs`; one line per run from `../phase2-round/parse.py`.

## 2026-10-29

julia-1.13 bfca89decc; TraitWorld ca92f22 (before) and `w91` 14ec5c8 (after); forks e4093e4. Product setting, strict mode off. Load average 1.4–3.1 (other agents' jobs). Measures idiomatic trait code's machinery: the entry of a function argument.

**The census** (`logs/census-forks-base.log`, `logs/count-*/count-1.out`). After the load, the forks' session makes 64 of TraitWorld's specializations without a hash (before the change):
- the `Callable` path: `enter_callable`, `_wrap_callable`, `_check_at_signature`, `_erased_at`, `_fptr`, `CObj`'s and `Erased`'s constructors, at `Type{Tuple{Union{Missing, Float64}}}` and `Type{Tuple{Union{Missing, Int64}, Union{Missing, Float64}}}`;
- `_callable_result` (the open result type) at the same tuples;
- the facts owner's `_family`, `_kept_at`, `_kept_narrowed` at `Type{Column{Union{Missing, Float64}}}` (a trait type with a `Union` in its key).

Of the session's compile roots only `enter_callable` and `_callable_result` are among them (E-233's trace). Other modules: 78, 66 of them Base's.

**What a session compiles of the entry** (`count`, one run after a warm-up, with `W91Workload`):

| | `enter_callable`: CodeInstances with machine code made in the session | inference-only | `_callable_result` |
|---|---|---|---|
| before | 2 (`Val{false}` at both signatures) | 2 | 2 |
| after | **0** | 2 | 2 |

**The session** (`session.sh`, hints off, seconds; wall / compiling; 6 runs each in three rounds of a warm-up and 2, `logs/wl-*`, `logs/sessions*.log`):

| | `select_filter` | `user_function` | steps | of it compiling | wall |
|---|---|---|---|---|---|
| with `W91Workload`, before | 0.463–0.478 | 0.271–0.299 | 1.75–1.83 | 1.29–1.36 | 3.60–3.92 |
| with `W91Workload`, after | 0.397–0.408 | 0.214–0.235 | 1.62–1.66 | 1.16–1.19 | 3.45–3.76 |
| without it, before (`time-base`) | 0.730–0.744 | 0.327–0.330 | 2.13–2.17 | 1.61–1.63 | 3.95–4.01 |
| without it, after (`time-w91`) | 0.723–0.728 | 0.327–0.333 | 2.14–2.15 | 1.60 | 4.22–4.26 |

- With a workload that covers the steps, the change takes 0.13 s off the steps (0.07 s in `select_filter`, 0.06 s in `user_function`): the entry is no longer compiled. One run after the change is an outlier (steps 1.83, `user_function` 0.32, GC 0.23 s) and is left out of the range above; it is in `logs/wl-w91/wl-1.out`.
- Without such a workload nothing changes: no image holds the entry at these signatures. The forks' own workloads do not run `ByRow` over columns with missing values.
- The wall time varies with the REPL's bimodal start (0.36 or 0.61 s, E-233).
- What remains of the `Callable` path in the session: `_callable_result` (the open result type, not covered, the note §4), the pointer's thunk for the session's function (`_fptr`, per function type), the `cfunction`'s callee `_CallWrap{S}` at the function's type.

**TraitWorld's test** `test/callable_images.jl` on the branch: passes in both settings. The same test at ca92f22 (the old signature in its probe, `logs/` not kept: run by hand) fails: no CodeInstance with machine code after the load, and the first call compiles `enter_callable(Type{Tuple{Union{Missing, Float64}}}, Type{Bool}, Any, Any, Val{false})`. With a static call from the image's own code (an entry compiled at the argument types) the old signature was kept too, through the caller's edge.

**The checks** on the branch (`../checks/logs/w91/`): TraitWorld's suite in the product setting (14ec5c8) and under the facts image (d22ec7b) pass; the acceptance suite 35/35 in both; TDE `Pkg.test()` passes (TDE 3a51d95) and its session's 9 `RESULT` lines equal `../w81/x1/session-x1-one-function.log`; TraitMakie `Pkg.test()` passes (2c70583); the forks' session digests equal upstream's in 26 steps, and the REPL session raises no error.
