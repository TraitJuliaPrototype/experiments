# W-170 (E-538): the candidates of the profiling round, built, checked and measured

The question (the registry, `writeup/record/experiments.md`, E-538): the candidates E-536 and E-537 found (open issues
260 to 264, the library's hooks, 255 (a)), each built where it follows from a rule and adds little code, checked by the
gates and the suites, and measured on the cell that showed it, beside its plain twin. No claim of better steady-state
speed: each cell is compared with the plain twin (PlainODE on the same build; upstream's packages on vanilla for
NetworkDynamics).

## How to run

From this directory (`source env.sh` is done by every script; nothing is downloaded, no `Pkg` operation):

```sh
bash time.sh <label> pollu "0 1" 3          # E-537's POLLU cells (w169/stiff/run.jl), B and A beside PlainODE
bash prof.sh <label> "pollu:0 pollu:1"      # E-537's profile, classed (python3 ../w169/stiff/profms.py logs/prof-<label>.log)
CELLS="B A V" bash nd.sh <label> time 2     # NetworkDynamics' step d (w169/stiff/nd_steady.jl); V: upstream on vanilla
CELLS="odecb:B odecb:A odecb-plain:A" bash sessions.sh <label> 3   # E-536's sessions; python3 sesstab.py logs/sessions/<label>
bash session.sh odecb A trace 1             # what the session compiles; python3 ../w169/tools/top.py logs/sessions/odecb-A-trace-1
python3 tables.py logs/time-<label>.log
source env.sh; jS A demo diag.jl            # the per-call costs (E-537's diag.jl (a), with the box's field reads)
jS A demo probe260.jl; JULIA_DISPATCH_PROFILE=1 jS A demo probe261.jl; jS A demo probe264.jl; jS A demo probe255.jl
(cd ../../../ndport && NDW_STACK=ports NDW_API=ports jSnd A $W/nd_digest.jl)   # step d's digest (the workload's digest_d)
```

**Settings** (`env.sh`), all on `julia-next` 683ea4fc16 (read only), product setting, strict mode off, one thread, BLAS
on one thread, niced, a fresh process per run, a depot of each setting's own (`agent-depots/w170/<S>`):
- **B**, before: TraitWorld 38200d3, TraitDifferentialEquations 06c28c3, NetworkDynamics-unified c2bbf0d (worktrees
  `wt/w170-base-*`), the round's environments remapped by `w159/mkenv.py` (`envs/B/*`).
- **A**, after: the branches `w170` (`wt/w170-tw`, `wt/w170-tde`, `wt/w170-nd`); the heads at each log's header.
- **C, D**, for the load's attribution: the library's branch with the ODE port at 06c28c3 (C), at 38fc6e6 (D, logs
  `c5load`, `c5wl`, `c5`) and at d061814 (D, from `c5ode4`).
- **V**: upstream's packages on vanilla v1.13.2 (45b6d15e34), E-537's cell (`w159/envs/V/ndup`, the round's images read
  behind a depot of this experiment's own; nothing was compiled).
- The plain twin PlainODE is the same code in every setting. The machine: 128 cores, 1-minute load 2.4 to 12 (others'
  jobs and one other agent's build); each log's header and rounds note it.

Interop or idiomatic: POLLU and the ODE programs are idiomatic code of the port; NetworkDynamics is a port of an upstream
package.

## Results, 2026-11-22

### 1. A declared field read through a box (open issue 260)

The library (`TraitWorld/src/dynamic.jl`): the declared fields a constant of the trait instance (`_declared_fields`,
generated: names, types, `@const` flags, read as the Compiler reads a declared field, with no evaluation of a contract);
`getproperty` and `setproperty!` at a box inlined, so that at a constant name the test folds; at a name not constant, a
scan of the constant table. The refusals stay (`probe260.jl`, 17 checks, and the library's `declared fields` testset): a
name outside the contract (`ArgumentError`, at a constant name and at one not constant), a value outside the declared
type (`TypeError`), a write of a `@const` field, a write converted to the declared type; the definition-time check still
names the field (`atbox.jl` reads the refusal's helper as a call at a box that only throws).

Per call (`diag-B-c3.log`, `diag-A-final.log`; the minimum of 7 runs of 10^5 calls):

| what | B | A |
|---|---|---|
| a declared field read through a box, `d.p` (constant name) | 111.4 ns | 25.9 ns |
| `d.t` (constant name; a `Float64` from a dynamic `getproperty`) | 112.6 ns | 46.8 ns |
| at a name not constant | 101.5 ns | 31.4 ns |
| a write, `d.u_modified = b` | 456.7 ns | 58.9 ns |
| ODECore's `_sync_in!` (5 reads through a box of `StepView`), the member `diag.jl` defines | 538.7 ns | 8.2 ns (`diag-A-c3.log`); 213.3 ns in A final |

The last row's 213 ns in A final is the member's, not the read's: ODECore's image holds `_sync_in!` since candidate 5,
split over the members known when the image was built; `diag.jl`'s own `StepView` member, defined after the load, is
served past the split. POLLU with callbacks (Rodas5's integrator, a member of another image) is unchanged by it.

NetworkDynamics' step d (`nd-c260.log`, 2 fresh processes each, load 6.7 to 8.1): **150.6–151.0 → 87.9–88.7 ms**; Tsit5
62.8–63.1 → 33.4–33.8 ms, the stiff solve 87.0–87.6 → 52.8–53.2 ms; the same steps and trips.

A defect found and fixed on the way (TraitWorld 3790bda): the first generator read the names from the contracts,
whose supertraits' expressions may need `eval`, which a generator may not do; ODECore's precompile workload (candidate
5), which reads `i.u` through a box of `IntegratorView` (a trait with supertraits), failed to precompile. The pattern
existed before (the generated `_field_isconst(::Type{X}, ::Val{s})`, removed).

### 2. A box at two signatures (open issue 261)

The reading of E-537 is not what happens. The call method `(d::Dynamic{Z})(args...) where {A, S, Z <: Callable{A, S}}`
is matched where the call is compiled (an `invoke`), and its specialization has `A` and `S` fixed. The cost was the
result's check: a helper, `_checked_result(r, S)`, called with the result, whose type is not known; compiled by facts,
that call is a run-time site, dispatched at every call through the leaf cache (hashing `Type{S}`): the dispatch profiler
counts 1,000,010 dynamic calls of `_checked_result` for 10^6 calls of the box (`probe261-B.log`), and `code_typed` under
the facts mode shows `dynamic TraitWorld._checked_result(%6, Nothing)::Any`. The library (`callable.jl`): the check
written in the call's body, as at one signature, the arguments tested against each signature in turn (`MethodError` past
the last), the result against that signature's `S` (`TypeError`). The check at the box is unchanged: the gates
`n14_callable_args`, `n35_trusted_result`, the library's `test/callable.jl`, `test/trusted.jl`, `probe261.jl` (8 checks)
pass; the call's result is inferred at `S` (a test in the library's suite, which fails on B).

| per call (`diag.jl`) | B | A |
|---|---|---|
| a box at one signature | 23.5 ns | 22.9 ns |
| the box of `All{rhs, duals}`, first signature | 120.4 ns | 23.7 ns |
| the same, second signature (duals) | 121.5 ns | 24.3 ns |
| `probe261.jl`: a box of two signatures, `f(1.5)`, in a loop | 205 ns | 68 ns |

### 3. Rodas5's integrator typed by its linear solver (open issue 262)

The ODE port (`lib/TraitRodas/src/rodas5.jl`): `Rodas5Integrator{JC, M, L}` with `ls::L`, the port following traits §7.10.
POLLU (`time-pollu-c3.log`, after candidates 1 to 3; `time-pollu-final.log`, after all; 3 fresh processes per cell,
interleaved; the minimum, the range of the medians; load 4.9 to 5.8):

| POLLU, 20 states | B box | B compiled | A box | A compiled | twin wrap | twin spec |
|---|---|---|---|---|---|---|
| no callbacks, final | 0.740 (0.747–0.753) | 0.625 (0.633–0.637) | 0.572 (0.581–0.620) | 0.546 (0.552–0.561) | 0.557 (0.562–0.566) | 0.536 (0.542–0.556) |
| with callbacks, final | 4.157 (4.166–4.191) | 3.565 (3.570–3.591) | 3.152 (3.161–3.168) | 3.018 (3.030–3.066) | 2.985 (2.994–3.011) | 2.915 (2.923–2.954) |
| no callbacks, after 1–2 (`time-pollu-c2.log`, 2 processes) | 0.741 | 0.626 | 0.652 | 0.664* | 0.556 | 0.544 |

(* one process's median 0.880; `time-pollu-c2b.log`, 3 processes: A compiled 0.624 (0.630–0.640), as B.)

The same steps, calls, Jacobians and error as the twin in every cell. **The port boxed is within 3 % of the twin's
default (0.581 against 0.562 ms), the port under `compiled_for` within 2 % of the twin's own function (0.552 against
0.542 ms); with callbacks 6 % and 4 %.**

What is left of GT-33's cost in the step (`prof-c3.log`, E-537's classes): the step's arithmetic, the solves and the
factorization carry no dispatch at run time in any cell; the box's dispatch is in the right-hand side (0.009 ms per
solve without callbacks, 0.038 with) and the callbacks (0.052–0.057 ms of 0.091–0.094 per solve with callbacks, against
the twin's 0.009–0.015). In POLLU no declared result read at a trait is checked in the step any more.

### 4. A continuous callback of several conditions (open issue 263)

ODECore: SciML's `VectorContinuousCallback(condition, affect!, len)`, the trait `VectorEventCallback{U, T, P}`
(`vector_event_length`, `vector_event_condition!(cb, out, u, t, integ)`, `vector_event_affect!(cb, integ, signs)`,
`vector_event_initialize!`), its record `FunctionVectorEventCallback`, its adapter `ParamVectorEvent`, `EnteredCallbacks`'
third vector. The solver core's `StepEvent` is a vector of conditions (a scalar callback is a vector of one):
each callback's conditions evaluated once per point, each condition's crossing located by bisection, the integrator
moved to the earliest, the affect told the signs of its conditions that cross there (`EventState`, `events_at!`,
`events_after!`, `locate_events!`, shared by Tsit5 and Rodas5). No new rule: traits §8 (the port's callback traits, storage
typed by the traits), the joint methods of traits §6.3 for a value of several callback traits. NetworkDynamics' port
(`src/callbacks.jl`): a batch of continuous component callbacks is one `VectorContinuousCallback`, as upstream's.

Checks: the ODE port's suite 36 testsets (35 and `test/w170.jl`: the vector callback's events equal two scalar callbacks'
to the bit in Tsit5 and Rodas5, the signs, a user's own `VectorEventCallback` type); NetworkDynamics' subset as before
(massmatrix 6, doctor 26, diffusion 108 pass 1 fail 1 error 24 broken, inhomogeneous 39 pass 1 error 12 broken,
ports_callbacks 14, ports_fixpoint 3; `checks/c5-nd-tests-A.log`); step d's digest (every saved state's bits, the trips
and their times) equal to B's (`nd-digest-B.log`, `nd-digest-A-c5.log`).

NetworkDynamics' step d (`nd-final.log`, 2 fresh processes per cell, interleaved, load 4.5 to 6.1; ms, the minimum and
the medians):

| | B | A | upstream on vanilla (V) |
|---|---|---|---|
| step d | 151.1 (151.7, 154.0) | **25.9 (25.9, 26.7)** | 28.0 (28.0, 28.8) |
| Tsit5 | 63.5 (63.6, 64.2) | 6.34 (6.35, 6.62) | 2.88 (2.91, 3.05) |
| the stiff solve | 87.8 (88.1, 88.6) | 18.9 (18.9, 19.5) | 24.5 (24.5, 25.7) |
| allocation per step d | 31.97 MiB | 3.62 MiB | 2.19 MiB |

The port's step d is now below upstream's (its Rodas5 variant), by its stiff solve; its Tsit5 solve is 2.2 times
upstream's (`nd-c263-prof.log`: callbacks 3.6 ms, of it 1.5 dispatch at run time, against upstream's 2.1; the right-hand
side 2.7 ms against 0.8).

