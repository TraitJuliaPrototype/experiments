# E-156: probes of the forms the SciML moves rely on (W-34)

The question (registry E-156; [the W-34 plan](../../writeup/plans/2026-10-21-w34-sciml-prerequisites.md) §2.1): do the forms the SciML moves 1–4 rely on work in TraitWorld as the references say? One script per probe, each with the plan's prediction by reading.

What it measures: TraitWorld's forms, neither interop (trait code calling plain code) nor idiomatic trait code as a whole. The two timing probes (P13, P15) are quick regression checks, not measurements; current numbers belong in [the evidence](../../writeup/design/evidence.md).

## How to run

From any directory, one job at a time (the shared lock, `nice -n 19`, a depot of its own first):

    ./run_probes.sh                 # every probe, serially, each in a fresh session
    ./run_probes.sh P1b P15         # some probes

- `setup_env.jl` made the environment once: TraitWorld developed from `../../TraitWorld`, ForwardDiff for P13's duals.
- `probes/common.jl`: the setting line, top-level evaluation, the checks and the result line. Modules defined directly under `Main` stand in for packages; each is an owner of its own ([traits §10.1](../../writeup/reference/traits.md#101-who-may-implement)).
- Each probe prints its checks, the plan's prediction, what the reference says, and a last line `RESULT <probe> PASS|FAIL|ERROR`.
  - **PASS:** every check matches what the reference says, its status and its Deviations table. A probe of a deviation (T-2, T-5, T-57) passes when the deviation reproduces as its row describes it.
  - **FAIL:** at least one check does not.
  - Whether the observed behaviour matches the plan's prediction is a separate column below.
- Timing (P13, P15): a hand loop of 10⁶ calls inside a typed function after warm-up, the best of five timings, and `@allocated` over one loop divided by the calls.
- Logs: `logs/<probe>.log`; `logs/run_probes.out` is the driver's summary.

## The build and the run

- julia-1.13 2943086604 (W-33). `Base.GIT_VERSION_INFO` prints `6d480d0753*`: the binary was built from the working tree that was then committed as 2943086604 (sys.so 2026-10-21 20:52, the commit 21:05).
- TraitWorld f06b82d, clean. The product setting (no `-J facts sys.so`), strict mode off (`JULIA_TW_STRICT=0`), one thread.
- Each probe in a fresh session after TraitWorld, one run. The machine's load (`/proc/loadavg`, 1/5/15 min) is at the top and the bottom of each log.

## Results (2026-10-22)

Build julia-1.13 2943086604, TraitWorld f06b82d, product setting, strict mode off, one run per probe, load 0.7–1.5 (logs). "Prediction" is the plan's (§2.1); "verdict" is against the reference, its Deviations included.

| Probe | Form | Prediction (plan) | Observed | Reference says | Verdict | Matches the prediction |
|---|---|---|---|---|---|---|
| P1a | `@implement X S{T} where {T} begin … end`, inside and outside the trait's module; the joint form with a block | not a family: a call reports "conforms to none" (T-5) | non-joint: declared, a call raises `MethodError` with the hint, in both modules. Joint (`SV{T} Ser{T} where {T} begin … end`): **`UndefVarError: T` at the declaration**, in both modules | §4.7 with T-5: the declaration taken as one type, a call raises `MethodError` | FAIL (the joint half: T-5's row describes a different failure) | non-joint yes; joint no |
| P1a′ | `@implement X A where {A <: S} begin … end` | outside refused by the precheck (T-57); inside works | as predicted | §4.7 with T-57 | PASS | yes |
| P1b | no-block families `S{T} where {T}` and `A where {A <: S}` by the type's owner outside the trait's module: operations without parameters, a trait of fields with parameters plus an operation, the joint form | works; members checked at first use | all work, typed and at the top level; a write through a declared field works; a non-conforming member (`Bad{Float64}`) refused at first use with `ImplementError` | §4.7, §10.1: Implemented | PASS | yes |
| P1c | the same declared by a third package | accepted (no ownership check) | **`S{T} where {T}` accepted** for a trait without parameters and for a trait whose parameters all come from fields, and the members work; `A where {A <: S}`, the joint form `SV{T} Ser{T} where {T}` and the concrete control are refused (rule 3) | §4.9, §10.1: refused | FAIL | yes for the `S{T} where {T}` form with field-defined or no parameters; no for the other two forms |
| P5 | `@trait Integrator{U, T, P} <: IntegratorView{U, T, P}`; subtrait beats supertrait | works | the trait declares, but **the first bounded function on it raises `UndefVarError: U`**; the family needs the parameters stated (joint form). Variant B (`<: IntegratorView` bare, parameters stated by a joint family) works: the subtrait's method wins, the supertrait's fields read through the subtrait's bound | §3.6 Implemented; the grammar takes a supertrait with parameters; no rule relates them | FAIL | no (the plan's form); B works |
| P7 | a default naming the trait's parameter | `UndefVarError` (T-2) | `UndefVarError: T` when the default runs | §3.2 with T-2 | PASS | yes |
| P8 | `struct Callback{U, T, P}` of `Callable{Tuple{U, T, Dynamic{IntegratorView{U, T, P}}}, Bool}` fields; `Vector{Callback{U, T, P}}` in the integrator; entered at `init` | works | works for two `P` types; `integ.p` and `integ.t` read in plain code infer at `P` and `T`; a condition returning `Int` refused at the call (`TypeError`, message "non-boolean (Int64) used in boolean context") | §7.2, §7.5, §7.1: Implemented | PASS | yes |
| P9 | no-block family over a mutable type with its own `getproperty`, every field mapped (`u => u, t => _t, p => p`) | works | works: fields read and written at the stored fields, the operation by the owner's method. But **no field check for family members**: no mappings with an own `getproperty` accepted; a writable declared field on a **`const` stored field written through the trait**; a wrong field type gives `TypeError` at the write; a missing field `FieldError` at the use. A concrete type with its own `getproperty` and no mappings is refused, as the reference says | §3.3, §4.4, §4.9 (at a member's first use): Implemented | FAIL | the main form yes; the checks no |
| P10 | `struct Problem{F <: ODERHS}` under `@default_with_dynamic_self`, two plain models | works (one problem type) | `Problem{Dynamic{ODERHS}}` for a concrete model and a family member, from the top level and typed callers; `compiled_for` gives `Problem{Decay}`; a trait-world model gives `Problem{OwnModel}` | §7.4, §6.3: Implemented | PASS | yes |
| P11 | `solve!(integ::Integrator{U, T, P}, prob::ODEProblemTrait{U, T, P}) where {U, T, P}` | works | matched pairs run; `U, T` or `P` disagreeing raise `TraitBoundError` naming the parameter, typed and at the top level. **`integ.u .+= integ.du` on a declared field raises `TraitUseError`** (Julia lowers it to `Base.dotgetproperty`) | §3.4, §5.1, §3.3: Implemented | FAIL (the `.+=` check only) | yes for the link |
| P12 | `init(prob::ODEProblemTrait{U, T, P}, alg)::Integrator{U, T, P}` as an operation; opened with `compiled_for` | unprobed (option (d)) | declared and accepted; **every call raises `TypeError: in typeassert, expected Integrator{…}, got EulerInteg{…}`**: the result is asserted to the trait's type, not made a `Dynamic` | §6.2: an operation's result declared with a trait is `Dynamic` (Implemented) | FAIL | — |
| P14 | joint family `Tsit5For{U, T, P}` implementing `ODEAlgorithmFor{U, T, P}`; `init(a, …)::Integrator{U, T, P}`; `configure(alg::Tsit5, prob)` | unprobed (option (e)) | the joint family is declared; its members are **refused at first use: `init` returns `Tsit5Integ{…}`, declared `Integrator{…}`** (as P12). **A solver package's bounded method `Core1.configure(alg::Tsit5, prob::ODEProblemTrait{…})` beside the core's `configure(alg, prob::ODEProblemTrait)` is refused (L-3)**, and so is the plan's §1.4 route `Core1.__init(prob::ODEProblemTrait, alg::MyAlg)`: an ordinary argument's type is part of the entry's shape | §4.7; §6.2; §5.5 with L-3 | FAIL | — |
| P13 | form A: `rhs!(f::ODERHS, du::AbstractVector, u::AbstractVector, p, t)::Nothing` on a `Dynamic` value | concrete: no allocation; family member: allocates | concrete (`Lorenz`, one line): 3.19 ns Float64, 4.70 ns duals, 0 bytes (plain call 3.02 / 4.37 ns). Family member (`ChainModel{Vector{Int}}`): 241 / 246 ns, **80 bytes** per call | §6.8; L-37 (304 bytes) | PASS | yes (80 bytes, not 304) |
| P15 | a bounded function called in a typed plain loop: family member against members declared on their own | family 304 bytes per call; declared none | family member: 384 ns and **208 bytes** per call (S{Float32}: 456 ns, 208 bytes); declared on its own (also `S{Float64}` declared after its family): 0.96 ns, 0 bytes. The same work as one bounded call with the loop in trait code: 0.96–0.98 ns per iteration for all four, 0 bytes | L-37 | PASS | yes (208 bytes, not 304) |
| P15 again (2026-10-27, julia-1.13 26a407d988: W-40) | the same | the family member at the declared member's cost | family member 0.88 ns, **0 bytes** per call (S{Float32} 0.88 ns, 0 bytes); declared 0.87 ns, 0 bytes; the probe's RESULT reads FAIL because its prediction is the old allocation (`logs/P15-w40.log`) | L-37 retired | — | yes |
| P13 again (2026-10-27, the same build) | the same | the family member at a declared model's cost | ChainModel (family member) 3.01 ns, duals 4.26 ns, 0 bytes; Lorenz 2.97 / 4.32 ns; plain call 2.97 / 4.34 ns (`logs/P13-w40.log`) | — | PASS | yes |
| X1 | a bounded function named like an unused Base export (`peek(x::X) = …`), found while writing P1b | — | refused: "`peek` belongs to Base; … only where it already has an entry of that shape (rule 3)"; plain Julia defines a new function of the module | §2, §5.5 | FAIL | — |


