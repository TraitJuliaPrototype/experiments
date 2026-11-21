# W-158, the port's part: the ODE port follows the design where its trimmed program is refused

E-510, continued (open issue 184). The trimmed ODE program (`../../w135/apps/ode.jl`: Lorenz with Tsit5, Robertson
with Rodas5) counted 36 errors under `--trim=safe` on julia `next` 8b35e4b77c (`../logs/c-ode.build.log`). Of them,
the port's own departures from the references: a `Vector{Any}` of callbacks with calls at `Any`, Rodas5's dual
chunk as a type chosen by a run-time value with its function at `@nospecialize(f)`, `PartialFn` built at `Any` in
`@nospecialize` helpers. This part changes the port (TraitDifferentialEquations, branch `w158p`) to follow the
references at each, one commit per departure, and counts the build after each. The compiler's kinds (the call of
the object a box holds, the callbacks' constructors at values known only by `Callable`: C-154, C-151) belong to
another agent's build.

## How to run

```sh
source experiments/implementation/w158/port/env.sh     # julia-next, the depot agent-depots/w158p, the build's project
cd $PORT
bash suite.sh <tag>             # the port's suite -> logs/suite-<tag>.log (the testsets counted)
bash build.sh <step>            # the ODE program trimmed (VERIFY=1) -> logs/w166c-w158p-<step>.build.log,
                                # errors by module (../../w135/summarize.py) and by statement and kind (probes/kinds.py)
APP=apps/ode_cb bash build.sh <step>   # the program with callbacks it knows (a tuple; one kept by the problem)
bash session.sh <tag> [N]       # the ODE program as a session (as ../sessions.sh counts the report's): a warm-up and
                                # N runs, the compiles by class, the port's instances, the build's check in the session
$JN --project=$ENVD probes/steps.jl          # 18 examples' results and step counts, two small timings
$JN --project=$ENVD probes/check_roots.jl    # the session's check, each error with its chain of frames
```

- `probes/kinds.py <log>`: the verifier's errors by statement (callee, innermost frame) and by E-510's kinds: 1 the
  callbacks' entry, 2 the call of the object a box holds, 3 Rodas5's chunk, 4 `PartialFn` at `Any`.