**The callbacks' adapter typed by the callback's type, measured and not taken:** `ParamCallback{U, T, P, C}` (and the
events' adapters) with `cb::C` changed no cell beyond the spread (POLLU with callbacks 3.150–3.181 against 3.155–3.180
ms, `time-pollu-c4b.log`; step d 25.8–26.3 against 25.9–26.1 ms, `nd-c263b.log`) and compiles the adapters per callback
type; its diff is kept in `patches-adapter-typed.diff`.

### 5. Callbacks in the workloads (open issue 264)

The umbrella's workload line alone (the program's form: a callback kept by the problem, a tuple given to `solve`)
saved 37 ms of the first run (307 → 270.5 ms, `c5wl`): the solve's keyword method and the records' constructors. The
rest stayed out of the image, by open issue 228's rule, now identified (`probe264.jl`, the census): an image keeps
another package's code only where the image's own code calls it (an edge to the worklist, Julia's
`has_backedge_to_worklist`). Two causes:
- `push!` of the adapters into the core's vectors followed a constructor's call at a value known by its trait, a call
  left to dispatch (typed `Any` under the facts mode), so Base's `push!` was dispatched when it ran: the constructor's
  result asserted in `adapt_callbacks!`;
- the events' and adapters' methods (`step_event_initialize!`, `_sync_in!`, `event_time`, …) are ODECore's, reached
  through the callbacks' traits when the solve runs, so the umbrella's image could not keep them: ODECore has a workload
  of its own, Tsit5 at a `Vector{Float64}` state and parameters with one discrete and one continuous callback.