## Findings

Failures where the reference says Implemented (candidates for deviation rows; the coordinator decides):

1. **A family `S{T} where {T}` without a block runs no ownership check** (P1c) when the trait has no parameters or all its parameters come from fields: a third package's declaration is accepted and works. Also no extension-trigger check. `TraitWorld/src/implement.jl:1473`–`1488` (`_implement_projection`, the branch "a family conforming by its fields" returns without `_check_implementation`). Reproducer: `module Third; using TraitWorld, ..TraitPkg, ..SolverPkg; @implement TraitPkg.ODEAlgorithm SolverPkg.Tsit5{C} where {C}; end`.
2. **Family members' fields are not checked** (P9): the same branch skips `_check_projection` (so `_field_problems`, `implement.jl:580`), and `_member_problems` (`implement.jl:830`) checks operations, parameter bounds and concreteness only. Consequences: an own `getproperty` without mappings accepted; **a trait write stores into a `const` field** (TraitWorld writes fields by pointer, `src/core.jl:131`–`140`); a wrong field type gives a `TypeError` at the write, a missing field a `FieldError` at the use, instead of `ImplementError` at the first use. Reproducer: `mutable struct ConstF{T}; x::T; const u_modified::Bool; end; @implement Flagged ConstF{T} where {T}` with `@trait Flagged begin u_modified::Bool end` and `setflag!(f::Flagged) = (f.u_modified = true; nothing)`: afterwards the `const` field is `true`.
3. **An operation's result declared with a trait** (P12, P14) is asserted to the trait's type: `TypeError` at every call (`src/core.jl:1060`, `return x::RT` in `opcall`), and a member whose method returns a conforming type is refused by the result check (`ImplementError`: "returns `Tsit5Integ{…}`, declared `Integrator{…}`"). Traits §6.2 lists "an operation's result declared with a trait" as Implemented.
4. **A supertrait with parameters** (P5): `@trait Integrator{U, T, P} <: IntegratorView{U, T, P}` declares, but `supertraits(::Type{Integrator}) = (IntegratorView{U, T, P},)` is defined without a `where` (`src/trait.jl:335`), so the first bounded function on the subtrait raises `UndefVarError: U`. A subtrait's parameters are not taken from its supertrait's fields either (`implement.jl:1477`–`1478`, `trait_field_params` of the subtrait alone): the family needs them stated. The grammar admits the form; §3.6 has no rule for it, so this may be an open issue rather than a deviation.
5. **`integ.u .+= x` on a declared field** (P11) raises `TraitUseError` ("passed to `dotgetproperty`, an ordinary function"): Julia lowers a dotted update of a field to `Base.dotgetproperty`, which the definition check does not treat as a field read (`src/checks.jl:150`, `:218`). Workaround: `u = integ.u; u .+= x`.
6. **The joint family with a block** (P1a) fails with `UndefVarError: T` at the declaration, not as T-5 describes (declared, then `MethodError`): `implement.jl:1169` (`_param_methods` with no `where` variables, so `param(…) = T` and `_param_agrees` evaluate `T`). T-5's row needs this case.
7. **X1:** a bounded function whose name Base exports but the module never used is taken as Base's function and refused by the L-3 rule (`src/trait_module.jl:828`–`831`). Plain Julia defines a new function of the module.