- `probes/instances.jl`: `../../w156/instances.jl` for the port's packages.
- Before `cb-step4`, `build.sh` did not set `DEPOT`, and `../../w166/build_c.sh` then writes the program's package
  images into the shared depot (`.julia-depot/compiled/v1.13/<pkg>/*_Jk7QE.*`, seven packages, the build's own slot).
  From `cb-step4` on they go to `agent-depots/w158p`.

## What was changed, and why

TraitDifferentialEquations `w158p` on `unified` 3e60c29:

| Commit | The departure | The rule | The new form |
|---|---|---|---|
| 9d97482 | the adapted callbacks passed to each solver in a `Vector{Any}`, split again with a call at `Any` (`enter_step_callbacks`, `_enter_step_callback!`) | storage typed by a trait keeps each form by its own type (traits §8.1); the reference's own operation takes the core's callbacks so (`solve_core(…, cbs::Vector{StepCallback{Vector{T}}})`, §4.1); a `Vector{Any}` is not fully typed (§14) | `StepCallbacks{U, T}`: a `Vector{StepCallback{U, T}}` and a `Vector{StepEvent{U, T}}`; `solve_core`, `init_core` take it |
| 3dce9a2 | the user's callbacks collected in a `Vector{Any}` (`_cbs`, `_callbacks`), the problem's too, entered at each solve with calls at `Any` (`_enter_callback!`) | §14; §8.1; a record made before a signature is known keeps each value as given and the constructor that knows the signature enters it (§8.2; porting guide B2.5, 0.4); a container of `Any` becomes storage typed by a trait (porting guide 0.1); open issue 184 (a) | `enter_callbacks(cbs, U, P)` → `EnteredCallbacks{U, Float64, P}` (a `Vector{Callback{U, T, P}}`, a `Vector{EventCallback{U, T, P}}`) where the types are known: `ODEProblem`'s constructor (its field), `solve`, `init`; a tuple entered item by item at each type; `remake` enters again |
| 1f5d34c | the function partially evaluated in `@nospecialize(f)` helpers (`_erased_function`, `_plain_function`), compiled at `Any`, and kept at `Any` beside its kept forms (`UserFunction`, the fields `fplain`) | a function known only by its signature is a kept form or `Callable{A, S}`; a box's function is called at another signature by boxing it again, `Dynamic{Callable{B, S}}(unwrap(d))` (§7.7, §9); a value known by its trait keeps a build's members listable (§14, §16) | `PartialFn(unwrap(k), p)` from the kept form; no `UserFunction`, no `fplain`; Rodas5's own dual chunk boxes `unwrap(m.f)` again at `CoreDualSig{N}`, a wrapper as it is |
| 1d9a516 | Rodas5's chunk a field `Union{Nothing, Int}`, `Val(N)` of it choosing the integrator's type when the solve runs, for `Rodas5()` too | fully typed code has its calls settled where it is compiled, and is the code that compiles ahead (§14, §16): an option that chooses the code's types is a type where the program makes it (upstream's `Rodas5{CS, …}`) | `Rodas5{L, CS}`, `chunk_size(alg)`; `rodas5_init` folds on `CS`; only `chunk_size = 0` (picked from the state's length when it runs) keeps a function barrier |

The user's API is unchanged: `solve(…; callback)` and `ODEProblem(…; callback)` take `nothing`, one callback, a
tuple or a vector, `Rodas5(; chunk_size, linsolve)` as before (and `chunk_size = Val(N)`). The core's API changed:
`solve_core`, `init_core`, `tsit5_init`, `ie_solve` take `StepCallbacks`; `adapt_callbacks` returns one;
`enter_callbacks` returns `EnteredCallbacks`; `enter_step_callbacks`, `UserFunction` are gone; `HasCallbacks`'s
`problem_callbacks` declares `Any`. The suite's `routea.jl` passes `StepCallbacks` to `tsit5_init`.

## Results, 2026-11-21

julia `next` 8b35e4b77c (`julia-next`), TraitWorld `unified` cedb718, project `../../w156/env_demo`, one thread,
`--trim=safe`, `VERIFY=1`, one Julia job at a time; load (1 min) 2 to 9 of 128.

| Step | TDE | Errors | 1 callbacks | 2 box call | 3 Rodas5 | 4 PartialFn | Statements | `verify_main` sites | Suite | Load |
|---|---|---|---|---|---|---|---|---|---|---|
| before | 3e60c29 | 36 | 22 | 4 | 6 | 4 | 14 | 20 | 35 pass | 2.4 |
| 1 step callbacks | 9d97482 | 34 | 20 | 4 | 6 | 4 | 13 | 19 | 35 pass | 2.5 |
| 2 user callbacks | 3dce9a2 | 14 | 0 | 4 | 6 | 4 | 7 | 5 | 35 pass | 2.5 |
| 3 function at its signature | 1f5d34c | 10 | 0 | 4 | 6 | 0 | 5 | 5 | 35 pass | 2.9 |
| 4 Rodas5's chunk a type | 1d9a516 | 4 | 0 | 4 | 0 | 0 | 2 | 2 | 35 pass | 9.4 |
| the program with callbacks (`apps/ode_cb.jl`) | 1d9a516 | 36 | 34 | 2 | 0 | 0 | 8 | 13 | | 4.4 |

Logs: `logs/w166c-w158p-<step>.build.log`, `logs/w158p-<step>.kinds.txt`, `logs/suite-<step>.log`.

- Kind 1 before: of its 22, 4 were the port's calls at `Any` (`_enter_callback!` 2, `_enter_step_callback!` 2); 18
  the compiler's (the records' constructors 12, the box's test `hasmethod` 4, `push!` of the constructors' join 2),
  reached only because the program could not tell its callback list was empty. Without callbacks none is reached.
- **Left on the ODE program: 4 errors, 2 statements, each reached by both solves, all the compiler's (C-154):** the
  call of the object a box of `All{Callable{CoreRHSSig{Float64}, Nothing}, Callable{CoreDualSig{8}, Nothing}}` holds,
  `TraitWorld/src/callable.jl:42` (from `core_rhs!`) and `:44` (from `_ad_jacobian!`).
- **The program with callbacks it knows** (a tuple to `solve`, one kept by the problem): no call at `Any` in the
  port. Its 36: the records' constructors at functions known only by bare `Callable` (`FunctionCallback{U,T,P}`,
  `FunctionEventCallback{U,T,P}`: 24 calls, 4 invokes), the box's test (`hasmethod` 2, `to_tuple_type` 2), `push!` of
  the constructors' join 2 (compiler C-151, C-154; open issue 159's records), and the box call 2 (C-154).

