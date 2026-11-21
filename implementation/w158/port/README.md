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
