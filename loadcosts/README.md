# loadcosts: where first calls lose time to unrelated package loads (E-141, E-142)

Two measured slowdowns of the round of 2026-10-20, taken apart into compilation events.
Build: julia-1.13 3b8085c222, TraitWorld bed3782, TraitDifferentialEquations 248f6a2; CSV 1.1.0.
Run 2026-10-20, one job at a time, `nice -n 19`, load average 0.9–2.5 (other jobs on the machine).
Not edited: Julia, TraitWorld, the demonstrators. Registry rows: [E-141, E-142](../../writeup/record/experiments.md).

## How to run

| Script | What | Setting |
|---|---|---|
| `run_rows_traced.sh <none\|before\|after> <run>` | `TraitDifferentialEquations/scripts/rows.jl` **unchanged**, with `--trace-compile=stderr --trace-compile-timing`, stdout and stderr through one pipe | product setting, default depot, the round's load path |
| `rowsdiff.py <ref.log> <run.log>` | per row: the trace entries the run has and the reference has not, their sum, the rest of the difference | — |
| `run_tde.sh <mode> <tag> [Pkg…]` → `tde_diag.jl` | rows 1–4 instrumented: two windows per row (below), compile and recompile time, GC, new CodeInstances by owner and module ("again" = replaces an invalidated one), the loads' invalidation logs with root causes (`.inv`), compile trace (`.trace`); `PROFROW=k` profiles row k | product setting |
| `tracediff.py <ref.trace> <run.trace> [row…]` | as `rowsdiff.py`, for `tde_diag.jl`'s traces | — |
| `run_ctl.sh <tag> [Pkg…]` → `ctl_diag.jl` | the control's upstream work (`factscompiler/control/lost.jl`), then the nine loads with the invalidation log, then the work again; `STEPS=1` times its four steps, `TRACE=1` the compile trace, `PROF=1` a profile (flat and tree) | `MODE=all` (default): facts system image, depot `/tmp/claude-1000/depot-facts`; `MODE=plain` |

`tde_diag.jl`'s two windows: **inner** is rows.jl's number. **outer** also counts the compilation of the measured statement itself (see finding 0).

## Finding 0: rows.jl's numbers leave out part of each first call

`@elapsed` forces its top-level statement to be compiled (`Experimental.@force_compile`, `julia-1.13/base/timing.jl:461`). The statement is compiled, and with it the inference of the call at its concrete types and of all it reaches statically, before `@elapsed` reads the clock. rows.jl's numbers therefore count only what is compiled at run time (dynamic dispatch, `cfunction` thunks, generators). The whole first call (`tde_diag.jl`, outer window, no loads, 3 runs): first solve 40–44 ms (rows.jl 11–13), second model function 32–34 (11–13), new model type's first solve **327–335 ms** (rows.jl 47–54), new callback 23–25 (13–15).

## E-141: TraitDifferentialEquations under CSV, DataFrames, CairoMakie (product setting)

No CodeInstance of the facts owner `:facts` was lost in any run (`tde-*.log`, "lost … by owner": only `nothing`). Every component below is **plain code** (owner `nothing`) that trait code's first calls run: TraitWorld's unmarked helpers and generators, and TDE's ordinary front end.

**Rows.jl unchanged, with the compile trace** (`logs/rows-*.log`, `rowsdiff.py` against `rows-none-1.log`; the trace adds about 15% to every row):