**The session** (`session.sh`, a warm-up and 3 runs; `logs/session-before.log`, `logs/session-after.log`):

| | before (3e60c29) | after (1d9a516) |
|---|---|---|
| first run of `main`, of it compiling | 486–488 ms, 484–485 ms | 342–355 ms, 339–352 ms |
| second run | 1.5–1.6 ms | 1.6–1.7 ms |
| load | 1913–1920 ms | 1946–2041 ms |
| compiles (the last run's trace) | 80, 1008 ms: session 9, recompile 5, own image 10, composition 5 (164.7 ms), julia 51 | 77, 853 ms: 9, 5, 10, composition 4 (23.1 ms), 49 |
| instances with code: ODECore, TraitRodas, TDE, TraitIndexing, TraitWorld | 401, 50, 84, 42, 557 | 399, 62, 82, 42, 548 |
| the build's check in the session (`../probes/ode_members.jl`) | 26 errors, 5 rounds, 12.0 s | 28 errors, 3 rounds, 7.7 s |

- The compiles gone: `_rodas5_run` at the integrator (a dynamic site before), `*` and `>` at `Float64`. TraitRodas'
  12 more instances are its image's: the workload's `Rodas5(chunk_size = 0)` is now a type of its own, so
  `rodas5_solve`, `rodas5_init`, `solve_core` and their callees have an instance for it beside `Rodas5()`'s.
- The check's 28 after: 2 the box call (C-154), 26 the box's `getproperty` at a declared field (traits C-153: the
  error message's `string` of a type, 25, and `declared_field_in`, 1), reached through `_sync_in!` (`sv.u`, `sv.t`
  at `Dynamic{StepView}`), from `ParamEvent`'s and `ParamCallback`'s methods. The check now has the step callbacks'
  members by flow (`StepCallback`: `ParamCallback`; `StepEvent`: `ParamEvent`; `Callback`, `EventCallback`: none, a
  "no method" fact), so it reads their code; the build resolves those reads (`logs/check-roots-after.txt`).
  None is the port's. Before: 26, of which 20 at the callbacks' entry and Rodas5's chunk, 2 the box call.

**Results and step counts** (`probes/steps.jl`; `logs/steps-before.txt`, `logs/steps-after.txt`): 18 examples (the
program's two solves; Rodas5 with the library's duals, chunk 0, chunk 2, compiled, a given Jacobian; Tsit5 compiled,
`Float32`; a discrete, a continuous callback, a tuple, a vector, the problem's with the given ones, Rodas5 with
callbacks; `remake` at new parameters with a kept callback; `init`/`step!`/`solve!` with Tsit5 and with Rodas5 chunk
0), a gradient and `rhs_function`: equal, line by line (return code, accepted and rejected steps, right-hand-side
calls, saved points and parameters, a digest of the printed times, states and saved parameters).

**Timings** (control only; the second call on, the minimum of 5, one process): the program's Lorenz solve 0.88 ms
before, 0.87 ms after; Robertson 0.59 ms, 0.59 ms; load 2.9 and 3.4.

## The other ports follow

The ODE port's rules (traits §7.4, §7.7, §8.1, §9, §14; porting guide 0.1, B2.7) applied to two more places. julia `next`
8b35e4b77c, TraitWorld `unified` cedb718, depot `agent-depots/w158n`, one Julia job at a time, load (1 min) 4 to 9 of 128.

| Port | Commit | The departure | The rule | The new form |
|---|---|---|---|---|
| TraitDifferentialEquations `w158n` (on `unified` 1d9a516) | 1425aec | `_nlpartial(@nospecialize(f), p)` and `_attime`, compiled at `Any`, built `NLPartial(f::Any, p)`; `_nlproblem(@nospecialize(r), @nospecialize(jr), …)` boxed at `Any`; the front end `NonlinearProblem(@nospecialize(f), …)`, `SteadyStateProblem(@nospecialize(f), …)` | a function known only by its signature is a kept form or `Callable{A, S}`; a box's function is boxed again at the signature called; a wrapper is taken as it is (§7.4, §7.7, §9); a value known by its trait keeps a closed build's members listable (§14, §16); the ODE core's `_core_function` (commit 1f5d34c) | the functions are trait arguments, `Callable{NLRHSSig{P,T}, Nothing}` (the ODE right-hand side's `RHSSig` for the steady state); `_nl_function`, `_nl_jacobian` make the kept form from the one it arrives in, `unwrap(k)` of a box or a wrapper; `_nlproblem` is typed, its type parameters written out; the two records (`NonlinearFunction`, `ODEFunction`) enter their functions and Jacobian in the forms they hold. `compiled_for(f)` now keeps the solver compiled for it |
| NetworkDynamics `w158n` (on `unified` 82513ee, local only) | 5f82334 | `get_callbacks` built `Any[…]` with a splat; `_cbvector` and the join of `add_nw_cb` built `Any[…]`; both passed as `callback = …` | a list the caller gives keeps its own type (a tuple), or a vector of the small union of the callback record types, never a `Vector{Any}` (porting guide B2.7, 0.1; traits §14) | `Vector{NetworkCallback}`, `NetworkCallback = Union{ContinuousCallback, DiscreteCallback}`, TDE's two records (the types `to_callbacks` returns) |