The callbacks program (`sessions/c5-*`, 3 runs each after a warm-up, interleaved; ms, the median and range):

| | B | D (candidates 1–3) | A (1–5) | PlainODE |
|---|---|---|---|---|
| first run | 306.1 (305.8–306.6) | 305.3 (305.3–330.2) | **144.1 (143.4–145.3)** | 125.6 (124.9–134.2) |
| load | 600.3 (596.2–614.6) | 602.1 (586.1–610.4) | 654.8 (638.4–663.0) | 306.4 |
| the session's own-image instances inferred (census) | 49 (B, `odecb-B-trace-1`) | | 8 (`odecb-A-trace-3`) | |

The images (`.so`, bytes): ODECore 1,932,960 (B) → 3,645,184 (A); TraitDifferentialEquations 4,425,032 → 3,780,752;
TraitRodas 352,088 → 341,992; the three 6.71 → 7.77 MB. The plain ODE program's first run 377 → 363.5 ms
(`c5ode4`): ODECore's workload serves it too.

### 6. The library's hooks: no instance the system image holds inferred only; their records typed

The library (TraitWorld 4a31dff): `svec[2:end]` in the definition-time check (`atbox.jl`, `classify.jl`) and
`enumerate(c.params)` in the records each activated membership gets at load (`_contracts_of!`, `_params_at`,
`_stated_env`) are loops by index over `1:length` (`eachindex(::Vector{Symbol})` is itself an instance the system image
lacks machine code for); a pattern's membership and a member's instance are records of one type each (`_Pattern`,
`_MemberAt`), their results asserted where a call at an abstract argument leaves them to dispatch. Found by
`probe_hooks.jl` (callers by backedges) and `probe_hooks2.jl`, `probe_hooks3.jl` (the stack of the first call). The gate
`n36_library_deep` passes; the gates 75 and 9, the library's 120 testsets, the ODE port's 36.

