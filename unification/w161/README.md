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