**Checks.**
- TDE's suite: 35 testsets, equal line by line to `logs/suite-step4.log` (`logs/suite-n-nl3.log`).
- `compiled_for(f)` as a residual, a given Jacobian boxed or wrapped, `SteadyStateProblem(compiled_for(f), …)`: solved as before (`Compiled` kept).
- The build's check in the session (`probes/nl_members.jl`, `closed_check`; `logs/n-nl-*.log`):

| Program | before (1d9a516) | after (1425aec) |
|---|---|---|
| construction only (`apps/nl_prob.jl`): `NonlinearProblem`, `SteadyStateProblem` | 2 errors: `NLPartial(::Any, p)`, `AtTime(::Any, p, t)` (`problems.jl:120, 121`) | 0 |
| construction and solve (`apps/nl.jl`) | 8 errors: the two above, `TDE.jl:66` `kwcall(TraitNonlinearSolve.solve, prob::Any, alg::Any)`, 5 at the program's use of its result | 6: no `NLPartial`, `AtTime` or `_nlproblem_of`; the `solve` front end at `Any` and its result's use remain (below) |

- NetworkDynamics' test subset (`logs/n-nd-after.log`, the command of `../../w161/suites.sh nd` with this depot, 133 s): massmatrix 6/0/0, doctor 26/0/0, diffusion 108 pass, 1 fail, 1 error, 24 broken, inhomogeneous 39 pass, 0 fail, 1 error, 12 broken: equal to `../../w161/logs/w158p-main-summary.log`.
- The subset has no callback file: `probes/nd_callbacks.jl` (a diffusion network with a continuous component callback, with and without `add_nw_cb` of TDE's `DiscreteCallback`, as one, a tuple, a vector) gives the same events, steps and end state before and after (`logs/n-nd-cb-before.log`: `Vector{Any}`, `n-nd-cb-after.log`: `Vector{Union{ContinuousCallback, DiscreteCallback}}`).

**Left, and found.**
- The nonlinear `solve` front end is `@nospecializeinfer solve(@nospecialize(prob), @nospecialize(alg); kw...)`, "neither specialized nor inferred on the problem's type", and the umbrella forwards to it at `Any` (`_solve_nonlinear`): a closed build cannot resolve that call, and the program's use of its result. It is a choice made for the recompile goal that the ODE `solve` does not make (its `solve_ode` is typed). Not changed here.
- One method of `_nlproblem_of` on `Union{NonlinearFunction, ODEFunction}` left the call, with the box's object at `Callable{…}`, unresolved in the check; two methods, one per record, resolve it (0 errors). The check does not resolve a dispatch on a method with a `Union` of types at a trait-typed argument.
- NetworkDynamics: a `DiscreteComponentCallback` fails at its first event with "the function with `nothing`, expected Nothing, got a value of type Bool" (`to_callbacks(::DiscreteCallbackWrapper)` passes the user's affect's value on; TDE takes `Nothing`), the same before and after. A callback of another type than TDE's two records in `add_nw_cb` is not taken by `_cbvector` (a user's own member of the callback traits).

## The nonlinear front end; NetworkDynamics' discrete callbacks

Open issues 246 and 248. julia `next` 8b35e4b77c, TraitWorld `unified` cedb718, depot `agent-depots/w158q`
(`qenv.sh`), one Julia job at a time, load (1 min) 3 to 9 of 128. 2026-11-21.

