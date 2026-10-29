# E-259 (U9): the guards of option (e) of open issue 136

The question (registry row E-259; open issue 136 (e); exploration `writeup/explorations/abstract-types-as-traits.md` §11.2 C7, §13.4, §16; the plan §6): under "never fold a negative membership in dispatch", which compiled call sites `f(s::S)` of the ports' workloads would carry a guard? How many sit in loops, how many would widen a result type, and what does one guard cost?

**Would change the proposal:** guards in hot code that a declared result does not cover: option (a) instead of (e).

## The answer

**(e) stands. No guard sits in a loop, none in bounded code, and none widens a result beyond what today's code already infers.**

- Across the five sessions, 7 guard sites in the ports' trait functions (3 distinct sites). Every one is at the boundary: plain code calling trait code.
- They come from two patterns only:
  - a capability predicate written as dispatch: `is_nonlinear_algorithm(alg::NonlinearAlgorithm) = true; is_nonlinear_algorithm(alg) = false`, called at `Tsit5` and `Rodas5`. Under (e) this is a run-time membership read, which is what the predicate means;
  - a `MethodError` path: code compiled at a type that is not a member (`add_lines!` at a `Vector{Float64}` for `Positions`). There is no cost on a path that throws.
- The guard costs nothing measurable when the membership is a cell per (type, set) holding its `min_world`:
  - 0.00 ns per call where LLVM hoists the read out of the loop;
  - +0.2 to +0.6 ns per call where it cannot (a write the compiler cannot see through in the loop).
- Two conditions on (e) follow from the numbers:
  1. **Base's abstract types must stay closed.** Their members come only from `struct S <: A`, as (e) states. If the abstract types BaseTraits' families range over admitted late members, 1,326–4,619 specializations per session would carry guards, on `axes`, `eltype`, `hash`, `==` and `broadcasted`. Restricted to the cases where a package (not only Julia) could declare the membership, it is still 173–1,122 specializations per session.
  2. **The registry must be a cell per (type, set), not a scan.** U8 part B's layout, a `Vector` of `(type, set, min_world)` scanned on each read, costs 357–372 ns per call. A per-type table keyed by set costs 27–28 ns. Neither belongs in a guard.

## Results (2026-10-29)

Build: julia-1.13 `00dcc9994c`, TraitWorld `33dd55e`. Product setting, strict mode off, one session each.

