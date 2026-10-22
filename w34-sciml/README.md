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