| Row (round: loaded against none) | Here: loaded against none, ms | The trace entries only in the loaded run | Rest |
|---|---|---|---|
| first solve, loads before (29 against 10.6) | 35.6 / 37.3 against 14.3 (+21.3 / +23.0) | recompile `TraitWorld._tw_type(::Any, ::IdSet{Any})` 21.4 / 23.0 | −0.1 / 0.0 |
| second model function, loads after (31 against 10.4) | 41.8 / 37.2 against 14.0 (+27.8 / +23.2) | recompile `_tw_type` 26.6 / 23.9 | +1.2 / −0.7 |
| new model type's first solve, loads before (95–97 against 44–46) | 116.5 / 120.0 against 56.9 (+59.6 / +63.1) | `TraitWorld.var"##15#16"`, the generator of `_carries_static`, compiled anew: 58.7 / 62.9 | +0.9 / +0.2 |
| new callback closure, before (24 against 12.7) | 31.4 / 32.7 against 18.9 (+12.5 / +13.8) | recompile `Core.kwcall(…, solve, ::ODEProblem, ::Tsit5)` (callback) 15.9 / 14.3 | −3.4 / −0.5 |
| new callback closure, after | 34.5 / 33.2 against 18.9 (+15.6 / +14.3) | the same, 15.6 / 17.4 | 0.0 / −3.1 |
| (not one of the four) `@implement`, loads before (81–83 against 60–62) | 109.8 / 104.1 against 78.8 | recompile the generators of `_parts` (`##106#107`) 9.9 / 8.8 and `_traitset` (`##12#13`) 8.7 / 7.9 | +12 / +9 (the row's own noise: 79 against 90 between two runs without loads) |

**Bisection over single loads** (`logs/tde-bis-{before,after}-<Pkg>.*`, `tracediff.py`):

| Component | Caused by (each alone) | Order |
|---|---|---|
| `_tw_type` recompile, 21–28 ms | CSV, DataFrames, StaticArrays, Unitful (not IntervalArithmetic) | both |
| generator of `_carries_static`, 59 ms | Unitful | before only |
| generators of `_parts`, `_traitset`, 8–12 ms each | Unitful, IntervalArithmetic (`_parts`); DataFrames (`_traitset`) | before only |
| `solve` front end recompile, 13–24 ms | IntervalArithmetic | both |

**The causes**, from the invalidation and image-validation logs (`logs/tde-before2.inv.gz`, `tde-after2.inv.gz`, section "root causes"):
- **`_tw_type`** (`TraitWorld/src/entry.jl:546`), called through `inferencebarrier` from `_from_trait_world` (`entry.jl:531`) once per new function type that crosses into a `Callable`. It is compiled plainly at `(::Any, ::IdSet{Any})` and reaches `is_trait_world` (`trait_module.jl:38`) and `owner`/`_owner` (`ownership.jl:108`), type-unstable string and array code. Its edges at abstract signatures get new matches: `Int64(::Integer)` (SentinelArrays' `(::Type{T})(::ChainedVectorIndex)`), `convert(::Type{Vector{String}}, ::Any)` (DataStrings, PooledArrays, StaticArrays), string `replace` at `Any` (Unitful).
- **The generators** (`##15#16` = `_carries_static`, `core.jl:328`; `##106#107` = `_parts`, `entry.jl:67`; `##12#13` = `_traitset`, `core.jl:292`; `##30#31` = `Erased`, `core.jl:743`) are plain closures. `_carries_static` calls `_carries` → `_decode_traits` (`core.jl:256`), where `np = length(u.parameters)` is `Any`, so `for i in 1:np` holds the edge `Colon(::Int64, ::Any)`; Unitful's `(:)(::Any, ::Quantity)` matches it. When TraitWorld loads after Unitful, image validation rejects the generator's code (`verify_methods`, `insert_backedges_callee`). When Unitful loads after TraitWorld, the code is invalidated but never needed again: a generator runs in the world of its method's definition (`julia-1.13/src/method.c:796`), where its old code is still valid. Hence "before only".
- **The front end**: `solve(@nospecialize(prob::ODEProblem), alg::Tsit5; callback, kw...)` (`TraitDifferentialEquations/src/TraitDifferentialEquations.jl:58`) is plain code of the ordinary module, inferred at the abstract `ODEProblem`. `_promote_state(prob.u0, prob.p)` (`:69`) is inferred at abstract `p`, so the dual branch `Vector{D}(u0)` is compiled at abstract `D <: Dual`, down to `Dual{T,V,N}(::V, ::Partials)` → `can_dual(V)`. IntervalArithmetic's package extension for ForwardDiff defines `ForwardDiff.can_dual(::Type{ExactReal}) = true` (`IntervalArithmeticForwardDiffExt.jl:7`); its insertion invalidates the chain up to `solve(::ODEProblem, ::Tsit5)` and both `##solve#2` bodies (`jl_method_table_insert` log). With loads before, the extension loads during `using TraitDifferentialEquations` (TDE brings ForwardDiff), so both orders pay.
- **Hidden by finding 0:** the same invalidation costs about 40 ms more in the outer window of the first solve after the loads (recompile 62–64 ms against the inner 24; IntervalArithmetic alone: 37–40 ms), for `solve(::ODEProblem, ::Tsit5)` itself, which the statement's compilation recompiles before the clock starts.

**Unexplained:** for the four rows, ±3 ms (the trace's noise). `@implement` with loads after varies by 3–22 ms without any extra trace entry or recompilation, within the row's own run-to-run spread; not attributed. The outer window of the new model type's first solve with loads before is 45–150 ms above "none" in 3 runs, of which the inner generator accounts for 45–80; one run's rest was GC (31 ms); the rest of the other two is not attributed (no recompilation, the same 127–130 new CodeInstances).

## E-142: upstream CSV + DataFrames after nine loads under `all`

**The work after the loads: 369–386 ms in 5 runs** (round: 435 ms; plain mode here 3.8 s). Compile time 366–384 ms of it (`logs/ctl-all-{1..5}.log`, `ctl-all-steps-{1..3}.log`):

| Component | Time | Share | Evidence |
|---|---|---|---|
| **`CSV._parse` recompiled by facts** | 320–334 ms | 86–89% | trace: one entry, `precompile(CSV._parse, …) # recompile` 321–333 ms (`ctl-all-2.trace`, `ctl-all-steps-1.trace`); step `CSV.read` 322–335 ms, all of it recompile |
| — of it, LLVM (codegen and optimization) | ~81% | | profile tree: 482 of 593 samples under `_parseprepared` in `jl_compile_codeinst_now` (`ctl-all-prof-2.tree`) |
| — of it, facts inference | ~19% | | 110 of 593 samples in `typeinf_ext_toplevel` |
| **Plain inference behind run-time `return_type`** in `describe` | 45–63 ms (up to 17 of it GC) | 12–16% | step `describe`; profile: 116 samples, all under `return_type` → `typeinf_ext(::PlainRTInterp, …)`; 61 answers of owner `:facts_plain_return_type` computed again (lost to the loads: 507), 39 new ones |
| `sort`, `combine` | 0.6 ms | — | as repeated work (0.8–1.0 ms) |

**The causes:**
- `CSV._parse` (CSV 1.1.0, `src/core.jl:3711`) writes `[0; v]` (`:3809`, `:3873`): `vcat(::Int64, ::Vector{Int64})`, a fact signature. SparseArrays' `vcat(::Union{Number, AbstractVecOrMat{<:Number}}, ::Vararg{…})` (`SparseArrays/src/sparsevector.jl:1275`) wins there. The log shows the insertion invalidating `vcat(::Int64, ::Vector{Int64})` and both `_parse` specializations at depth 1 (`ctl-all-3.inv.gz`). Bisection (`ctl-all-bis-*.log`): StatsBase, Distributions, Interpolations, CairoMakie each alone cost 325–336 ms in `CSV.read`: each loads SparseArrays. OffsetArrays, Unitful, IntervalArithmetic, StaticArrays, REPL cost nothing there.
- The `return_type` answers rest on plain edges at abstract signatures: `quantile!(::AbstractVector, ::Float64)`, `get_stats(::AbstractVector, ::Vector{Symbol})`, `sum`/`extrema`/`mean` of `SkipMissing{<:AbstractVector}`, sort internals at `AbstractVector` and `Integer`, `Colon(::Int64, ::Integer)` (`ctl-all-3.new`). Each of eight of the nine loads alone costs 16–80 ms in `describe` (REPL 0); the top method is Unitful's `Colon(::Any, ::Quantity)`, 726 entries.
- Against 2026-10-19 (~990 ms, "70% plain inference behind `return_type`"): that part is now 45–63 ms. The vcat recompile, estimated then at ~280 ms, is now the bulk.
- For comparison, plain mode recompiles `CSV._parse` in 675 ms and the whole work in 3.8 s (`ctl-plain-steps-1.*`). The facts mode's recompile of `_parse` is not slower than plain Julia's.

**By design or a bug:**
- The `_parse` recompile is **by design**. A standard library counts as Julia's own code, so SparseArrays' `vcat` for Base's types is a stakeholder's change, followed by rule P (`writeup/reference/facts.md` §2.2, "The standard libraries count as Julia's own code"; open issue §1.19). Plain Julia pays it too.
- The `return_type` part is **by design** too (facts.md §7.1, "An answer computed at run time is computed again when plain Julia's would change"). Its "revalidated after loads" is Planned.
- No bug found in E-142.

**Unexplained:** nothing beyond 1–2 ms (the sum of the steps matches the whole work).

## Proposed fixes and expected gains (not built)

| # | Fix | Where | Expected gain | Kind |
|---|---|---|---|---|
| 1 | Compile TraitWorld's first-call helpers by facts: mark `_tw_type`, `is_trait_world`, `owner`, `_owner` (and `_extension_parent`, `_stdlib_names`) `@machinery`. Code compiled by facts holds facts only, so neither image validation nor invalidation touches it. | TraitWorld `entry.jl`, `trait_module.jl`, `ownership.jl` | 21–28 ms on the first crossing of a plain function after any of CSV/DataFrames/StaticArrays/Unitful: the round's +18 (first solve, before) and +20 ms (second function, after) | a gap: TraitWorld code that trait code runs at every first call is plain, so outside G2 (facts.md §6.1 "neutral") |
| 2 | Generator bodies that do no table reads, as the `_carries_static` docstring intends: move the work into `@machinery` functions (`_carries`, `_decode_traits`, `_encode_traits`, the bodies of `_parts` and `Erased`), so the plain generator holds one edge to a facts CodeInstance; or at least `np = length(u.parameters)::Int` and similar assertions. | TraitWorld `core.jl:256`, `:292`, `:322`, `:328`, `:743`; `entry.jl:67` | ~59 ms (the round's +51, new model type, loads before), 17–19 ms (`@implement`, before), 11.5–12 ms (the `Erased` generator, in row 5's "ForwardDiff's own tag", before) | a **bug** in TraitWorld relative to its own stated intent: the docstring of `_carries_static` says the generator avoids code "whose native code a load may invalidate", but the generator's own native code is rejected when TraitWorld loads after Unitful |
| 3 | TDE's front end: a function barrier at concrete `(U, P)` before `_promote_state` (for example `_solve_tsit5(prob.f, prob.u0, prob.tspan, prob.p, alg, cbs, opts)` specialized on `u0::Vector{U}, p::P`, `f` `@nospecialize`), so no code is compiled at abstract `D <: Dual`. This matches the docstring's "compiled once per parameter type `P`". | `TraitDifferentialEquations/src/TraitDifferentialEquations.jl:58`, `:69` (and the Rodas5 entry `:79`) | 12–17 ms on the new-callback row in both orders (the round's +11.5); ~40 ms more of the first solve after IntervalArithmetic that rows.jl does not see | by design (an ordinary module's plain code, facts.md §2.2 "Scope"); a demonstrator fix |
| 4 | Measure first calls whole: rows.jl's `@elapsed` should not let the statement's compilation run before the clock, e.g. time `Base.invokelatest(() -> …)`, or report `tde_diag.jl`'s outer window. | `TraitDifferentialEquations/scripts/rows.jl` (and any `row(…, @elapsed …)` harness) | correct numbers: the new model type's first solve is ~330 ms, not 45 | measurement |
| 5 | E-142's vcat: decide open issue §1.19. If the standard libraries were owners of their own, SparseArrays' `vcat` for Base's `Number` and `Vector` would be a pirate. Strict mode refuses it at trait code's facts, but not in `CSV._parse` under `all` (F-4). For upstream CSV under `all`, the principled remedies are upstream: SparseArrays' concatenation methods restricted to calls with a sparse argument, or CSV not concatenating at Base's types (`pushfirst!`). Trait code (TraitCSV) has its own facts. | open issue §1.19; upstream SparseArrays | ~325 ms of the 370–390 | by design today |
| 6 | E-142's `return_type`: the Planned revalidation of cached answers after loads (facts.md §7.1): re-check an answer whose edge was hit, instead of inferring again with the optimizer. | Julia `Compiler/src/facts.jl` | at most the 45–63 ms, less the revalidation's own cost | Planned |

## Dated results

| Date | Build | Result |
|---|---|---|
| 2026-10-20 | julia-1.13 3b8085c222, TraitWorld bed3782 | E-141: the four TDE slowdowns are three plain compilations each (the `_tw_type` recompile, the `_carries_static` generator compiled anew, the TDE `solve` front end recompile); with rows.jl unchanged, the trace accounts for each difference to ±3 ms. E-142: 369–386 ms = `CSV._parse` recompiled 320–334 ms (SparseArrays' `vcat`) + plain `return_type` inference 45–63 ms |

## E-146: the fixes, measured (2026-10-20)

The fixes of E-141, built and measured: TraitWorld 226db6a, TraitDifferentialEquations 99393b9, julia-1.13 3b8085c222, product setting, the round's environment.

**The fixes:**
- TraitWorld: `_tw_type` is `@machinery` (compiled by facts). The generators' code is written fully typed: the types they reflect on are asserted (`(P::DataType).parameters`, `::Int`), so the image's generators hold no edge at an abstract signature.
- TraitDifferentialEquations: `solve(::ODEProblem, ::Tsit5)` calls `_solve_tsit5` behind a function barrier, compiled at the concrete state and parameter types.
- `rows.jl` times each first call whole (`@first`), and reports the garbage collector's time per row.

**Two lessons on the way** (`logs/rowswhole-after-fixes-gc.log`, `logs/snoop-*.log`, `logs/rows-none-1-*.log`):
- **The garbage collector.** After the big loads, the first full collection over the larger heap (90–190 ms) falls into whichever row triggers it: the second model function or the first gradient. The tables below subtract it (`rowscompare.py --nogc`).
- **Generator helpers compiled by facts were slower.** The first attempt marked the generators' helpers (`_carries`, `_decode_traits`, `_encode_traits`, the generator bodies) `@machinery`. That removed the invalidation, but the `Float32` row's worker compiled 36 ms slower: the helpers run many times while a large worker is inferred, and under facts each operation on an untyped value is a run-time site. Fully typed plain code removes the invalidation and keeps plain speed: step 1 of the argument (`../../writeup/design.md` §2.1).

**Result** (ms, whole first calls, the garbage collector's time subtracted; two runs per order; `logs/rowswhole-before-fixes-gc.log` at load 1.3 against `logs/rowswhole-after-fixes4-gc.log` at load 1.1):

| Row | Before: none / before / after | After: none / before / after |
|---|---|---|
| first Tsit5 solve | 39–41 / 57–61 / 36–37 | 25–26 / 25–26 / 24–26 |
| a second model function | 30–31 / 29–30 / 56–57 | 19–21 / 19 / 23–25 |
| a new model type: `@implement` | 63–66 / 254–259 / 68–70 | 66 / 69–70 / 70–74 |
| a new model type: first solve | 334–358 / 376–402 / 331–336 | 340–371 / 335–338 / 338–350 |
| first Rodas5 solve | 30 / 32–36 / 28–30 | 27–28 / 30–32 / 29–32 |
| a new callback closure | 21 / 33–38 / 34–37 | 21 / 21–23 / 22–23 |
| first gradient | 82–90 / 103–110 / 108 | 68–70 / 82–89 / 85–88 |
| a second loss closure | 58 / 60–62 / 56 | 45–48 / 44–48 / 41–43 |
| a third loss, another model function | 108 / 109–116 / 113–114 | 89–94 / 97 / 91–92 |
| ForwardDiff's own tag | 707–711 / 730–878 / 706–710 | 671–678 / 696–703 / 686–689 |
| a `Float32` state, first solve | 435 / 427–437 / 430–442 | 439–441 / 446–448 / 449–461 |

- Every row but one is now the same in every load order, within the runs' spread.
- What remains: the first gradient with loads, 82–89 against 68–70 ms (+15 ms); not diagnosed.
- `Float32`'s first solve is 5–20 ms slower than before: the barrier compiles `_solve_tsit5` for each new state type.
- The whole-call numbers are larger than `@elapsed`'s (evidence §3 before 2026-10-20): a new model type's first solve is 335–371 ms whole, against 44–46 ms inside `@elapsed`'s window.

Scripts: `run_rows_whole.sh <tag>`, `rowscompare.py [--nogc] <logs…>`, `snoop_rows.jl` (inference per row with SnoopCompile, from an environment of its own in the scratch directory).