### How to run

```sh
source experiments/implementation/w158/port/qenv.sh      # env.sh with the depot agent-depots/w158q
cd $PORT
bash qsuite.sh <tag>                                       # the port's suite -> logs/q-suite-<tag>.log
(cd .. && NLAPP=nl $JN --project=$ENVD port/probes/nl_members.jl)        # the build's check in the session (nl, nl_prob)
LIST=2 $JN --project=$ENVD probes/q_nl_session.jl         # what a session compiles for a new residual (below)
(cd $TW_ROOT/ndport && ND_FILES=ports_callbacks_test.jl,ports_fixpoint_test.jl \
   $JN -t 2 --project=$TW_ROOT/experiments/implementation/w161/nd/env_test_head $PORT/probes/q_nd_tests.jl)  # by name
$JN --project=$TW_ROOT/experiments/implementation/w161/nd/env_test_head probes/q_nd_fixpoint.jl   # find_fixpoint
```

- `probes/q_nl_session.jl`: one process; phase A solves a `NonlinearProblem` with NewtonRaphson, TrustRegion and
  the default polyalgorithm and a `SteadyStateProblem` with NewtonRaphson; phase B the same with new functions;
  phase C a third pair through a function of Main. Per phase the compile time and the method instances that hold
  code and did not before it (a diff of the whole method table), by module; the results as digests.
- `probes/q_nd_tests.jl`: a copy of `ndport/scripts/r3_nd_tests.jl` (the runner `../../w161/suites.sh nd` runs)
  whose files are given (`ND_FILES`).

### What was changed, and why

| Tree | Commit | The departure | The rule | The new form |
|---|---|---|---|---|
| TDE `w158q` (on `unified` 1425aec) | d96afc6 | `solve_nl(a::NonlinearAlgorithm, m::NLCoreProblem, opts)::NLCoreSolution`: the solution's element type unknown at a box of the algorithm, so a typed caller that passes it on is compiled with a split | an operation's `where` variables are fixed by its arguments (traits §4.1) | `solve_nl(a, m::NLCoreProblem{T}, opts)::NLCoreSolution{T} where {T}`; NewtonRaphson, TrustRegion, the polyalgorithm declare the same |
| TDE `w158q` | 3a1c4c3 | `@nospecializeinfer solve(@nospecialize(prob), @nospecialize(alg); kw...)`, `solve_nonlinear(@nospecialize(prob), …)`; the umbrella's `_solve_nonlinear` at `Any` | fully typed code is the code that compiles ahead (traits §14, §16); a plain function is boxed at `Callable`, one problem type for every function (§7.8, §9); the model is the trait, the problem is a record (porting guide B2) | `solve(prob::NonlinearProblemTrait, alg::NonlinearAlgorithm; abstol, reltol, maxiters)`, `solve_nonlinear(prob::NonlinearProblemTrait{T,P}, …)`; the umbrella's `_solve(prob::NonlinearProblemTrait, alg::NonlinearAlgorithm, …)` calls it, as `_solve` calls `solve_ode`; the options converted at their declared types |
| NetworkDynamics `w158q` (on `unified` 5f82334, local only) | a9ea1cf | the discrete batch's affect returned `any_pchanged && save_parameters!(integrator)`, a `Bool` | the result of a call of a box is asserted to `S`; where `S` is `Nothing`, end the function with `nothing` (traits §9) | the closure ends with `nothing`, as the continuous batch's; `test/ports_callbacks_test.jl` |
| NetworkDynamics `w158q` | c2bbf0d | `NetworkFixedT`, a callable struct, not a member of `Callable`: `find_fixpoint` raised `MethodError` at `SteadyStateProblem(nw_fixed_t, x0, p)` since TDE 1425aec | a callable type that is no `Function` is a member of `Callable` by declaration (traits §9) | `@implement TraitWorld.Callable NetworkFixedT{NW} where {NW}`; `test/ports_fixpoint_test.jl` |

