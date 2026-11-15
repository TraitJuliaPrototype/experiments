# W-161: the fifth wave (the merge, open issue 204, D-4, D-2)

The fifth wave of [the plan](../../../writeup/plans/2026-11-15-next-iteration.md) (§6), on `julia-next` (branch `next`) with TraitWorld `unified`:
- the merge of `next-s3` into `next` and of TraitWorld `s3` into `unified`, both lines' gates again (E-496);
- open issue 204: a trait's parameters left open erase too (E-497);
- D-4: a required operation is an entry of the contract and no method at the set (E-498, E-499);
- D-2: `Callable` is a contract at the box (E-500, E-501).

Registry: E-496 to E-501 in `writeup/record/experiments.md`. Current numbers: [the evidence](../../../writeup/design/evidence.md), §1, "The fifth wave on `next`". The agent's session note: `session-notes/2026-11-15-agent-w161.md`.

## How to run

Every script: `source experiments/unification/w161/env.sh` first (a depot of this agent's own stacked before the shared one; `$JN` is `julia-next`, `$JU` `julia-unified`, `$CSVFILE`, `$LOADS`).

| | What | Run |
|---|---|---|
| `suites.sh` | every gate of the two merged lines and the suites: W-155's `gate_deep.jl`, W-155b's `gate_d11.jl`, W-160's check gates, the library's suite, the ODE port's, TraitMakie's, NetworkDynamics' subset, the forks' digests, Julia's four test files | `bash suites.sh <label> [deep d11 w160 library tde makie nd digests tests]` |
| `merge/delete_forwarder.jl` | E-496's own gate: code that decided a positive membership where the type is known ends when the membership is taken back | `$JN --project=$TW_ROOT/TraitWorld-unified merge/delete_forwarder.jl` |
| `i204/summarize.jl` | E-497: `summarize(c::Column, name)` compiled once per trait instance | `$JN --project=<TraitWorld tree> i204/summarize.jl` |
| `d4/mistakes.sh` | E-498: E-385's fifteen mistakes (W-136's cases, trait forms) on a tree | `bash d4/mistakes.sh <label> julia-next TraitWorld-unified` |
| `../w152/p4/late.jl` | E-498: what the library's late load ends after upstream CSV's and DataFrames' work | `$JN --project=env_lib ../w152/p4/late.jl $CSVFILE lib` |
| `d4/op150.jl` | E-498: open issue 150's case, `mul!` as an operation an untyped method serves | `$JN --project=$TW_ROOT/TraitWorld-unified d4/op150.jl` |
| `d4/plain.sh` | E-499: W-134's plain session, vanilla, the baseline and the head, interleaved | `bash d4/plain.sh <label> [runs]` |
| `d4/prof_first.jl` | E-499: where the plain session's first call spends its samples (open issue 225) | `$JN --project=env_lib d4/prof_first.jl $CSVFILE` |
| `d2/gate.jl` | E-500: D-2's gate (members, the box's and the wrapper's tests, GT-24 (b), no code ended by a method definition) | `$JN --project=$TW_ROOT/TraitWorld-unified d2/gate.jl` |
| `../w152/p7c/census.jl` | E-500: the `Callable` census, its guard pairs | `$JN --project=env_demo ../w152/p7c/census.jl TraitWorld TraitCSV TraitTables TraitMakie TraitDifferentialEquations`; `--project=env_forks … TraitWorld CSV DataFrames Tables` |
| `d2/functors.jl` | E-500, GT-32, open issue 227: every callable type of a session, a `Function`, declared, or neither | `$JN --project=env_forks d2/functors.jl -v TraitWorld CSV DataFrames Tables CairoMakie …` |
| `d2/plain_functor.jl` | open issue 227's case: an interpolation object at a `Callable` argument | `$JN --project=env_demo d2/plain_functor.jl` |
| `d2/e371.jl` | E-501: E-371's loop (plain, the wrapper, the box; one entry), head or baseline | `$JN --project=$TW_ROOT/TraitWorld-unified d2/e371.jl`; `$JU --project=d4/env_base_lib d2/e371.jl` |
| `d2/sessions.sh` | E-501: E-372's table and ODE sessions, head (`d2/env_head_demo`) or baseline (`d2/env_base_demo`: TraitWorld-base, the ODE port at `prototype-2026-11` in `wt/w161-tde-base`) | `bash d2/sessions.sh head\|base [N]` |
| `d2/image_instances.jl`, `d2/rodas_image.jl`, `d2/rodas_probe.jl` | open issue 228: the instances with valid code a build's images hold, per function; the one case | `$JN --project=d2/env_head_demo d2/image_instances.jl <out> TraitDifferentialEquations ODECore TraitRodas …` |

**Environments.** Copies of W-155b's (`env_forks`, `env_facts`, `env_session`, `env_demo`, `env_lib`) and W-160's (`nd/env_head`, `nd/env_test_head`, `late/env_head`), each loading the library from `TraitWorld-unified` and the ODE packages from `TraitDifferentialEquations-unified`; TraitMakie from `TraitMakie-unified`.

## Results, 2026-11-15

### E-496: the merge

`next` f8c2bf5f95 (the merge), TraitWorld `unified` 23717c1, TraitDifferentialEquations 6f96ded, TraitMakie d905a0b, NetworkDynamics 6d311a3, forks 439bae7; product setting, strict mode off, one thread; load 4 to 9 of 128. `logs/m1-summary.log`, `logs/m1-*`, `logs/e496-delete-forwarder.log`.