- **Repositories:**
  - TDE: `w34` at `e9e07ed`;
  - TraitMakie: `7f70363` (its session rerun on 2026-10-29, after the session's Lollipop step was fixed);
  - TraitReport: `d21fe00`;
  - TraitTables: `438ac2b`;
  - TraitCSV: `9c6477b`;
  - forks: `943b065`;
  - ndport: `a5bdc75` (NetworkDynamics `ports` `dfc6663`, GraphMakie `ports` `498be7c`).
- **How the census was taken:** counts read from the code that each session compiled, re-inferred. These are counts, not timings.
- **Load:** about 1.

### Guard sites per session (trait functions: the ports' bounded methods and the defaults of operations)

| session | call sites | at concrete types | non-concrete (run-time dispatch already) | a `Dynamic`/`Kept`/`Compiled` value (a run-time split already) | positive folds | guards | of them in a loop | in bounded code | widening (none / covered / to `Any`) |
|---|---|---|---|---|---|---|---|---|---|
| TDE (`scripts/session.jl trait`, passed) | 92 | 21 | 22 | 49 | 19 | 2 | 0 | 0 | 0 / 0 / 2 |
| TraitMakie (`scripts/session.jl`, 10 of 10 checks) | 46 | 27 | 1 | 18 | 26 | 1 | 0 | 0 | 0 / 0 / 1 |
| TraitReport (`scripts/session.jl`) | 62 | 35 | 4 | 23 | 34 | 1 | 0 | 0 | 0 / 0 / 1 |
| forks (`scripts/session.jl`, `env_forks`) | 309 | 78 | 71 | 160 | 78 | 0 | 0 | 0 | — |
| NetworkDynamics on the ports (setting PT, passes first … usertype) | 217 | 100 | 22 | 95 | 65 | 3 | 0 | 0 | 0 / 0 / 3 |

- "Call sites" counts the statically resolved calls of a function with bounded methods. They are found in every CodeInstance that holds an edge to one of its method instances, both session code and image code. Each counts once per caller instance.
- "Plain" sites (a typed method selected, no bounded method could beat it) are the rest of the concrete ones: ndport 32. Their selected method is typed by the argument's own supertype (C7).
- **No guard on a subtrait** (a bounded method on a less specific set selected now, beaten later by a subtrait) occurs in any session. The self-test plants one.

### Every guard site

| function, argument types | caller | case | selected now | the guard waits on | result: now ⊔ guarded | today's inferred result | sealed variant folds | what runs on failure |
|---|---|---|---|---|---|---|---|---|
| `is_nonlinear_algorithm(Tsit5)`, `(Rodas5{DenseLU})` (TDE, ndport) | `TraitDifferentialEquations._isnonlinear` (`TraitDifferentialEquations.jl:72`) | fallback | the untyped fallback (`false`) | `Tsit5 ∉ NonlinearAlgorithm` | `Bool ⊔ Any` (no declared result) | `Any` | yes | a real fallback |
| `add_lines!(Axis, Vector{Float64}, ColorName, Float64)` (TraitMakie, TraitReport, ndport) | `TraitMakie.lines!` (`TraitMakie.jl:103`) | MethodError | none | `Vector{Float64} ∉ Positions` | `Union{} ⊔ Any` | `Any` | no (`Positions` adopts Base's vectors) | MethodError |

- **Today's results are `Any` already** at these sites: the entry reaches the fallback through an inference barrier. So (e) loses nothing against today. Option (a) would type the fallback's result (`Bool`). A declared result `::Bool` on the bounded predicate would remove the widening under (e).
- **The sealed variant** (the coordinator's question): suppose a set whose memberships are all declared at the member type's definition or in the member's own package proper folds its negatives. Then 4 of the 7 guard sites fold.
  - Such a set has no membership in an extension and none by the set's owner for a foreign type. These are U5's members by owner, refined: `by_owner`, `by_owner_param`, `generic_own_ub`.
  - The guards that stay are `add_lines!` at `Positions`, an open set.
- **The kind of fallback:** 3 MethodError, 0 a default or the same declared result, 4 real fallbacks (the predicate, at `Tsit5` and `Rodas5` in two sessions; counts from `logs/*-sites.tsv`). None of them is in a loop.

### The hypothetical `Base.show(::IO, ::X)` on an open set (U5's question)

Base has no bounded methods today. A Base function gets guards only where someone defines a bounded method on it, and U5 found none. If a package added `Base.show(io::IO, x::X)` for an open set `X`, these static calls would carry a guard, one per call to `show` at a concrete type whose selected method is Base's `show(::IO, ::Any)`:

| session | `show` call sites | guards | in a loop | widening |
|---|---|---|---|---|
| TDE | 548 | 8 | 6 | none (both `Nothing`) |
| TraitMakie | 554 | 17 | 9 | none |
| TraitReport | 545 | 16 | 9 | none |
| forks | 699 | 15 | 6 | none |
| ndport | 792 | 18 | 6 | none |

- The guards in loops are Base's printing code: `show_delim_array` printing a `Base.PkgId`.
- None of these guards widens a result.
- The sealed variant removes none of them, because the hypothetical set is open.

### Base's abstract types as open sets (the other treatment)

What (e) would cost if `AbstractArray`, `AbstractDict` and `AbstractString` (and `Dates.Period` and `LinearAlgebra.Factorization` where loaded), with their abstract subtypes, admitted late members. Counted per session: the specializations at concrete types whose selected method would lose to the same function's method on such a type that the argument is not a subtype of (C7). This is read from method instances and their callers, without re-inference and without loops.

| session | functions | specializations | their static callers | where a package could declare the membership: specializations / callers |
|---|---|---|---|---|
| TDE | 79 | 1,420 | 5,119 | 226 / 354 |
| TraitMakie | 83 | 1,326 | 4,665 | 173 / 253 |
| TraitReport | 83 | 1,530 | 5,400 | 208 / 299 |
| forks | 102 | 2,204 | 9,228 | 301 / 643 |
| ndport | 224 | 4,619 | 13,106 | 1,122 / 1,864 |

- **Top functions:** `axes`, `eltype`, `hash`, `cconvert`, `==`, `broadcasted`, `any`, `sum`.
- **"A package could declare"** means the argument names a type that Core, Base or a standard library does not own. Where every type is Julia's, only Julia may declare the membership, so the negative stays folded by ownership (U7's finding 2).
- **This is an upper bound.** It counts the `Compiler` package's types and TraitWorld's own types as a package's.
- **The reading:** under (e), Base's abstract types must stay closed, with members only through `struct S <: A`, as the option states. BaseTraits' traits (`Indexable`, `Iterable`, …) are open; their bounded methods are what the main table counts.

### The cost of one guard (`guardcost.jl`, `jl --exclusive`)

The setup:

- The call `f(x)` is made at a non-member `S`. The selected method `m0` runs, and the guarded branch (the bounded method, a run-time site) never runs.
- The figure is ns per call: the median over 2,001 loops of 1,000 calls, with p10 and p90 in the logs.
- julia-1.13 `00dcc9994c`, one thread, load 0.6–1.4. Four runs on 2026-10-29: `logs/guardcost-1.log` to `-4.log`. Runs 1–2 have no opaque variants.

| variant | `m0` inlined | `m0` `@noinline` | allocation |
|---|---|---|---|
| `plain` (no guard: option (a), or a closed set) | 0.903–0.923 | 3.08–3.09 | 0 |
| `cell`: a cell per (S, X) with the membership's `min_world`, read against `tls_world_age()` | 0.903–0.924 | 2.00–2.04 | 0 |
| `cell_fast`: the world read only where the cell holds a membership | 0.904–0.926 | 2.00–2.04 | 0 |
| `plain_opaque`: a `@noinline` write in the loop | 5.13–5.57 | 6.21–6.39 | 16 B (the write's) |
| `cell_opaque`: the same with the guard | 5.48–5.78 | 6.75–6.97 | 16 B |
| `dict`: a per-type table keyed by set (`IdDict`), a `@noinline` read | 26.8–28.2 | 27.5–28.8 | 0 |
| `registry`: U8 part B's `Vector` of `(type, set, min_world)`, 21 entries, scanned | 357–374 | 361–375 | 0 |
| `cell_widened`: `cell` with the guarded result not declared, so the sum is `Any` | 23.9–25.3 | 25.1–25.7 | 32 B |

- **The cell's load and compare are loop-invariant.** LLVM unswitches the loop on them, so in `cell` the guard costs nothing per call. The loop's LLVM is in `logs/guardcost-3.log`.
- **Where the read cannot be hoisted** (`*_opaque`), the guard adds 0.2–0.6 ns per call.
- With `m0` behind `@noinline`, the guarded loop is faster than the plain one (2.0 against 3.1 ns) in every run. That is code layout, not the guard.
- **A guard that widens costs 24–25 ns and 32 B per call** in a loop, because its result is boxed. That is the case the criterion asks about. No such site exists in the ports.

## Findings for the design

1. **Where the guards come from.** Guards arise only at the boundary, from capability predicates written as dispatch and from a `MethodError` path.
   - Inside bounded code there are none. There an argument's membership is positive by construction, and the ports have no subtrait methods competing with a supertrait's.
   - The predicate is the case §13.4 names ("the capability test of open issue 82 (b) … there a run-time read is what one wants"). For a predicate, the guard is the semantics, not a cost.
2. **Base's abstract types decide the count.** If they stayed open, guards would land on Base's hottest generic functions in every session. Ownership removes most of them: only Julia may declare a Julia-owned type a member of a Julia-owned family. But 173–1,122 specializations per session remain where a package's type is involved. So (e) needs the rule it states: abstract types are closed, and the open sets are the traits.
3. **The registry's layout matters by three orders of magnitude.** U8 part B shows world-correctness. As a guard's read it must be a cell per (type, set), fixed when the guard is compiled: a load and a compare, hoistable out of loops. It must not be a lookup in a table.
4. **The sealed variant removes most of the remaining guards** (4 of 7). The ones left are on open sets that adopt Base's types (`Positions`).
5. **Today's lowering asserts a bounded function's declared result on the untyped fallback too.** The self-test's `describe(x) = :plain` beside `describe(s::Shape)::String` raised a `TypeError` through the entry. Under (e), `m0` is an ordinary method with its own result. So "the guarded result is the bounded method's declared result joined with `m0`'s" is a change from today, not a description of it.
6. **Unrelated, seen on the way: TraitMakie's REPL session refused its Lollipop recipe.** The session's `setcolor!(l::Lollipop, c::Dynamic{ColorSpec})` did not cover the `Kept{ColorSpec}` that the `Plot` trait declares, so `@implement Plot Lollipop` raised "Lollipop has methods for some operations of Plot but not for setcolor!". The message names the operation, not the declared signature or the near-miss method: [open issue 139](../../../writeup/open-issues.md). TraitMakie `1af318c` fixed the session. The census was rerun on 2026-10-29 at `7f70363` (10 of 10 checks): `add_plot!(Axis, Lollipop)` is now a positive fold, and the TraitMakie row counts the recipe part.

## What the census counts, and what it does not

- **The model (open issue 136 (e)):**
  - A bounded method `f(x::X)` is a method at `X`.
  - A compiled call at concrete argument types folds a positive membership.
  - It carries a guard where a bounded method that does not apply now would apply after a later membership and would beat the method selected now.
  - Specificity per position: a plain type other than `Any` (the argument's own declared supertype) first, then a set (C7), then `Any`. Between sets, a subtrait comes first. Between plain types, subtyping decides.
  - No guard where the argument is one of Core's kinds or a type value (E-255).
- **Bounded methods are read from TraitWorld's registries:**
  - the workers of every function in a trait module's `__tw_entries__` or `__tw_extended__`, with their bounds per position (U5's reading);
  - the defaults of operations (`has_default`), as a bounded method of the operation at its trait, with the declared result read from `op_ret` at the erased key.
- **Plain methods:** every method of the function except the entries, the workers and the operations' trait-object methods. A tagged untyped fallback counts as the method it stands for.
- **Membership:** `TraitWorld.conforms` in the newest world.
  - A trait object (`TObj`) inside bounded code stands for its key's receiver type, a member of the traits it carries. An erased key counts as a `Dynamic` value.
  - `Dynamic`, `Kept` and `Compiled` values are run-time splits, counted apart.
- **The declared result:** the type that both an `isa` and a `typeassert` of the method's lowered body name, which is how Julia lowers `f(…)::R`. Otherwise `Any`.
- **The call sites:** the CodeInstances holding a backedge to a method instance of the function, re-inferred unoptimized (by facts for the facts owner), with each call statement's argument types.
  - "In a loop": the statement lies in a cycle of the caller's control-flow graph. That is not a measure of hotness, as in U7.
- **Not seen:**
  - calls that code compiled by facts makes at a non-fact signature: run-time sites with no edge;
  - calls inferred at abstract types that match several methods: a method-table edge. The non-concrete counts are lower bounds. Both kinds are run-time dispatch already.
  - Top-level thunks: none were compiled.
- **The session drivers:**
  - `drive.jl` evaluates a REPL session file expression by expression, as the REPL does: soft scope, results shown unless the input ends with `;`, errors shown, `exit()` skipped.
  - In script mode (`U9_MODE=include`) it includes the workload as a script.
  - The census then runs in the same process.
- **The self-test** (`selftest.jl`, `run_selftest.jl`, `logs/selftest.log`) plants one site of each kind: a positive fold, a guard on a subtrait (in plain code and in bounded code), a guard on a fallback (one in a loop), a `MethodError` guard, a type value (no guard), a declared supertype beating a bound (no guard), and a non-concrete call. The census finds each.

## How to run

From the design repository's root:

```bash
experiments/w83/u9/run_all.sh                       # selftest tde makie report forks ndport, or any of them
experiments/tools/jl --exclusive julia-1.13/julia --startup-file=no experiments/w83/u9/guardcost.jl   # U9_SHOW_CODE=1: the guarded loop's LLVM
```

- **Depots:** `run_all.sh` runs through `jl --name w83u9`. The slot depot is stacked over `run_all-plain`'s caches, and over `ndport/depot-ports` for ndport. ndport precompiled into the slot depot once, which took about 4 minutes. The slot depot was removed afterwards.
- **Files.** Each session writes:
  - `logs/<label>.log`: the session's output and the census report;
  - `logs/<label>-sites.tsv`: every call site, with its case, loop flag, whether it is in bounded code, the trait object's key, the sealed variant, the fallback's kind, the method selected now, the guarding methods with the positions they wait on, the results, and the caller;
  - `logs/<label>-bounded.tsv`: the bounded methods read;
  - `logs/<label>-basefamilies.tsv`: the other treatment, per specialization.