The ODE program's load (`sessions/c6ode-*`, 5 runs each, load 6 to 7.4): **B 615.6 (607.7–635.9), A 616.3 (615.1–619.5)
ms**: candidate 6 takes back what candidates 4 and 5 added (D at d061814: 650.3; A before candidate 6: 670.2, `c5ode4`).
What the load generates machine code for (`ode-B-trace-1`, `ode-A-trace-1`): 91 ms (13 instances, the library's 19 ms)
→ 49 ms (Julia's own: `@static` 26.7, `@main` 12.7, `setindex!(::IdDict{Any,Vector{Any}}, …)` compiled again 6.4, `Ref{Any}(::Type)` 3.1).
The split (`split-ode-c6.md`, one profiled run each): the library's image hook compiling 50 → 17 ms, the
definition-time check compiling 11 → 0; the membership walk 62 → 82 ms and the memberships' activation 27 → 41 ms
(candidate 4, below); the callbacks program's load 618 → 592 ms (`c6`).

### 7. The walk by the member's origin (open issue 255 (a)), measured only

`probe255.jl` (`probe255-B.log`, `probe255-A.log`). At the load itself the runtime's counters: B 175 walks, 2,102 methods
replayed, 472 examined, 47 invalidation events; A 179, 2,283, 521, 58. Each activated membership walked again in the
loaded state, without invalidating (a proxy; what it does not model is in the probe's header):

| B | memberships | methods replayed | walk (proxy) |
|---|---|---|---|
| new with the load (the port's packages' types) | 65 | 2,010 | 152 ms |
| the library's types | 4 | 13 | 0.06 ms |
| foreign (Core, Base, standard libraries) | 106 | 923 | 349 ms |

- Of the foreign walks, the two pattern memberships of the kept forms in `Callable` (`Dynamic{Z}`, `Compiled{Z}` for
  `Z <: Callable{A, S}`, the library's) take 175 + 160 ms of the proxy: in the loaded state they meet every method at
  `Callable`, at the library's load they meet the library's few.
- The new members' replays in the proxy, 2,010, are 96 % of the load's own 2,102: the walk at the ODE port's load is
  almost all at members whose type is new with the load. Most of it is `Callable`'s memberships (`@implement Callable T`
  for 25 of the port's types), each replaying every method at `Callable` (112 in B, 123 in A).
- So candidate 4's load cost: its methods with `Callable` arguments (the vector callback's record and entry) lengthen
  every `Callable` membership's walk (+11 methods each, +181 replays at the load).

## Not done, not verified

- NetworkDynamics' port has no remote but upstream's (`origin` is JuliaDynamics/NetworkDynamics.jl): its branch `w170`
  (4992049) is local, in `wt/w170-nd`, not pushed.
- The walk's split by member is a proxy (re-walked in the loaded state); the load's own walk is not split per membership.
- `setindex!(::IdDict{Any,Vector{Any}}, ::Any, ::Any)` is compiled again at every trait program's load; which method ends
  it is not known.
- The steady state of the Brusselator, the plot and report programs and the frames sessions were not measured again.
- NetworkDynamics' whole workload and its other passes were not run; only step d, its digest and the test subset.
