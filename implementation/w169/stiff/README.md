# E-537 (W-169): the steady state of a stiff ODE, and NetworkDynamics' steady state told apart

The question (the registry, `writeup/record/experiments.md`, E-537): what does the steady state of a challenging ODE
cost with the port, against the plain twin PlainODE on the same build and upstream OrdinaryDiffEq on vanilla, at equal
tolerances, with the right-hand side boxed by default and under `compiled_for`? And (§4 of the brief) what NetworkDynamics'
steady state on the port is made of, against upstream's packages on vanilla (E-514: 312–313 ms against 225–231 ms).

## How to run

From this directory, `source env.sh` (it sources the workspace's `env.sh`, sets the depots, one thread, BLAS on one
thread). Each script writes one log under `logs/`, with a header naming every tree's commit and the load.

```sh
bash time.sh <label> pollu "0 1" 3      # the six cells of POLLU, with and without callbacks, 3 fresh processes each
BRUSS_N=16 bash time.sh <label> bruss "0" 3
bash prof.sh <label> "pollu:0 pollu:1 bruss:0"     # the sampling profile, port and twin
source env.sh; jH diag.jl                # the per-call costs behind the profile's classes, and two callers' stacks
bash nd.sh <label> time 2               # NetworkDynamics' step d, each solve timed and counted
CELLS="H:ports V:ports" bash nd.sh <label> profile
source env.sh; NDW_STACK=ports NDW_API=ports jHnd $S/nd_steady.jl chains   # who reads a declared field at run time
python3 tables.py logs/time-*.log; python3 profms.py logs/prof-r1.log
```

- `problems.jl`: the problems, one text for every stack: the 2-D Brusselator (SciMLBenchmarks' form, periodic
  boundaries, `BRUSS_N`² points, 2 `BRUSS_N`² states) and POLLU (20 species, 25 reactions); in place, on a flat
  `Vector{Float64}`. The callbacks: a periodic pulse, a `DiscreteCallback` checked after each accepted step (22 pulses on
  the Brusselator, 19 on POLLU); the last before the span's end, since a pulse at the last step is saved after its
  affect by the port and upstream and before it by PlainODE.
- `run.jl <stack> <problem> <cb> <form> [time|profile|ref]`: one stack per process. Every solve: Rodas5, abstol 1e-8,
  reltol 1e-6, saveat 11 points, the Jacobian by ForwardDiff's duals in chunks of 8, dense LU (LAPACK's getrf).
  - port (the ODE port, TraitDifferentialEquations): `box` (the default: `Callable` erases; at a `Float64` state with
    no Jacobian given, the function is boxed at both signatures, `Dynamic{All{Callable{rhs}, Callable{duals}}}`) or
    `compiled` (`compiled_for(f)`);
  - plain (PlainODE): `wrap` (its default: FunctionWrappers at both signatures) or `spec` (the function itself: PlainODE's
    Rodas5 has no such path; `SpecAD` in `run.jl`, 20 lines outside its tree, the same loop as its `pjacobian!`);
  - up (OrdinaryDiffEqRosenbrock 2.7.5, LinearSolve 5.18.2, the manifest of `w159/envs/V/ndup`, nothing downloaded):
    `Rodas5(autodiff = AutoForwardDiff(chunksize = 8), linsolve = LUFactorization())`, `auto` (SciML's default
    AutoSpecialize) or `full` (`FullSpecialize`).
  - `ref`: one solve at abstol = reltol = 1e-12 (upstream, `full`), the final state into `refs/`; the error is
    max|u − ref| / max|ref| at the span's end. The port's reference of POLLU agrees with upstream's to 9.8e-15.
- `profclass.jl`: the profile's samples (0.5 ms, C frames), classed by context (the right-hand side; at duals inside
  the Jacobian; the Jacobian's rest; the factorization; the solves; callbacks; the step's arithmetic; the rest) and by
  the run-time part at the leaf (code; the box's call; dispatch at run time, its subtyping and type lookups included;
  allocation; GC).
- `nd_steady.jl` (run from `ndport/`): the workload's steps a–c, then step d's two solves (Tsit5, the stiff solver)
  timed and counted alone, and profiled. The plotting steps are not loaded.