**Why the front end was at `Any`.** e4eeed9 (W-32 R3, E-242) wrote TraitNonlinearSolve's `solve` as the umbrella's
ODE `solve` was then: `@nospecializeinfer`, "so a caller's code does not infer the solver again" (TDE's
`HISTORY.md`): a front end specialized on the problem's type made each caller's first call infer the solver, while
the problem's type named the function. 388cb33 added the forwarding `_solve_nonlinear`, unspecialized on the
keywords. 0483ac0 made the ODE front end typed ("what is compiled once is decided by the function's attribute, not
by `@nospecializeinfer`") and left the nonlinear one. The reason no longer holds: the problem's type names no
function under `Callable`'s default (`NonlinearProblem{T, P, Dynamic{…}, …}`), and phase B below measures it.

### Results

**The port's suite:** 35 testsets, equal to before but for the timings (`logs/q-suite-before.log`,
`logs/q-suite-nl-contract.log`, `logs/q-suite-nl-typed.log`).

**The build's check in the session** (`probes/nl_members.jl`):

| Program | before (1425aec) | after (3a1c4c3) |
|---|---|---|
| construction only (`apps/nl_prob.jl`) | 0 | 0 |
| construction and solve (`apps/nl.jl`) | 6 errors: `kwcall(TraitNonlinearSolve.solve, prob::Any, alg::Any)` (TDE.jl:66), 5 at the program's use of the result | 2 errors, both the call of the object a box of `All{Callable{NLSig{Float64}, Nothing}, Callable{NLDualSig{8}, Nothing}}` holds, `TraitWorld/src/callable.jl:42` (the residual) and `:44` (at the duals): compiler C-154, the ODE program's kind; reached now that the check reads the solver |

Logs: `logs/q-nl-before-{nl,nl_prob}.log`, `logs/q-nl-after-{nl,nl_prob}.log`.

**What a session compiles** (`probes/q_nl_session.jl`; compile ms and new instances with code per phase):

| | phase A (first solves) | phase B (new functions) | phase C (new functions, through a caller) |
|---|---|---|---|
| before (1425aec), 4 runs | 190.5, 192.6, 213.3, 221.1 ms; 192 | 56.9–60.4 ms; 29 | 97.8–112.5 ms; 86 |
| after (3a1c4c3), 4 runs | 202.1, 220.0, 222.3, 227.3 ms; 208 | 57.6–58.4 ms; 29 | 97.9–106.6 ms; 86 |

- Phases B and C list the same instances before and after: the residual's own (`sq2!`, `NLPartial{typeof(sq2!)}`,
  `AtTime{typeof(ss2!)}`, at `Vector{Float64}` and at the duals), the box's check for it, and Base's. No instance of
  the solver, the front end or the umbrella: a new residual compiles itself only.
- Phase A after: 16 instances more, once per problem type (`TDE.solve`, `_solve`, its keyword body at
  `NonlinearProblem{Float64, Vector{Float64}, Dynamic{…}, …}`; `TraitNonlinearSolve.solve`, `solve_nonlinear` at the
  trait; `nl_core`, `nl_with_problem`). The time is within the runs' spread (190 to 227 ms). A workload line in TDE's
  image (a nonlinear solve through the umbrella) took 12 of them (196 instances; 189.9, 214.2, 214.7 ms;
  `logs/q-nl-session-wl*.log`); not committed.