| Gate | Result |
|---|---|
| `gate_deep.jl` (D-5) | OK |
| `gate_d11.jl` (D-11) | OK, 0 failed |
| W-160's `new_fold`, `stores`, `kept_own`, `mistakes` | pass (kept_own: 4 own instances, 4 callers kept, 4 reached) |
| the library's suite | 93 testsets, exit 0 |
| the ODE port's suite | 35 testsets, pass |
| TraitMakie's suite | 79 checks, pass (its first run in `logs/m1-summary.log` failed to find `PlainPlots`: the suite runs in `env_demo`) |
| NetworkDynamics' subset | diffusion 108 passed, 1 failed, 1 error, 24 broken; inhomogeneous 39 passed, 1 error, 12 broken (as on W-151's and W-160's builds) |
| the forks' digests | equal, 26 steps |
| Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` | SUCCESS |
| `merge/delete_forwarder.jl` | 19 of 19: `runit` (a forwarder's box), `mkbox`, `store!` rest on the membership's method through a callee's code, `isit` by an edge of its own; all four end when the membership is taken back |

### E-497: open issue 204

TraitWorld `unified` fb67ac1 against 23717c1, on `next` f8c2bf5f95. `i204/logs/`, `logs/i204-summary.log`.

| | before | after |
|---|---|---|
| the member inside `summarize(c::Column, name)` | plain | boxed at its instance |
| instances of the method as written, two members of `Column{Float64}`, one of `Column{Int}` | 1, at `Column` (the attribute's, compiler C-112) | 2, at `Dynamic{Column{Float64}}` and `Dynamic{Column{Int64}}` |
| checks of `summarize.jl` | 9 of 12 | 12 of 12 |
| the library's suite, the ODE port's, TraitMakie's, NetworkDynamics' subset | pass | pass |

### E-498, E-499: D-4

`next` 5448a8b7bf, TraitWorld `unified` c838f76 and 4b6c1d6; the baseline `unified` 7b374f39ce with TraitWorld-base; vanilla. `d4/logs/`, `logs/d4-summary.log`.

| | before (the merge's head) | after |
|---|---|---|
| `late.jl`: plain instances the library's late load ends | 208 of 119,854 | 0 of 120,065 |
| E-385's `03b` (an operation called outside its signature) | `OperationError`, 3 lines | `MethodError` at the user's line with the contract's hint, 11 lines (open issue 226) |
| open issue 150's case (`d4/op150.jl`) | — | 7 of 7 |
| the suites, the gates, Julia's four test files | pass | pass (Julia's `core` after 5302297a99) |

E-499 (3 runs and a warm-up, load 4.7 to 7.2): the repeated work 0.18–0.19 ms (the baseline 0.19, vanilla 0.17–0.18); the late load 35–49 ms ending 0, against 45–63 ms ending 209; the first work 3.31–3.47 s against the baseline's 2.90–3.00 and vanilla's 3.25–3.30 (`d4/logs/e499.log`; open issue 225).

### E-500, E-501: D-2

`next` eaa19da272, TraitWorld `unified` c14d2e4 and d1febca, the ODE port ae1a966, forks bf6799b. `d2/logs/`, `logs/d2e-summary.log`, `logs/d2f-summary.log`.

| | before | after |
|---|---|---|
| the census: pairs of a `Callable` against an untyped method (`d2/logs/census-*`) | 7 (the ODE port 5, the forks 2) | 0 |
| pairs told apart by a function's signature | 0 | 0 |
| `d2/gate.jl` | — | 25 of 25 |
| the suites, the gates, digests, Julia's four test files | pass | pass |
| declarations the ports needed (`@implement Callable T`) | — | the ODE port 14, its tests 5; ChainModels' model `<: Function` |
| callable types that are neither a `Function` nor declared (`d2/logs/functors-*.log`) | — | the forks' session 134 of 174; the demonstrators' 35 of 67 |

E-501 (3 runs each, the same hour, load 0.6 to 1.6): E-371's loop (`d2/logs/e371-*.log`): plain 0.79 ns on both; the wrapper 0.79 ns on both, one entry 0.79 ns against the baseline's 3.17; the box 26.5–27.0 ns a call against 22.9. E-372's sessions (`d2/logs/sessions-*.log`): the table session's first run 54.3–54.7 ms against 62.1–62.5; the ODE session's 651–653 ms against 398–399, of it `TraitRodas._rodas5_run` compiled in the session (315 ms), which `next`'s image does not hold, as `next-s3`'s does not (`d2/logs/image-*.txt`; open issue 228). The environments' `Project.toml` named the `-s3` trees until this date; their manifests, which is what loads, named the `-unified` ones.

### E-496 again: the second merge

`next` 32a2235abd (`next-s3` to bc844be7c0: W-157's `Val` and `IOContext`), with D-4 and D-2; TraitWorld `unified` d1febca, the ODE port ae1a966, forks bf6799b; load 1 to 5. `logs/m2-summary.log`: `gate_deep.jl` OK, `gate_d11.jl` OK, W-160's four pass, the library's suite (93 testsets), the ODE port's (35), TraitMakie's, NetworkDynamics' subset as before, digests equal (26 steps), Julia's four test files SUCCESS; `merge/delete_forwarder.jl` 19 of 19 (`logs/m2-delete_forwarder.log`); D-2's gate 25 of 25 (`d2/logs/gate-m2.log`).