Settings: H is `julia-next` 683ea4fc16 (two commits after the freeze), TraitWorld 38200d36df, TraitDifferentialEquations
06c28c376f, the round's environments `w159/envs/H/demo` and `w159/envs/H/nd`, images in `agent-depots/w169s/H`; V is
`julia-vanilla` 45b6d15e34 (v1.13.2). Product setting, strict mode off, one thread. A process: two warm-up solves, then
7 timed solves (the minimum and the median); 3 fresh processes per cell, interleaved over the cells. The load is in each
log (3.3 to 9.0 on 128 cores; another agent's jobs beside). The workloads are idiomatic code of each stack.

The logs not used below: `time-pollu-r1.log` (its callbacks pulsed at the span's last step, so PlainODE's final state
differed by the pulse; its runs without callbacks equal r2's); `nd-prof-r1.log` (a callback's condition, which evaluates
the network, was classed as the right-hand side; `nd-prof-r2.log` classes it as the callback's).

## Results, 2026-11-22

### The cells (`logs/time-pollu-r2.log`, `time-bruss-cb0-r1.log`, `time-bruss-cb1-r1.log`)

The minimum over the 3 processes' minima, the range of their medians. Counts: accepted and rejected steps; `nf` the
right-hand-side calls the solver counts (port and twin: at `Float64`; upstream: its Jacobian's calls included); the
Jacobians and factorizations; the calls at duals (port and twin: one per chunk of 8 columns); allocation and GC per solve.

| problem | cb | stack | form | min (ms) | medians (ms) | alloc MiB | gc ms | accepted | rejected | nf | Jacobians | factorizations | dual calls | error |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| POLLU, 20 | 0 | port | box | 0.732 | 0.741–0.748 | 0.214 | 0 | 59 | 0 | 532 | 59 | 59 | 177 | 2.09e-9 |
| | | port | compiled | 0.626 | 0.634–0.637 | 0.204 | 0 | 59 | 0 | 532 | 59 | 59 | 177 | 2.09e-9 |
| | | plain | wrap | 0.553 | 0.564–0.570 | 0.199 | 0 | 59 | 0 | 532 | 59 | 59 | 177 | 2.09e-9 |
| | | plain | spec | 0.538 | 0.545–0.551 | 0.199 | 0 | 59 | 0 | 532 | 59 | 59 | 177 | 2.09e-9 |
| | | up | auto | 0.467 | 0.475–0.488 | 0.030 | 0 | 60 | 0 | 722 | 60 | 60 | in nf | 9.83e-10 |
| | | up | full | 0.455 | 0.468–0.490 | 0.029 | 0 | 60 | 0 | 722 | 60 | 60 | in nf | 9.83e-10 |
| POLLU, 20 | 1 | port | box | 4.102 | 4.124–4.156 | 1.148 | 0 | 236 | 79 | 2836 | 315 | 315 | 945 | 9.25e-6 |
| | | port | compiled | 3.550 | 3.570–3.589 | 1.092 | 0 | 236 | 79 | 2836 | 315 | 315 | 945 | 9.25e-6 |
| | | plain | wrap | 2.950 | 2.953–3.010 | 0.999 | 0 | 236 | 79 | 2836 | 315 | 315 | 945 | 9.25e-6 |
| | | plain | spec | 2.878 | 2.899–2.926 | 0.999 | 0 | 236 | 79 | 2836 | 315 | 315 | 945 | 9.25e-6 |
| | | up | auto | 2.310 | 2.341–2.381 | 0.057 | 0 | 235 | 79 | 3454 | 235 | 314 | in nf | 8.45e-6 |
| | | up | full | 2.237 | 2.254–2.292 | 0.049 | 0 | 235 | 79 | 3454 | 235 | 314 | in nf | 8.45e-6 |
| Brusselator, 512 | 0 | port | box | 877.6 | 878.0–881.4 | 19.77 | 0 | 186 | 21 | 1864 | 207 | 207 | 13248 | 4.77e-6 |
| | | port | compiled | 875.9 | 876.2–882.1 | 19.54 | 0 | 186 | 21 | 1864 | 207 | 207 | 13248 | 4.77e-6 |
| | | plain | wrap | 874.8 | 875.9–881.8 | 19.53 | 0 | 186 | 21 | 1864 | 207 | 207 | 13248 | 4.77e-6 |
| | | plain | spec | 880.2 | 881.8–886.0 | 19.53 | 2.3 | 186 | 21 | 1864 | 207 | 207 | 13248 | 4.77e-6 |
| | | up | auto | 782.1 | 787.0–790.2 | 4.26 | 0 | 178 | 33 | 13260 | 178 | 211 | in nf | 4.26e-6 |
| | | up | full | 787.2 | 790.1–794.5 | 4.26 | 0 | 178 | 33 | 13260 | 178 | 211 | in nf | 4.26e-6 |
| Brusselator, 512 | 1 | port | box | 897.4 | 899.2–902.4 | 20.39 | 3.4 | 191 | 21 | 1909 | 212 | 212 | 13568 | 0.0222 |
| | | port | compiled | 899.0 | 900.4–902.0 | 20.15 | 0 | 191 | 21 | 1909 | 212 | 212 | 13568 | 0.0222 |
| | | plain | wrap | 897.3 | 898.4–902.9 | 19.90 | 0 | 191 | 21 | 1909 | 212 | 212 | 13568 | 0.0222 |
| | | plain | spec | 895.3 | 896.2–905.4 | 19.90 | 2.4 | 191 | 21 | 1909 | 212 | 212 | 13568 | 0.0222 |
| | | up | auto | 825.8 | 827.3–834.3 | 4.45 | 0 | 191 | 31 | 14193 | 191 | 222 | in nf | 0.00288 |
| | | up | full | 830.2 | 833.3–839.1 | 4.44 | 0 | 191 | 31 | 14193 | 191 | 222 | in nf | 0.00288 |

- **The port and the twin do the same work:** the same steps, calls, Jacobians and factorizations, the same error to the
  digits shown. Every difference between them is the cost of a step's machinery, not of the solver's work.
- **The Brusselator** (n = 512; the port's Jacobian is dense, so N = 16, a solve of 0.9 s): the dense LU is 69 % of a
  solve. The port, boxed or compiled, is within the twin's spread (876–886 ms).
- **POLLU** (n = 20, where a step's machinery shows): the port boxed 0.741–0.748 ms against the twin's 0.564–0.570
  (+32 %); compiled 0.634–0.637 against the twin's own function 0.545–0.551 (+16 %). With callbacks: 4.12–4.16 against
  2.95–3.01 ms (+39 %); compiled 3.57–3.59 against 2.90–2.93 (+23 %).
- The error with callbacks is the pulses' lag: a discrete callback fires at the end of the first accepted step after
  its time, which the step sizes decide (the reference's steps are small). Port and twin lag alike.
- Upstream (another implementation; a reference, not a baseline of the same code): POLLU 0.47 ms, 15 % below the twin;
  the Brusselator 787–794 ms, 10 % below, with fewer Jacobians (it keeps the Jacobian over a rejected step) and a
  cheaper Jacobian's seeding. Its error is of the same order.

### Where the time goes (`logs/prof-r1.log`, 8 s of solves per cell; `python3 profms.py logs/prof-r1.log`)

ms per solve by class (samples per solve × share × 0.5 ms); in brackets the part that is dispatch at run time.

| POLLU, no callbacks | port box | port compiled | plain wrap | plain spec |
|---|---|---|---|---|
| the step's arithmetic | 0.207 (0.068) | 0.200 (0.066) | 0.132 (0) | 0.130 (0) |
| the solves (getrs) | 0.170 | 0.166 | 0.163 | 0.161 |
| the factorization (getrf) | 0.156 | 0.155 | 0.154 | 0.154 |
| the right-hand side, `Float64` | 0.085 (0.067) | 0.013 | 0.010 | 0.010 |
| the Jacobian's rest | 0.060 | 0.062 | 0.067 | 0.061 |
| the right-hand side at duals | 0.043 (0.020) | 0.019 | 0.019 | 0.019 |
| the rest | 0.015 | 0.014 | 0.011 | 0.010 |
| all | 0.735 | 0.630 | 0.555 | 0.545 |

| POLLU, callbacks | port box | port compiled | plain wrap | plain spec |
|---|---|---|---|---|
| the step's arithmetic | 1.126 (0.381) | 1.032 (0.344) | 0.683 (0) | 0.670 (0) |
| the right-hand side, `Float64` | 0.464 (0.356) | 0.068 (0.007) | 0.055 | 0.049 |
| callbacks | 0.265 (0.112) | 0.312 (0.158) | 0.009 (0.006) | 0.011 (0.006) |
| the right-hand side at duals | 0.219 (0.108) | 0.104 | 0.105 | 0.109 |
| solves, factorization, Jacobian's rest, the rest | 2.07 | 2.07 | 2.07 | 2.03 |
| all | 4.140 | 3.585 | 2.920 | 2.865 |

The Brusselator: the factorization 614 ms, the Jacobian's rest 122–125, the solves 61–64, the right-hand side at duals
53–58, the step 21–24 in all four cells; dispatch at run time below 2 ms.

The classes read up close (`logs/diag-r1.log`; per call, the minimum of 7 runs of 10^5 calls):

| what | per call |
|---|---|
| the function itself, or the wrapper `compiled_for` | 0 ns (inlined) |
| a box at one signature, `Dynamic{Callable{rhs}}` | 23.0 ns |
| the box at two signatures, `Dynamic{All{Callable{rhs}, Callable{duals}}}`, at either signature | 123.7–124.3 ns |
| `linfactor` (copy and LU of 20 × 20) on a field typed `LinearSolver` / typed `DenseLU` | 3527 / 2454 ns |
| the same and 8 `ldiv!` | 6876 / 5331 ns |

- **The box at the right-hand side** (the default form): the port's default boxes the function at both signatures (the
  Jacobian is by duals), and that box costs 124 ns a call, 101 ns more than a box at one signature. The leaf C frames
  found only in the boxed cells are the type cache's (`int64hash` 4.3 %, `typekeyvalue_eq`) and the method lookup
  (`jl_lookup_generic_` 2.0 %). One reading, not verified: the call method
  `(d::Dynamic{Z})(args...) where {A, S, Z <: Callable{A, S}}` (TraitWorld `callable.jl`) binds `A` and `S` from an
  intersection, which is not decided where the call is compiled, so the call is matched when it runs. POLLU: (532 + 177) calls × 123 ns = 87 µs, against 0.11 ms
  measured between box and compiled; with callbacks (2836 + 945) × 123 ns = 0.47 ms against 0.55 ms. The Brusselator:
  15,112 calls × 123 ns = 1.9 ms of 0.88 s, within the spread. `compiled_for` removes it.
- **The linear solver kept at its trait:** `Rodas5Integrator`'s field `ls::LinearSolver` holds the solver at the trait,
  though `Rodas5{L}` knows its type. `linfactor(i.ls, W)` (rodas5.jl:204) is a call on a value known by its trait: its
  declared result `Solvable{Float64}` is asserted when it runs, and the assertion is subtyping against a set
  (`subtype_entry`, `jl_substitute_var`, `ijl_typeassert` under that line): 1.07 µs a call. The factorization is then
  typed `Solvable{Float64}`, and each of the stage's 8 `ldiv!` is dispatched when it runs: 0.48 µs a step more. POLLU:
  59 steps × 1.55 µs = 91 µs, against the 88 µs between the port compiled and the twin's own function; with callbacks 315
  attempts × 1.55 µs = 0.49 ms. `compiled_for` of the function does not remove it.
- **The callbacks' path:** per accepted step the port's discrete callback costs 1.3 µs (0.31 ms over 236 steps) against
  0.04 µs in the twin. In it: the adapter `_sync_in!` (ODECore core.jl:737) reads five declared fields of a
  `Dynamic{StepView}`, and each read computes the field's declared type when it runs
  (`_dynamic_field_type` → `declared_field_in`, 2.7 % of the samples of POLLU with callbacks, compiled); the callback kept
  at its trait (`ParamCallback.cb::Callback`); the user's condition boxed at one signature.
- Allocation and GC are equal in port and twin within 0.05 MiB per POLLU solve (the box's call boxes its `Float64` time).

### NetworkDynamics' steady state (`logs/nd-time-r1.log`, 2 fresh processes each, interleaved, load 4.1–5.3; `logs/nd-prof-r2.log`, `logs/nd-chains-r1.log`)

E-514's `again` pass, per step (its logs `w159/logs/g2-nd-r1-H-*.out`, `g2-nd-r3-V-*.out`): step d (the two solves) takes
150–153 ms on the port against 25.5 ms upstream; the plots f and g 158 ms against 197–200 ms. **The port's steady state is
slower by its solves, by 125 ms; its plots are faster by 40 ms.**

Step d's solves alone (medians over 2 processes; the minimum of 7 calls each):

| solve | port (Rodas5, saveat) | upstream, the port's variant (Rodas5, saveat) | upstream, E-514's (Rodas5P) |
|---|---|---|---|
| Tsit5 | 62.8–63.7 ms; 159 steps, 0 rejected, nf 988; 13.35 MiB | 3.02–3.17 ms; 162, 0, nf 1023; 0.165 MiB | 3.00–3.05 ms; 162, 0, 1023; 0.73 MiB |
| the stiff solver | 87.5–87.7 ms; 196 steps, 0 rejected, nf 1781 (and its Jacobians at duals); 17.9 MiB | 25.1–25.2 ms; 164, 1, nf 8078 (its Jacobians' calls included), 164 Jacobians, 165 factorizations; 1.41 MiB | 21.4–21.7 ms; 140, 2, 6910 |
| step d whole (with `remake`) | 152.6–153.0 ms | 28.7–28.9 ms | 25.0–25.5 ms |
| line trips (Tsit5, stiff) | 16, 16 | 16, 16 | 16, 16 |

The solver's work is about equal (Tsit5: 159 against 162 steps, 988 against 1023 calls); the time is not. The profile
(ms per solve; dispatch at run time in brackets):

| class | port, Tsit5 | upstream, Tsit5 | port, stiff | upstream, stiff |
|---|---|---|---|---|
| callbacks (the conditions, which evaluate the network's outputs) | 62.0 (22.7) | 2.08 (0.06) | 74.6 (27.9) | 2.64 (0.10) |
| the right-hand side, `Float64` | 3.07 (1.31) | 0.79 (0) | 5.31 (2.01) | 1.07 (0) |
| the right-hand side at duals | — | — | 5.76 (1.56) | 18.19 (9.70) |
| the step, the solves, the rest | 0.26 | 0.14 | 5.85 | 3.04 |
| all | 65.3 | 3.0 | 91.5 | 24.9 |

- **Callbacks are 95 % of the port's Tsit5 solve.** The port makes one ODECore `ContinuousCallback` per output of the
  batch's vector condition, 40 here (NetworkDynamics-unified `src/callbacks.jl` `to_callbacks`: "TDE has no vector
  condition; census item 18"), and each evaluates the whole batch's condition. Upstream evaluates one
  `VectorContinuousCallback`. So the port evaluates the network's outputs about 40 times per condition check.
- **44 % of the port's Tsit5 solve** (3405 of 7748 samples) is a declared field's type computed when it runs: the
  condition's closure reads `integrator.p` through the box `Dynamic{IntegratorView}` (callbacks.jl:475, :484, once per
  output and callback), and TraitWorld's `getproperty(d::Dynamic{X}, s)` (dynamic.jl:41) is called, not inlined, so
  `_dynamic_field_type(X, s)` runs at every read; the rest is `_sync_in!`. About 28 ms of the 63.
- The right-hand side proper: 3.1 ms against 0.8 ms (of it 1.3 ms dispatch at run time).
- Upstream's stiff solve spends 9.7 ms in dispatch at run time inside NetworkDynamics at duals, which the port does
  not: there the port is faster (5.8 against 18.2 ms).

## Findings

Each slowdown against the twin, the rule or the port's choice that produces it, its cost, whether `compiled_for` removes
it, and a proposal. No fix is built.

1. **The box at two signatures costs 124 ns a call, the box at one 23 ns.** Rule: traits §7.7 (a box of an intersection
   of `Callable`s; a call takes the signature its arguments match) and §9; the port's default boxes the right-hand side at
   both signatures where its Jacobian is by duals (traits §7.8, `ODEProblem`'s front end). The cost is the
   implementation's: the box's signatures are a constant of its type (`_signatures(Z)`, a generated constant already),
   but the call method binds `A` and `S` by `Z <: Callable{A, S}`, and the profile shows a type-cache lookup and a
   method lookup per call (the reading above, not verified). Cost: 87 µs of a POLLU
   solve of 0.74 ms (12 %), 0.47 ms of 4.1 ms with callbacks; the Brusselator 1.9 ms of 0.88 s. `compiled_for` removes
   it. Candidate: the intersection's call method at `Z <: All` without the `where {A, S}`, the signatures taken from
   `_signatures(Z)` (TraitWorld `callable.jl`, about 5 lines). Saves up to 101 ns a call (bounded by the one-signature box,
   measured); risk: a closed build's list of what the call can be, which `_call_at_signatures` keeps.
2. **A declared field read through a box computes its type at every read.** Rule: lowering §7 (a box's declared field is
   read on its object, asserted to the declared type) and traits §3.3, §7.9; the declared type is fixed once the trait is
   declared. TraitWorld's `getproperty`/`setproperty!` at `Dynamic{X}` are invoked, not inlined, so the constant name
   does not reach the compiled code and `_dynamic_field_type(X, s)` (`declared_field_in`) runs at each read, about 80 to
   100 ns. Cost: about 28 ms of the port's NetworkDynamics Tsit5 solve of 63 ms (44 %); 2.7 % of POLLU with callbacks
   (`_sync_in!`). `compiled_for` of the right-hand side does not reach it (the callbacks' integrator is boxed by the
   library). Candidate: `@inline` on the two methods, or the type as a constant per `(X, Val(s))` (2 to 6 lines);
   `_dynamic_field_type`'s effects are `+c,+e,+t,+u`, so it folds at a constant name once inlined. Saves the read's
   80–100 ns (bounded by the profile's samples, not measured with the fix).
3. **A declared result read at a trait is asserted at about 1 µs.** Rule: traits §7.9 (an operation on a value the code
   knows by its trait returns its declared result, asserted) and compiler §7.4 (every declared result read at a set is
   checked): GT-33. Here the assertion `::Solvable{Float64}` of `linfactor`'s result is a subtyping against a set when it
   runs: 1.07 µs a call (field typed by the trait against typed by the member, `diag.jl`), and the factorization typed
   by the trait makes 8 `ldiv!` per step dynamic (0.48 µs). Cost: 91 µs of POLLU's 0.63 ms compiled (14 %); 0.49 ms of
   3.57 ms with callbacks. `compiled_for` does not remove it. Proposal (a tension's text below): §7.9 says a member checked
   at its membership returns its declared result already; in a branch on a member among the first four the assertion
   could be omitted, and past them a membership of a concrete type could be answered from a cache that carries its world.
4. **The port keeps the linear solver at its trait** (a gap of the port): `Rodas5Integrator.ls::LinearSolver`, though
   `Rodas5{L}` keeps `L` and its docstring says the solver is compiled per linear solver. The integrator typed by `L`
   (traits §7.10: compile per type for kernels) removes finding 3's cost here. About 3 lines in `lib/TraitRodas`.
5. **The port's NetworkDynamics evaluates its batch condition once per output** (a gap of the port and of ODECore):
   ODECore has no vector continuous callback, so `to_callbacks` makes 40 callbacks, each evaluating the whole batch.
   Cost: most of the 60 ms of callbacks in the Tsit5 solve and 72 ms in the stiff one, beside finding 2. Proposal: a
   vector condition in ODECore (`EventCallback` with an output vector, as SciML's `VectorContinuousCallback`).
6. **The callbacks' adapter per accepted step** (ODECore `ParamCallback`, `_sync_in!`): 1.3 µs a step against 0.04 µs in
   the twin; finding 2 is part of it, the callback kept at its trait (`cb::Callback`) and the boxed condition the rest.
7. Shared by port and twin, not the design's: the Jacobian's dual buffers allocated per Jacobian (`_ad_jacobian!`,
   PlainODE's `pjacobian!`: 15 of the 19.5 MiB of a Brusselator solve), and a Jacobian per rejected step.

## Not measured, not verified

- No fix was built: the savings of findings 1–4 are bounds from the per-call costs and the profiles.
- Upstream's solves were not profiled for the stiff problems; its lower time is not attributed.
- The twin's `spec` form is written in `run.jl` (PlainODE has none for Rodas5).
- The callbacks are kept in their default form (boxed) under `compiled_for` of the right-hand side; a callback under
  `compiled_for` was not timed.
- NetworkDynamics: 2 processes per cell (not 3), one profile each; whether finding 2 also holds on the tag was not looked at.