- The results (return code, steps, residual and Jacobian evaluations, the solution, the residual's norm) are equal.

Logs: `logs/q-nl-session-{before,after}.log` (LIST=2), `logs/q-nl-session-{1425aec,3a1c4c3}-{1,2,3}.log`.

**NetworkDynamics** (TDE 3a1c4c3, ND c2bbf0d):
- The test subset by the command of `../../w161/suites.sh nd` with this depot (`logs/q-nd-after.log`, 62 s):
  massmatrix 6/0/0/0, doctor 26/0/0/0, diffusion 108/1/1/24, inhomogeneous 39/0/1/12 (pass/fail/error/broken),
  equal to before; the same failure (`diffusion_test.jl:111`) and the same two errors (a mass matrix with an algorithm
  that takes none).
- `test/ports_callbacks_test.jl`: 14/0/0/0 (`logs/q-nd-cbtest-after.log`); before the fix 0/0/1/0, `TypeError: in
  Callable, end the function with nothing, expected Nothing, got a value of type Bool` (`logs/q-nd-cbtest-before.log`).
- `test/ports_fixpoint_test.jl`: 3/0/0/0 (`logs/q-nd-ports-after.log`); on ND 5f82334 0/0/1/0, `MethodError: no
  method matching SteadyStateProblem(::NetworkFixedT{…}, …)` (`logs/q-nd-ports-before.log`).
- `probes/q_nd_fixpoint.jl`: `find_fixpoint` with the default, NewtonRaphson and `abstol` gives the same digits on
  TDE 1d9a516 (before 1425aec) and on 3a1c4c3 with c2bbf0d (`logs/q-nd-fixpoint-at-1d9a516.log`,
  `logs/q-nd-fixpoint-after.log`); on 1425aec and on 3a1c4c3 without c2bbf0d it raises the `MethodError`.
- The subset's list of files is `ndport/scripts/r3_nd_tests.jl:43` (`const FILES`), the script `suites.sh nd` runs.

**The pattern: a user's function's value passed on where the port declares the result.** The port's signatures
with a declared result (`grep -n "Nothing}"` over TDE's `lib/*/src` and `src`), and NetworkDynamics' callers:

| TDE's signature | NetworkDynamics' caller | Verdict |
|---|---|---|
| `ODEProblem(f::Callable{RHSSig{P,T}, Nothing}, …)`; `ODEFunction(f)` | `ODEProblem(ODEFunction(nw), …)` (`post_utils.jl:77`): the network's call returns `nothing` with `RET = Val(:du)` (`coreloop.jl`) | right |
| `ODEFunction(f; jac)`, `Callable{CoreJacSig{T}, Nothing}` | no Jacobian given | not reached |
| `SteadyStateProblem(f::Callable{RHSSig{P,T}, Nothing}, …)` | `find_fixpoint`: `NetworkFixedT`, its call returns the network's `nothing` | right once a member of `Callable` (c2bbf0d) |
| `FunctionEventCallback`: condition `Callable{CondSig, Float64}`, affects `Callable{AffectSig, Nothing}` | `to_callbacks(::ContinuousCallbackWrapper)`: the condition reads `out[oidx]` of a `Vector{Float64}`; the affects wrapped `(…; nothing)` or `_signed_affect!`, which ends with `nothing` | right |
| `FunctionCallback`: condition `Callable{CondSig, Bool}`, affect and `initialize` `Callable{…, Nothing}` | `to_callbacks(::DiscreteCallbackWrapper)`: the condition returns `true`/`false`; the affect returned the closure's last value | the affect fixed (a9ea1cf) |
| the same | `to_callbacks(::PresetTimeCallbackWrapper)`: `t in ts`; the affect wrapped `(affect(integrator); nothing)`; `initialize` ends with `nothing` | right |
| `NonlinearProblem`, `NonlinearFunction` | NetworkDynamics' `NonlinearFunction` (`initialization.jl:381`) is a stub of SciML's, not TDE's | not reached |
| the user's own callback records in `add_nw_cb` | checked by TDE where they are made | the user's |

### Found

- **The definition-time check at the box reads the other branch of a split as "has no method".** Where a call's
  argument is abstract and its one method covers part of it, Julia's optimizer compiles a test and a call, and in
  the other branch `Core.throw_methoderror` (the method table is complete). `check_at_box` (TraitWorld
  `src/atbox.jl`, the `fv === Core.throw_methoderror` case) counts each such call with a value at the box as a
  fault. Traits §7.3 counts "a call left to run time that finds a method when it runs" as no fault, and only "no
  method at the types the code knows"; `Base._methods_by_ftype` finds one method at those types. Met twice here:
  `nl_with_problem(::NLCoreSolution, ::Dynamic{…}, ::Nothing)` (the abstract declared result; the code:
  `isa(%2, NLCoreSolution{Float64})`, else `throw_methoderror(nl_with_problem, %2, _2, nothing)`), and
  `solve_nonlinear(…, ::Any)` in the keyword body read at untyped keywords. The port's forms that pass: the
  operation's result names `T` (d96afc6, a rule of its own); the options converted with `Float64(x)::Float64`.
  Proposal: in `check_at_box`, a `throw_methoderror` whose callee has a method at the argument types known is the
  split's other branch, no fault; a gate with the two cases. Not changed here (TraitWorld is another tree).
- **`find_fixpoint` was broken by TDE 1425aec** and the subset did not reach it (c2bbf0d; above).
- **In a session, `Base.infer_return_type` of `solve_ode` and of `solve_nonlinear` at concrete types is `Any`**, for
  the ODE front end as for the nonlinear one, while their callees infer concrete types (`nl_core`, `solve_nl`,
  `nl_with_problem`) and the build's check resolves the program's use of the result. Not investigated.