Against the plan rather than the references:
- **L-3 refuses the plan's §1.4 route for move 3** (P14). A non-owner's bounded method needs an entry of the same shape, and the shape includes the ordinary arguments' declared types (`trait_module.jl:685`: `pattern`). So `Core1.__init(prob::ODEProblemTrait, alg::Tsit5)` from a solver package is refused even when the core has `__init(prob::ODEProblemTrait, alg)`. This is the L-3 row as written ("a shape the function has none of yet"), but it means an open set of solvers cannot extend the core's bounded functions by their own types. The route needs W-36, or another spelling.
- **Per-call cost of a family member:** 80 bytes per call in form A (P13), 208 in P15, not the 304 of L-37 (measured in `test/untyped.jl`'s setting). The gap is a plain caller's call into a bounded function (384 ns against 0.96 ns); inside one bounded call there is none.


---

# E-157: move 1 in form B, with move 5's check (TDE, W-34)

The question (registry E-157; [the W-34 plan](../../writeup/plans/2026-10-21-w34-sciml-prerequisites.md) §2.2, §1.2): with SciML's split of a plain `ODEFunction` record and a problem that keeps the function at bounded `Callable` parameters, (1) are TDE's `RESULT` lines unchanged, also with the chunk entered at `init`? (2) What does an `rhs!` call cost and allocate, `Dynamic` against `compiled_for`, with a `Vector` and a named-tuple `p`? (3) How many allocations per Tsit5 step (40 states, 1,000 steps)? (4) Does a new model type or function compile no CodeInstance of the solver's functions? (5) Is an `f` returning `du` refused at its first call? (6) Is a `Trajectory` helper compiled once per key, with one solution type for two models?

What it measures: interop, library trait code (TDE's solvers) calling plain functions and a plain callable model. The timings are quick regression checks, not measurements; current numbers belong in [the evidence](../../writeup/design/evidence.md).

## What was built (TDE branch `w34`, 29f0641, from `main` fbb9bd8)

- **`ODEFunction{F, TJ, TMM}`** (the ordinary module): SciML's plain record of the user's functions, `ODEFunction(f; jac = nothing, mass_matrix = I)`. No parameter for `u`'s or `p`'s type.
- **`ODEProblem{T, P, F, D, J}`** (ODECore): `f::F` at `RHSSig{P, T}`, `fd::D` at `DualSig{P, 8}` (as on `main`), and `jac::J` at `JacSig{P, T} = Tuple{Matrix{T}, Vector{T}, P, Float64}`, each a struct parameter bounded by `Callable` (traits §7.4). Without a Jacobian, `J` is the library's own `no_jacobian`, cast `compiled_for`, so `jacobian!` folds on `J`. The function as given is kept beside, in a `UserFunction` holder (field `fplain`).
- **`jacobian!`** stays the trait's operation with its default (finite differences); `ODEProblem`'s method calls the given Jacobian when `J` is not `no_jacobian`, else duals (chunk 8) for a `Float64` state.
- **The chunk per problem:** a new trait operation `rhs_function(prob)::Any = nothing`; `ODEProblem` returns the function as given (or `nothing` when a Jacobian was given). `Rodas5(chunk_size = 0)` enters it at Rodas5's `init` (`rodas5_solve`) at the duals of a chunk picked from the state's length (`ForwardDiff.pickchunksize`; `chunk_size = N` fixes it): `DualJacobian{P, N, FD <: Callable{DualSig{P, N}, Nothing}}`, held by `Rodas5Integrator{P, JC}`. The driver `rodas5_run` is a function barrier compiled per `N`. `Rodas5()` keeps the problem's `jacobian!`.
- **`examples/ChainModels`:** a plain package that knows nothing of TDE or TraitWorld. `ChainModel{G}`, a diffusion with cubic damping on a graph of type `G` (`PathGraph`, `RingGraph`, `EdgeList`), callable as `m(du, u, p, t)`, `p` a `Vector` `[k, d]` or a named tuple `(k, d)` or `(k, d, w)`.
- **`Trajectory{U, T}`** (ODECore): operations `times(s)::Vector{T}`, `state(s, k)::U`, `at(s, τ::T)::U` (linear between saved states). `@implement Trajectory{Vector{T}, Float64} ODESolution{T} where {T}`. The solution keeps no problem.
- TDE's suite: 85 checks pass, 1 broken as on `main` (`test/w34.jl` adds 21).

## How to run

From any directory, one job at a time (the shared lock, `nice -n 19`, the depot `/tmp/claude-1000/depot-w34` first):

    m1/run_all.sh run1          # check 1 (the session, both chunk paths), then checks 2–6, each in a fresh session
    m1/run_tests.sh <label>     # TDE's suite on the checkout as it stands
    m1/run_session.sh <label> [chunk]   # check 1 alone; `chunk`: every Rodas5() as Rodas5(chunk_size = 0)

- `m1/setup_env.jl` made the environment once: TraitWorld, TDE, LorenzModels and ChainModels developed from the checkouts; ForwardDiff; SnoopCompileCore.
- `m1/common.jl`: the setting line, the load, and the CodeInstance count (below).
- Check 1 runs TDE's `scripts/session.jl trait` in TDE's own environment (`scripts/env`) and compares its `RESULT` lines with `main`'s (`logs/session-main-{1,2}.log`, TDE fbb9bd8). `session_chunk.jl` is the session with `Rodas5()` replaced by `Rodas5(chunk_size = 0)`, made by `run_session.sh`.
- **Counting CodeInstances (checks 4, 6):** every method of the given modules from Julia's global method table (`Base.visit(Core.methodtable)`); for each, `Base.specializations(m)` and the CodeInstances in each MethodInstance's cache, keyed by (MethodInstance, owner): `plain`, `facts` (the facts compiler's), or TraitWorld's check owner (inference for its checks). A snapshot before and after a step; the difference is what the step compiled. Check 4 counts ODECore and TraitDifferentialEquations (the solvers, the problem, the integrators, the front end) and, for context, every module; SnoopCompileCore's `@snoop_inference` lists the methods inferred, by module, as a second view (it agrees). A control (`compiled_for`) shows that the count sees new solver code.
- `m1/repro_nonbits_box.jl`: the minimal reproducer of finding 1.
- Logs: `m1/logs/<check>-run{1,2}.log`, `session-*.log`, `tests-*.log`. `m1/logs/dev/` holds the logs of the build's first commit (0bb297b), kept because they show what finding 3 and 4 below found.

## The build and the run

- julia-1.13 2943086604 (prints `6d480d0753*`, as for E-156), TraitWorld c655dde, TDE 29f0641 (branch `w34`), the product setting, strict mode off (`JULIA_TW_STRICT=0`), one thread.
- TDE's load order: TDE, its example packages, then the script. Two runs of each check (`run1`, `run2`), each check in a fresh session; the load (`/proc/loadavg`, 1/5/15 min) is at the top and the bottom of each log: 0.5–1.1 throughout.

## Results (2026-10-22)

Build julia-1.13 2943086604, TraitWorld c655dde, TDE 29f0641, product setting, strict mode off, two runs, load 0.5–1.1. Interop.

| Check | Outcome | Key numbers (run 1 / run 2) |
|---|---|---|
| 1 `RESULT` lines | **unchanged**: the 9 lines identical to `main`'s, on both chunk paths; the session passes (14 checks) | `main` ×2, `w34` ×2, `w34` chunk at init ×2: all identical (Tsit5, Rodas5, `Float32`, two gradients, an edited function). Rodas5 with chunk 3 at init gives the same bits as chunk 8 |
| 2 per `rhs!` call (through the problem's bound, as the solver calls it) | `Dynamic` below 10 ns, no allocation for `Vector` and bits named-tuple `p`; **a named tuple holding a vector is boxed at every `Dynamic` call** | Lorenz, `Vector` p: `Dynamic` 7.57 / 7.76 ns, `compiled_for` 1.46 / 1.52, direct 1.46 / 1.49, 0 bytes. Bits named tuple: 8.82 / 8.37 ns, 0 bytes. Named tuple holding a vector: 14.77 / 15.77 ns, **32 bytes, 1 allocation** per call (`compiled_for` 3.18 / 3.34 ns, 0 bytes). ChainModel (40 states), `Vector` p: 37.3 / 32.8 ns against 30.0 / 27.9 `compiled_for`; with the non-bits named tuple 44.6 / 46.0 ns, 32 bytes |
| 3 allocations per Tsit5 step (40 states, 1,001 steps, 6 f calls per step) | **none**, except one box per call for the non-bits named tuple under `Dynamic` | 0 bytes / step for `Vector` and bits named-tuple `p`, both modes (53 allocations per 1,000-step solve: the setup); non-bits named tuple, `Dynamic`: 192 bytes, 6 allocations per step. ns per step 445–488 (`compiled_for` 443–459). For information, Rodas5: 6,304 bytes / 8 allocations per step with the problem's Jacobian (chunk 8; `ad_jacobian!` allocates its dual buffers per Jacobian), 400 bytes / 2 with the chunk at init (the LU) |
| 4 no new solver code for a new model or function (`Dynamic`) | **none** | New CodeInstances in ODECore + TraitDifferentialEquations: `ChainModel{RingGraph}` 0, `ChainModel{EdgeList}` 0, a new function 0, a closure with a named-tuple `p` 0 (Tsit5, Rodas5 both paths, `saveat`); control `compiled_for(ChainModel{RingGraph})`: 31. What a new model does compile: itself at its signatures (ChainModels 8 per key) and TraitWorld's 10 per function (`_fptr` and `_CallWrap` at the three signatures used, `Float64`, duals 8, duals 10, and one `Erased` constructor at the init chunk's signature), plus Base's code the model's own body needs |
| 5 an `f` returning `du` | **refused at its first call** under `Dynamic` (`TypeError: expected Nothing, got Vector{Float64}`); **before any call** under `compiled_for` (`ImplementError` at the problem's first use, naming `rhs!` at the declared arguments) | The same for a callable model returning `du`, and for a given Jacobian returning `J` (`TypeError` at its first call; `ImplementError` at the problem's first use under `compiled_for`). Construction is not refused under `Dynamic` (as on `main`, the suite's `@test_broken`) |
| 6 a `Trajectory` helper | **compiled once per key**; one solution type `ODESolution{Float64}` for a function, two `ChainModel`s, a `compiled_for` model and a problem type (`LorenzProblem`, Rodas5) | Two helpers (`sample`, `final`) in a trait module of their own: the first call 8 CodeInstances (an entry and a body per helper, and their bookkeeping), every further model 0, a `Float32` state (a new key) 4, a dynamic call 2 (the entry at `Any`, the body at `Dynamic`) |

### Findings

1. **A `Dynamic{Callable}` call boxes an immutable non-bits argument** (check 2, 3): a named tuple `p` that holds a vector costs one allocation per call (32 bytes in TDE, 16 in the reproducer) and ~7 ns. A bits named tuple and a `Vector` cost nothing. The caller passes non-bits values as `Any` (`TraitWorld/src/core.jl:1118`, `_ctype`; the `ccall` at `:1146`); lowering §12 says "Non-bits arguments go boxed", so this is the lowering as written, and the registry row names it a lowering deviation row. Under `compiled_for` nothing is boxed. Reproducer: `m1/repro_nonbits_box.jl`.
2. **The `Dynamic` call's overhead is ~6 ns** against a direct call (7.6–7.8 against 1.5 ns for Lorenz), above the evidence's 3.95 ns for a bare `Callable` call (a different body, through the problem's `rhs!` method and the kept `Dynamic{Callable}`'s extra load, open issues §4 item 35, P4). Below the row's ~10 ns.
3. **A field typed `Any` in the problem specialized its constructor per model type** (first commit 0bb297b, `logs/dev/check4-run1.log`): the explicit-parameter constructor `ODEProblem{T, P, F, D, J}(…)` was compiled per type of the function stored in `fplain::Any` (2 CodeInstances for `ChainModel{RingGraph}`, one per key; `Function` subtypes are not specialized, so plain functions showed 0). Fixed in TDE by a `UserFunction` holder with a `@nospecialize` inner constructor (29f0641). The design is not involved; the lesson is for ports that keep a raw value beside a kept one (principled traits §10.3).
4. **The member check caught an error in the build's own `Trajectory` conformance** (`logs/dev/check6-try1.log`): `at` returned `Vector{Float64}` for a `Float32` solution; at its first use `ODESolution{Float32}` was refused with an `ImplementError` naming `at` and both types. Fixed (`θ` at the element type).
5. **A per-function `Erased` constructor at the init chunk's signature** (check 4): entering the function at `DualJacobian`'s bound from trait code compiles TraitWorld's `Erased{A, S}` constructor once per function type there; at the problem's bounds (entered from the ordinary module, `@nospecialize`) it does not. One small CodeInstance of TraitWorld's per new function, none of the solver's.

### Deviations met

None of T-62, T-64, T-65, T-66, T-67, L-3 is on this build's path: `init` is an internal function returning a concrete integrator (no trait-typed result, T-64), no dotted update of a declared field (T-65), no Base-like names (T-66), no supertrait (T-67), every bounded method in its function's owner (L-3). On the path but not limiting:
- **L-37:** TDE's `ODEProblem` and `ODESolution` are family members, so each plain call into a bounded function (`solve_ode`, once per solve; a `Trajectory` helper, once per call) takes the family's registry path. Once per solve, not per step; not measured here.
- **T-54:** a kept `Dynamic{Callable}` made at one signature enters the problem's dual bound (as on `main`) and, on the init path, `DualJacobian`'s; the design refuses it (§7.5). The suite's check of that case predates this branch.

### Pushback (idiomatic code against the design)

- **A function the solver enters at signatures of its own choosing** (the chunk at init): the trait cannot state "a function callable at the duals of any chunk", so the problem hands out its raw function as an operation's result `::Any` (`rhs_function`), and the solver enters it at its own bound. A `Callable` bound whose argument types the callee chooses is open issues §2 item 10. Recorded as a choice that works within the design; the escape is the `Any`.
- **No optional bounded parameter:** a `Callable` parameter cannot be "absent". The problem keeps a library marker (`no_jacobian`, compiled) at `J`, so a problem with a Jacobian and one without are two types, and the solver compiles once for each (as SciML's `f.jac === nothing` does in its type).
- **An immutable `p` is boxed per call under `Dynamic`** unless it is a bits type (finding 1): SciML's `p` is often a named tuple holding arrays. Within the design: `compiled_for(f)`, or a mutable `p`.
- **The mass matrix:** the record carries it; TDE's solvers take `I` only (`ArgumentError` otherwise). Not in move 1's checks.

### Choices made (mine)

- `jacobian!` keeps TDE's name (the plan's `jac!`); the existing API (`ODEProblem(f, …)`, `Rodas5()`, `jacobian!` of problem types) is unchanged.
- `ODEFunction` lives in the ordinary module; the problem's front end reads it under `@nospecialize`, so no record is built per function.
- The absent Jacobian is the library's own function at `J`, cast `compiled_for`, rather than a `Bool` field or a `Union` field.
- The chunk path is opt-in: `Rodas5(chunk_size = 0)` picks the chunk, `chunk_size = N` fixes it; `Rodas5()` keeps the problem's Jacobian. A given Jacobian wins over the chunk path (`rhs_function` returns `nothing`).
- The init-chunk function sits in a helper struct `DualJacobian` held by the integrator (`Rodas5Integrator{P, JC}`), not in a bounded parameter of the integrator itself, so the integrator needs no marker when the problem's `jacobian!` is used.
- `Trajectory`'s operations are not exported (`times`, `state`, `at` are common names); `at` interpolates linearly; the solution keeps no problem, so its type stays independent of `P`.
- `ChainModel{G}` lives in a TDE example package that depends on nothing; checks 2–6 use it.


---

# E-158: move 2, callbacks and the integrator view as traits (TDE, W-34)

The question (registry E-158; [the W-34 plan](../../writeup/plans/2026-10-21-w34-sciml-prerequisites.md) §2.3, §1.3): with callbacks as `Callback{U, T, P}` kept in a vector of the integrator, entered at `init` as records of `Callable` fields, and seeing the integrator as `Dynamic{IntegratorView{U, T, P}}` with operations, (1) are event times and states equal to a typed control (PlainODE) bit for bit, discrete first, then a scalar continuous callback? (2) Does a new callback compile nothing in the driver, with one integrator type for two callback sets? (3) Is `integ.p` typed in a callback? (4) Is a callback type without `affect!` refused at `@implement`? (5) What does a step with two callbacks cost and allocate against the control?

What it measures: idiomatic trait code (TDE's solvers over trait-typed callbacks and the integrator view), against the same solver in plain Julia. The timings are quick regression checks, not measurements; current numbers belong in [the evidence](../../writeup/design/evidence.md).

## What was built (TDE branch `w34`, cccc517, from E-157's 29f0641)

- **`IntegratorView{U, T, P}`** (ODECore): the fields `@const u::U`, `@const t::T`, `@const dt::T`, `@const p::P`, `u_modified::Bool`, `terminated::Bool`; the operations `add_tstop!(i, τ::T)`, `terminate!(i)`, `interp!(i, out::U, τ::T)` (the state within the last accepted step, by the solver's interpolant). `Tsit5Integrator{T, P}` and `Rodas5Integrator{P, JC}` conform as no-block families, by their own methods; `U`, `T`, `P` come from the fields.
- **`Callback{U, T, P}`** (`condition(cb, u::U, t::T, integ::Dynamic{IntegratorView{U, T, P}})::Bool`, `affect!(cb, integ)::Nothing`) and **`EventCallback{U, T, P}`** (`event_condition(…)::Float64`, `event_affect!(…)::Nothing`).
- **The user's records:** `DiscreteCallback(condition, affect!)` and `ContinuousCallback(condition, affect!)`, plain structs of two `Any` fields (`@nospecializeinfer` constructors). At `init` (`enter_callbacks`) each becomes a `FunctionCallback{U, T, P}` / `FunctionEventCallback{U, T, P}` of two `Kept{Callable{…}}` fields at the problem's `(Vector{T}, Float64, P)`, a joint no-block family implementing the trait. A value of a callback type is kept as `Kept{Callback{U, T, P}}` (or `EventCallback`, by `conforms`).
- **The integrator keeps** `Vector{Callback{Vector{T}, Float64, P}}` and `Vector{EventCallback{…}}` (struct fields; `Kept{…}` in a trait module). Tsit5's `init` (`tsit5_init`) is split from its driver (`tsit5_run!`).
- **The driver:** tstops (the step clipped to the next one, `t` set to it exactly); after an accepted step the continuous callbacks (the earliest sign change, bisection on `interp!` to `Float64`'s resolution, `event_time`, the integrator moved to the last time before the crossing, the state saved there, `event_affect!`, `f(u, t)` again; the fired callback's next check starts a hundredth into the next step, SciML's repeat nudge), then the discrete ones as before. Rodas5: tstops and discrete callbacks; a continuous one is refused (`ArgumentError`).
- **The control** (`baselines/PlainODE`): the same driver text (`event_time` verbatim), the integrator itself as the view, `add_tstop!`/`terminate!`/`interp!` as plain functions; `solve_typed(prob, Tsit5(); callbacks, events)` takes typed records (`TypedDiscreteCallback{C, A}`, `TypedContinuousCallback{C, A}`) in tuples, the discrete ones unrolled by recursion, so the driver is compiled per callback set (SciML's form). PlainODE's `solve` keeps its untyped `Vector{Any}`.
- **Following the design:** `LorenzModels`' `Bounce` and `RaiseSigma` implement `Callback{Vector{Float64}, Float64, LorenzParams{Float64}}` (`RaiseSigma` reads `integ.p.σ` without an assertion); the session's `ResetZ` implements `Callback{Vector{Float64}, Float64, Vector{Float64}}`. The front end's API (`ODEProblem`, `solve(…; callback)`, `DiscreteCallback`, closures writing `i.u`, `i.p`, `i.terminated`) is unchanged.
- TDE's suite: 95 checks pass, 1 broken as on `main` (`test/w34_move2.jl` adds 10).

## How to run

From any directory; every Julia job through `m2/jl.sh` (the shared lock, cores 0–1, `ionice -c3`, `nice -n 19`, one thread, one precompile task, the depot `/tmp/claude-1000/depot-w34` first):

    m2/run_all.sh run1          # the session's RESULT lines, then checks 1, 2, 3+4, 5, 5 hot, each in a fresh session
    m2/run_tests.sh <label>     # TDE's suite on the checkout as it stands
    m2/run_session.sh <label>   # TDE's session (scripts/session.jl trait): RESULT lines against main's (../m1/logs/session-main-1.log)

- `m2/setup_env.jl` made the environment once: TraitWorld, TDE, LorenzModels and PlainODE developed from the checkouts; ForwardDiff; SnoopCompileCore.
- `m2/common.jl`: the setting line, the load, `check`, and the CodeInstance count (E-157's).
- `m2/models.jl`: the user's models and callbacks (an oscillator with mutable parameters and three discrete callbacks: a kick at `p.tk` re-armed by `add_tstop!`, a write to `p.c`, `terminate!`; a bouncing ball with two continuous callbacks, the ground and the apex, and a discrete one writing `p.e`), written once, for TDE and the control.
- **Check 2's count:** as E-157 check 4, each step called behind `invokelatest`, so that it is not inferred with the harness. The new CodeInstances of ODECore and the front end are split into the driver and `init` (ODECore), the callbacks' operations at a callback type (that type's own entries), and the front end (the ordinary module).
- **Check 5:** best of five solves, ns per accepted step; `@allocated` over one solve per step. `hot`: the members the loop uses (`FunctionCallback{Vector{Float64}, Float64, Vector{Float64}}`, `Tsit5Integrator{Float64, Vector{Float64}}`) declared on their own in ODECore before their first use, L-37's workaround.
- Reproducers: `m2/repro_typed_array.jl` (finding 3), `m2/repro_kept_params.jl` (finding 4), `m2/repro_nospecialize.jl` (a note on `@nospecialize`).
- Logs: `m2/logs/<check>-run{1,2}.log`, `session-w34-run{1,2}.log`, `tests-w34-cccc517.log`, `run_all.out`; `m2/logs/dev/` the logs of the build's uncommitted states (a failing ball test before the repeat nudge).

## The build and the run

- julia-1.13 2943086604 (prints `6d480d0753*`), TraitWorld 2e9ed68, TDE cccc517 (branch `w34`), the product setting, strict mode off (`JULIA_TW_STRICT=0`), one thread.
- TDE's load order: TDE, its example packages, the control PlainODE, then the script. Two runs (`run1`, `run2`), each check in a fresh session; the load (`/proc/loadavg`, 1/5/15 min) is at the top and the bottom of each log: 2.1–2.6 throughout (the user at work on the machine).

## Results (2026-10-22)

Build julia-1.13 2943086604, TraitWorld 2e9ed68, TDE cccc517, product setting, strict mode off, two runs, load 2.1–2.6. Idiomatic trait code.

| Check | Outcome | Key numbers (run 1 / run 2) |
|---|---|---|
| 0 TDE's `RESULT` lines | **unchanged**: the 9 lines identical to `main`'s; the session passes, with its new callback type at the prompt | both runs |
| 1 event times and states | **identical to the typed control, bit for bit**, in every variant: `sol.t`, `sol.u`, retcode, step and call counts, the event log (name, time, state) and the final parameters; TDE with `Dynamic` and `compiled_for` functions, the control typed and untyped | Stage 1 (discrete, oscillator): 10 events, the kicks after the first exactly at 2.0, 3.0, …, 8.0 by `add_tstop!`, the stop by `terminate!` at 8.505; every step saved, `saveat`, and tolerances 1e-10. Stage 2 (continuous, ball, 0 ≤ t ≤ 4): 13 events; the first contact at 0.45152364098573 (`sqrt(2/g)` within 2e-15); the ball never below −1e-9 |
| 2 no driver code per callback | **none**; one integrator type `Tsit5Integrator{Float64, OscParams}` for two callback sets (three closures; a closure, a callback type and a continuous callback) | New CodeInstances in the driver and `init`: a new discrete callback 0, two new ones 0, a new continuous one 0, a second callback type 0 (its own `condition` and `affect!` entries 2, the front end's keyword call 1); the first callback type 3 once per key (`init`'s branch for callback-type values). TraitWorld per new closure pair: 6 (`_CallWrap`, `_fptr`); per new callback type 31–35 (its implementation's machinery). Control (PlainODE typed): 9 new driver CodeInstances for one new callback |
| 3 `integ.p` typed | **yes**: `integ.p` on a `Dynamic{IntegratorView{Vector{Float64}, Float64, OscParams}}` infers `OscParams`, `integ.p.k` `Float64`; `RaiseSigma`'s `condition` reads `integ.p.σ` without an assertion and infers `Bool`; the write `integ.p.c = 0.5` reaches the user's `p` and the solve (equal before t = 4, different after) | — |
| 4 a callback type without `affect!` | **refused at `@implement`**: `ImplementError` ("has methods for some operations of Callback but not for affect!"), raised at the macro's expansion; a condition returning `Int` also refused (`returns Int64, declared Bool`). **A callback type at other parameters than the problem's is accepted at `init` and refused only at its first call** (`TraitArgumentError`): finding 4 | — |
| 5 a step with two callbacks | **The design's form (families):** two callbacks add 1,353 / 1,359 ns and **1,024 bytes per step**, against 6.5 / 2.4 ns and 0 bytes for the typed control and 94 / 100 ns, 32 bytes for PlainODE's `Vector{Any}`. **With the hot members declared on their own (L-37's workaround):** 32 / 41 ns and **32 bytes per step** (16 per callback call), against 4.6 / 0.8 ns, 0 bytes typed and 93 / 89 ns, 32 bytes `Vector{Any}` | Per step without callbacks: TDE 177 / 185 ns, the control 164 / 168 ns (both 122 B, saving every step). One call, families: `condition` on the kept `FunctionCallback` 1,779 ns, 848 B; `integ.p[1]` on the view 667 ns, 384 B. Hot: 42–43 ns, 48 B and 0.9 ns, 0 B; the kept `Callable` alone 12.7 ns, 16 B. `compiled_for` closures: 1,918 / 1,978 ns (families), 547 / 566 ns and 128 B (hot) per step for two |

### Findings

1. **L-37 dominates the callbacks' cost** (check 5). Both families of move 2 are on the hot path: every operation on a kept `FunctionCallback{U, T, P}` and every field read on the `Dynamic{IntegratorView{U, T, P}}` of a `Tsit5Integrator{T, P}` opens the family through its registry (`_conf_family`): 1.8 µs and 848 B per `condition`, 0.67 µs and 384 B per `integ.p`, so two callbacks add 1.35 µs and 1 KB to a 0.18 µs step. Declaring the two members on their own removes it (32–41 ns per step). The library cannot declare the members for its users' parameter types (`OscParams`, `LorenzParams`): that is the owner of `P` (planned, T-28) or W-40.
2. **The view is boxed at every callback call** (check 5, hot): a `Dynamic{IntegratorView{…}}` is an immutable non-bits value, so each `Dynamic{Callable}` call that takes it boxes it (16 B; open issues §4 item 35; E-157 finding 1). Two callbacks: 32 B per step, as PlainODE's `Vector{Any}`. It is the callbacks' signature itself, so every callback call of move 2 allocates unless the box goes.
3. **`X{P}[]` in a trait module's function body is not taken as `Kept{X{P}}`** (found building `enter_callbacks`): traits §7.2 says a trait's name as a container's element type means `Kept{X}` (`Column[]`). A bare name works (`Plain[]`), and so does a struct field `Vector{Shape{P}}`; `Shape{Float64}[]`, `Shape{P}[]` and `Vector{Shape{Float64}}()` give a vector of the trait type itself, and `push!` of a conforming value fails at `convert`. `TraitWorld/src/trait_module.jl:361` (`_dyn_body` rewrites only when `_istraitname`, `:306`, which takes a symbol or a dotted name, not a `curly`). Reproducer: `m2/repro_typed_array.jl`. TDE writes `Kept{Callback{U, T, P}}[]`.
4. **A value is kept at parameters its type does not implement** (check 4): `Kept{Shape{Int}}(Sq())`, `Dynamic{…}` and `Compiled{…}` alike, with `Sq` implementing only `Shape{Vector{Float64}}`, are accepted (`conforms(Sq, Shape{Int})` is `false`); the first operation raises `TraitArgumentError`. `Dynamic{X}(x)` checks the family, `_family_list(X)`, not `X`'s parameters (`TraitWorld/src/core.jl:435`–`440`). In TDE a callback type at another `P` passes `init` and fails at its first `condition`. Reproducer: `m2/repro_kept_params.jl`.
5. **`compiled_for` closures cost more than `Dynamic` ones** (check 5): kept in a `Kept{Callable}` field, a `Compiled` function is called by run-time dispatch on its type (traits §7.5, "a call selects its code by its type"), 270–280 ns per call with hot members. The design's `compiled_for` buys speed where code is compiled for the value; the integrator's vector is not.
6. **A note on compile counts** (check 2; not a TraitWorld matter): a constructor with `@nospecialize` arguments still gets one CodeInstance per closure type when a caller that knows the types is inferred, in a trait module and a plain module alike (`m2/repro_nospecialize.jl`); `@nospecializeinfer` gives one. TDE's `DiscreteCallback` and `ContinuousCallback` use it. The front end's keyword call (`Core.kwcall` of `solve`) is compiled per callback container type (a callback type, a tuple of them), Julia's keyword machinery: one small CodeInstance in the ordinary module per new callback type.

### Deviations met

- **L-37** (finding 1): on the main path of move 2, twice per callback call.
- **Open issues §4 item 35** (finding 2): the view boxed per `Dynamic{Callable}` call.
- Not on this build's path: T-57 (the families have no block), T-62 (every family by its owner), T-68 (no mapped fields), L-3 (users' callback types add plain methods for their own types; every bounded method is in its function's owner), L-31 (the view is made explicitly, `Dynamic{IntegratorView{…}}(i)`).

### Pushback (idiomatic code against the design)

- **A callback type for every `P` is not offered** (traits §3.4, §4.7: a type conforming at every parameter value). A callback type states its problem's types (`@implement Callback{Vector{Float64}, Float64, LorenzParams{Float64}} Bounce`), so `Bounce` serves Lorenz problems only; SciML's callback types serve any problem. The ways round: the plain record entered at `init` (what `DiscreteCallback` does), or a family over a parameter of the callback's own, which the user then writes (`Bounce{P}`).
- **The view's type in every callback signature** is long (`Dynamic{IntegratorView{Vector{Float64}, Float64, LorenzParams{Float64}}}`); `LorenzModels` names it once (`const LorenzView = …`).
- **Move 2 puts two families on every callback call:** the callback records (`FunctionCallback{U, T, P}`, parametric because their `Callable`s name `U, T, P`) and the integrators. Through L-37 each call and each field read takes the per-member path (`main`'s cost for its unparametrized `Dynamic{IntegratorView}` was not measured here). Before W-40, the speed needs per-member declarations that only `P`'s owner could write.
- **Every callback call allocates** while the view is a non-bits immutable passed to a `Dynamic` function (item 35).
- **`compiled_for` on a callback** does not compile the driver for it (by design: the integrator's type stays free of callback types); it only changes the call to a run-time dispatch. SciML's fully specialized callbacks have no counterpart short of a callback type in the integrator's type.

### Choices made (mine)

- `IntegratorView{U, T, P}`'s fields as above; `terminated` stays writable beside `terminate!` (the existing API); `dt` is the last accepted step's size.
- Two traits, `Callback` and `EventCallback`, with distinct operation names (`event_condition`, `event_affect!`), not one trait with a kind.
- The user's records are plain structs in ODECore with `Any` fields, entered at `init`; the front end passes the callbacks as a `Vector{Any}` (`solve_ode`'s signature changed, internal). A continuous callback type is recognized by `conforms`.
- `interp!` interpolates the last accepted step (after acceptance; the integrator keeps `uprev`, `kprev`, `tprev`); Rodas5's from `uprev` and `u`.
- Continuous events: after the step is accepted, before saving; the earliest callback's event wins; the integrator moves to the last time before the crossing; the state is saved there once (not the post-affect state, as for discrete callbacks); SciML's repeat nudge (a hundredth of the step) for the fired callback's next check. Continuous before discrete. Rodas5 refuses continuous callbacks.
- tstops: `add_tstop!` ignores a time not ahead; a tstop behind a continuous event stays.
- TDE declares no hot members (the design's form is what is measured; the workaround is measured from the script).
- The control's typed callbacks are tuples with the discrete ones unrolled by recursion; PlainODE's `Vector{Any}` path is shown beside it.

---

# E-229: move 5, the solution as a trajectory (TDE, W-34)

The question (registry E-229; [the plan](../../writeup/plans/2026-10-29-sciml-finish.md) §2, §4): can the solution keep its problem as a kept value, with no axis for its function or type? Is a helper over trajectories compiled once per solution type, not per model? Does `DiffEqArray` conform?

What it measures: idiomatic trait code (library helpers written against a trait) and the solution's type. No timings.

## What was built (TDE branch `w34`, bc68501, from 44b4d14)

- **`lib/TraitArrayTools`,** RecursiveArrayTools' stand-in, a package of its own below the core: `Trajectory{U, T}` (`times`, `state`, `at`), `DiffEqArray{E}` (states at times, linear between them; `A(τ)`), `plotpoints(s::Trajectory{U, Float64}, i)::Matrix{Float64}`, `linear_at`.
- **`CoreSolution{T}`,** what a solver returns (ODECore; Tsit5, TraitRodas and TraitImplicit return it). **`ODESolution{T, P}`,** made by the outer layer (`with_problem`, a bounded function on the problem): the same data, `prob::Kept{ODEProblemTrait{T, P}}` and the names. `sol(τ)` is `at(sol, τ)`.
- `_ad_jacobian!` declares its result `::Nothing` (finding 1).
- TDE's suite: 116 checks pass, none broken (`test/w34.jl` adds 11).

## How to run

    move5/run.sh <run>       # checks 1–6, each in a fresh process, through the shared lock, niced

- Check 1 runs TDE's `scripts/session.jl trait` (`JULIA_LOAD_PATH="scripts/env:@stdlib"`) and compares its `RESULT` lines with `../w81/x1/session-x1-one-function.log`; check 2 is TDE's `Pkg.test()`; checks 3–6 are `move5/move5.jl` in `move5/` (its environment: TDE, TraitArrayTools, LorenzModels, ChainModels from the checkouts).
- CodeInstances are counted as in E-157 (every method of TraitArrayTools from the global method table, the CodeInstances of each specialization by owner), before and after each step. Check 6 runs before check 5, which calls `plotpoints` too.
- Logs: `move5/logs/{session,tests,move5}-run1.log`.

## Results (2026-10-29)

julia-1.13 bfca89decc, TraitWorld c39fedc, TDE bc68501, product setting, strict mode off, one run, load 0.8–1.2.

| Check | Outcome |
|---|---|
| 1 `RESULT` lines | **unchanged:** the 9 lines identical; the session passes |
| 2 TDE's suite | **passes** (116) |
| 3 one solution type | **`ODESolution{Float64, Vector{Float64}}`** for a function, the same `compiled_for`, `ChainModel{PathGraph}` (Tsit5), `ChainModel{RingGraph}` (Rodas5), Rodas5 with the chunk at init; `sol.prob` is `Kept{ODEProblemTrait{Float64, Vector{Float64}}}` for each. A problem type (`LorenzProblem`), `Tuple` parameters and a `Float32` state give their own `P` or `T` |
| 4 `sol.prob` | its `u0`, `tspan`, `p` read back; `rhs!(sol.prob, …)` is the problem's derivative, for `ODEProblem` and for `LorenzProblem` (its `p` a `LorenzParams`) |
| 5 `DiffEqArray` | conforms; `plotpoints` equals the solution's for each component; `A(τ) == sol(τ)` on 21 times |
| 6 `plotpoints` compiled | typed callers, new CodeInstances in TraitArrayTools: the first solution type 12; four more models and solvers of that type 0; `LorenzProblem` 10, `Tuple` parameters 10, `Float32` 11 (each a new solution type); a `DiffEqArray{Float64}` 17. As `Dynamic{Trajectory{Vector{Float64}, Float64}}`: 12 for the first, 0 for four more (two other solution types and a `DiffEqArray`) |

### Findings

1. **The kept problem is checked as a family member; under facts, `jacobian!` inferred `Any` there.** Storing an `ODEProblem` whose function is `Dynamic` in `Kept{ODEProblemTrait{T, P}}` checks it as a member of the problem family (before move 5, `core_problem` checked only compiled ones). The check refused it: `jacobian!` returns `Any`, declared `Nothing`. Plain inference of the same body gives `Nothing`. Under facts the generated entry of the bounded `_ad_jacobian!(fd::Callable{CoreDualSig{N}, Nothing}, …)`, called with the problem's function kept at another signature, is inferred with `fd::Any` (`enter_callable(…, ::Any, ::Any, …)`, then `checked_call(::typeof(_ad_jacobian!), ::Any, …)` by dynamic dispatch), so its result is lost (`TraitWorld.factscode`). TDE declares `_ad_jacobian!`'s result, which the entry passes to its callers. A candidate open issue for the main session: the facts entry of a bounded function loses its inferred result when a kept function enters at another signature.
2. **One solution type per state and parameter type.** The function, the callable model's type, the problem's type and the solver are no part of it.
3. **The helper is compiled per solution type, not per model,** and once for every trajectory kept `Dynamic`.
4. **Move 5 costs the load about 0.14 s** (E-230): the three `ODEProblem` members the solutions keep are fixed in TDE's image and checked again at every load (W-84).

### Choices made (mine)

- `Trajectory`'s owner is a package of its own below the core (RecursiveArrayTools' place in SciML), so a plotting package needs no solver.
- Two types: the solver's `CoreSolution{T}` and the user's `ODESolution{T, P}`, rather than one type with a `Union{Nothing, …}` problem field. The core never sees the problem (W-63); the split states it.
- `plotpoints` returns a copy (an n × 2 matrix), not a view conforming to TraitMakie's `Positions`; that view would need a package extension.
- `at` stays linear between the saved states; the solvers' interpolants are not kept.

# E-239: W-32 R2, the TDE side (2026-10-29)

The question (registry E-239; [the R1 census](../../writeup/plans/2026-10-29-ndport-r1-census.md) §3, items 1, 2, 12–17; open issue 119): can TDE take what NetworkDynamics needs from SciML, each item in the trait form, with results unchanged? Not a measurement, except E-168's session once (`../ttfx/`, section E-239).

## What was built (TDE branch `w34`, ede32e3 and f0a79ae, from 3a51d95)

- **Optional properties of a problem's function** (open issue 119): the traits `HasMassMatrix`, `HasJacobianPrototype`, `HasSystem` on the function's type (and `HasCallbacks` on a problem's). `ODEFunction`'s defaults read them, `ODEProblem` keeps them; `solve` and `init` refuse a mass matrix other than the identity for an algorithm that takes none (`takes_mass_matrix`, an `ODEAlgorithm` operation, default `false`). A callable object with an undeclared `mass_matrix` property is refused.
- **The system object back** (item 12): `getsystem` on a problem, a solution, the integrator, a callback's view of it.
- **Rodas5 with continuous callbacks** (item 1): the events located as Tsit5's (`locate_events!`, shared).
- **`init`, `step!`, `step!(integ, dt, stop_at_tdt)`, `solve!`** (item 2): the drivers are their integrators' `advance!` (one accepted step); `ODEStepper <: ODEAlgorithm` (`init_core`); `CoreIntegrator{U, T}`. `init` returns the integrator callbacks see (`ParamIntegrator`). The integrators keep their core problem (`Tsit5Integrator{T, M}`, `Rodas5Integrator{JC, M}`).
- **Items 13–16:** `save_discretes!` and `parameters_at(sol, t)`; `ODEProblem(…; callback)`; `tstops` and the callbacks' `initialize`; `auto_dt_reset!`; `ContinuousCallback(condition, affect!, affect_neg!)`.
- **Item 17, part:** `ODEFunction` callable. Not done: `Rodas4`, `copy` of absent parameters.
- TDE's suite: 161 checks (116 before; `test/r2.jl` and changed expectations in `w34.jl`, `w34_move2.jl`, `routea.jl`).

## How to run

    r2/run.sh <run>                     # check 1: the session's RESULT lines; check 2: Pkg.test() (stock image)
    W=<scratch> r2/control_before.sh    # E-168's session on TDE 3a51d95, the same day (needs a worktree, see its header)
    julia --project=../ttfx/env_d r2/probe_steps.jl   # the first problem and solves, wall and compile time

## Results (2026-10-29)

julia-1.13 bfca89decc, TraitWorld ca92f22, product setting, strict mode off.

| Check | ede32e3 | f0a79ae |
|---|---|---|
| 1 `RESULT` lines (`logs/session-run1`, `-run2`) | **identical** (9) | **identical** (9) |
| 2 TDE's suite | passes (161) | passes (161) |
| `ODEProblem` of a new function (`probe_steps.jl`, the env of setting D) | 43 ms (3a51d95: 5 ms) | 5 ms |
| the first Tsit5 solve | 58 ms (3a51d95: 22 ms) | 22 ms |

### Findings

1. **A bound's entry is compiled per argument type.** The front end first read a plain function's optional properties through three bounded functions: about 38 ms of compilation per new function, and E-168's session 0.25 s slower. f0a79ae reads them without entering a bound where the answer is known without one (a function that declares none of the traits; TDE's own records, by their fields).
2. **A kept value meets a bound of another trait:** its held object must conform (`TraitBoundError`), where a plain value that conforms to none of the bounds reaches the ordinary fallback (traits §5.5 and §6.5 read together suggest the fallback). The front end reads a kept value's properties through its kept trait only, so a model kept as `Dynamic{Callable{…}}` shows no mass matrix. A candidate open issue.
3. **NetworkDynamics' `NWState(int::(IntegratorView, HasSystem))`** is refused by TraitWorld's encoding: the untyped one-argument constructor, lowered below the bound (lowering L-3), is reported ambiguous with `NWState(thing, uflat::AbstractVector)`, which no call can reach. NetworkDynamics takes TDE's concrete integrator by type and refuses a callback's view with a message. A case for the main session.
4. **A type's own `getproperty` and declared fields:** `integ.ps` sugar on `ParamIntegrator` made TraitWorld require explicit field mappings for `IntegratorView`; the sugar was dropped (`getparam(integ, :ρ)`).

### Choices made (mine)

- A mass matrix is kept by the problem and refused by the algorithm (`takes_mass_matrix`), not refused at the problem: the solvers are an open set, and one that takes mass matrices needs no change to the front end.
- A Jacobian prototype is a hint: kept, never refused (a solver that does not use it computes the same Jacobian dense).
- A callable object with a `mass_matrix` property it does not declare is refused (SciML reads the property; a silent ODE would be wrong). Functions are exempt: a closure's captured variables are its fields.
- `init` takes only `ODEStepper`s (a subtrait): a solver that cannot be stepped is refused at the bound (`TraitBoundError` naming `ODEStepper`).
- A callback's `initialize(u, t, integ)` without SciML's callback argument; an affect of `nothing` is refused (every crossing is an event, as NetworkDynamics' vector callbacks have it).
- The parameters are saved at the start of every solve with callbacks (`deepcopy` unless an array), and at each `save_discretes!`; `parameters_at` takes the last saved at or before `t`.
- The integrators keep their core problem's type (`M`): it names no parameters type, and the drivers were compiled per core problem already.

# E-242: W-32 R3, the TDE items left for NetworkDynamics (2026-10-29)

The question (registry E-242; [the R1 census](../../writeup/plans/2026-10-29-ndport-r1-census.md) §3, item 11, S7, item 17's rest; open issues 117 and 118): can TDE take NetworkDynamics' fixed point, `remake`, dense output and the solution's `idxs` forms, each in the trait form, with results unchanged; and how far does NetworkDynamics then run? Not a measurement, except E-168's session once (`../ttfx/`, section E-242).

## What was built (TDE branch `w34`, e4eeed9 and 388cb33, from f0a79ae)

- **Nonlinear problems with an open set of solvers** (item 11), a new package `lib/TraitNonlinearSolve` as [the note](../../writeup/plans/2026-10-29-tde-nonlinear-problems.md) designs it (its §7 lists the amendments): `NonlinearProblemTrait{T, P}`; TDE's `NonlinearProblem` and `NonlinearFunction`; `SteadyStateProblem` from a right-hand side at a time or from any `ODEProblemTrait`; `NonlinearAlgorithm` with `NewtonRaphson`, `TrustRegion` and `NonlinearPolyalg`, each over any `LinearSolver`; the solution with its problem kept; a precompile workload. The umbrella re-exports it and forwards a nonlinear algorithm from its `solve`, chosen by trait dispatch (`is_nonlinear_algorithm`, `is_nonlinear_problem`: bounded methods with an untyped fallback, 388cb33).
- **`remake(prob; u0, tspan, p, callback)`** (S7) in ODECore: the user's functions back from the problem with their attributes, entered again.
- **Dense output** (open issue 117, my choice): `Interpolant{U, T}` (`interpolate`) in ODECore; `HermiteSteps{T}` (Tsit5) and TraitRodas' `Rodas5Steps`; `CoreSolution` and `ODESolution` keep `Kept{Interpolant{Vector{T}, Float64}}` or `nothing`; `dense` defaults to an empty `saveat`. A step cut by an event keeps its full step's data and ends at the event's time, so `sol(te)` is the state saved there.
- **The solution's `idxs` forms:** `sol(τ; idxs)` is `sol(τ, idxs)`, by dispatch on the index's type (`Int`, `Symbol`, vectors; a library's own type by its own method); at a vector of times, a vector of values. Open issue 118 is not built.
- Not built: `Rodas4` (a second tableau and interpolant) and `copy` of absent parameters (a `NullParameters` default would change every parameterless problem's type).
- TDE's suite: 222 checks (161 before; `test/nonlinear.jl`, `test/r3.jl`).

## How to run

    r3/run.sh <run>                     # check 1: the session's RESULT lines; check 2: Pkg.test() (stock image)
    W=<scratch> r3/control_before.sh    # E-168's session on TDE f0a79ae, the same day (needs a worktree, see its header)
    julia --project=<TDE> r3/quick_nl.jl nonlinear.jl r3.jl     # the new test files alone
    (ndport) scripts/r3_pc.sh <name>; scripts/r3_run.sh <name> scripts/r3_workload.jl; R1_JFLAGS="-t 2" scripts/r3_run.sh <name> scripts/r3_nd_tests.jl

## Results (2026-10-29)

julia-1.13 bfca89decc, TraitWorld d22ec7b (main, as found), product setting, strict mode off.

| Check | e4eeed9 / 388cb33 |
|---|---|
| 1 `RESULT` lines (`r3/logs/session-1.log`, `session-4.log`) | **identical** (9) |
| 2 TDE's suite (`r3/logs/tests-1.log`, `tests-4.log`; `tests-2`, `-3`: the intermediate form, finding 6) | passes (222) |
| NetworkDynamics' workload (`ndport/logs/r3-tde/run-3.log`, `run-4.log`) | 4 failures (E-239: 24): `SII.getu(sol, …)` in each pass (open issue 118) |
| `find_fixpoint` against the relaxation (flows and frequencies) | 8.4e-10–9.6e-10 in every pass |
| the cascade (Tsit5 and Rodas5) | E-239's trips, the same lines and times |
| dense output against `saveat` (Tsit5, the network with its callbacks) | 0.0 |
| NetworkDynamics' test subset (`ndport/logs/r3-tde/ndtest-1.log`, `ndtest-2.log`) | as E-239: massmatrix 6, doctor 26, diffusion 108/1/1/24, inhomogeneous 39/0/1/12 |
| E-168's session, setting D (`../ttfx/logs/e242/`) | e4eeed9 1.74–1.77 s (`a-D-*`); 388cb33 **1.34–1.35 s**; the control on f0a79ae 1.27–1.32 s (four sessions, two before and two after) |
| inferring `solve(::Any, ::Tsit5)` at the session's keywords (`r3/probe_inference3.jl`) | e4eeed9 447 ms; 388cb33 14 ms; f0a79ae 12 ms |

### Findings

1. **A field kept at a bounded parameter is read through the bound.** In a trait module, `prob.f` on TDE's `ODEProblem` gives the trait object (`Callable{…} at PartialFn{…}`), not the stored record, so `rewrap` saw no cast. `remake` reads the fields as stored (`getfield`).
2. **A trait object reaches untyped code only where its trait is expected** (rule 2): `SteadyStateProblem(prob::ODEProblemTrait)` read the problem's optional properties inside the bound and was refused (`TraitBoundError` at `getsystem`). The front end reads them before the problem enters the bound.
3. **A library's own index type on TDE's solution:** NetworkDynamics' methods `(sol::ODESolution)(t::Real, idx::SymbolicIndex)` load and run, strict mode off; the ports' ownership rules raise nothing for a method that names the library's own type.
4. **One `solve` across packages:** TraitNonlinearSolve's `solve` is its own function; the umbrella forwards to it. A shared `solve` (CommonSolve's role) meets lowering L-3 (W-36). A case for the main session.
5. **`conforms` in a front end is inferred by the callers.** At e4eeed9 the umbrella's `solve` asked `conforms(typeof(alg), NonlinearAlgorithm)`. A caller that infers `solve` at its keywords' types (E-168's `solve_two`) inferred TraitWorld's membership lookup with the trait as a constant: 0.43 s in the session's first solve, not visible in `--trace-compile` beyond the caller's own line (`Main.solve_two` 519 ms). An inference barrier removed it (13.7 ms); trait dispatch removes it without an annotation (388cb33). A note for the main session: `conforms` is a run-time question, and a library that asks it in a front end pays for it in its callers' inference.
6. **A `@trait_module` block in the umbrella** (an intermediate form of the fix, bounded predicates in the umbrella itself) made the suite's nested-gradient test fail deterministically ("cannot determine ordering of Dual tags", `r3/logs/tests-2.log`, `-3`): ForwardDiff orders tags by the order of their first compilation, and the block changed it. The predicates moved to TraitNonlinearSolve, and the test passes. Not attributed further; the test depends on compilation order.
7. **The in-place function that returns its array** (open issue 120, decided): one in NetworkDynamics' test subset (`diffusion_test.jl:33`), adapted at the source; none in NetworkDynamics' own code.

### Choices made (mine)

- Open issue 117 as its proposal (the user's rule "more expressive is principled"); `dense` on without `saveat`, as SciML's default; Tsit5's interpolant is the cubic Hermite its `saveat` and events use.
- `sol(ts; idxs)` returns a plain vector of the values, not a `DiffEqArray` (TraitArrayTools' `DiffEqArray` holds vector states; SciML's holds any). Upstream's `sol(ts; idxs).u` does not run.
- The `idxs` forms by dispatch on the index's type, so NetworkDynamics' own indexing serves its indices without a protocol (open issue 118's alternative C7, in the solution's call syntax).
- `remake` gives a plain function back plain and a cast one under its cast; it keeps the callbacks unless given.
- The note's amendments (§7): the trait's default Jacobian by finite differences; `SteadyStateProblem` a constructor; the line search a flag; the default polyalgorithm.
