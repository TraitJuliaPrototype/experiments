# Evidence for "wrapping by facts" (session 23, 2026-10-16)

Design: `writeup/explorations/wrapping-by-facts.md` in the design repository. Stock Julia 1.13.2, niced, serialized through the session's Julia lock.

## E3: is stock invalidation exact at concrete signatures? (`e3_exact.jl`)

A caller `g(x::Float64) = f(x) + 1` holds the fact "`f` at `Tuple{Float64}` selects `f(::Real)`". Each case defines one new method:

| new method | changes plain Julia's result | invalidated |
|---|---|---|
| `f(::Number)` (less specific) | no | no |
| `f(::Int8)` (does not apply) | no | no |
| `f(::String)` (does not apply) | no | no |
| `f(::Float64)` | yes | yes |
| `f(::AbstractFloat)` | yes | yes |
| `f(::Union{Float64,Int8})` | yes | yes |
| `h(::Real, ::Any)` against `h(::Real, ::Real)` (loses) | no | no |
| `h(::Float64, ::Any)` and `h(::Any, ::Float64)` (ambiguous) | yes (error) | yes |
| `h(::Float64, ::Real)` | yes | yes |

**Result:** exact in all nine cases. A definition invalidates code at a concrete signature if and only if it wins there or makes the call ambiguous. Rule P needs no runtime predicate.

## E1 and E2: the demonstrators' closure, with CSV, DataFrames and CairoMakie loaded first (`e12_closure.jl`)

**Setup:**
- run TraitDifferentialEquations (Tsit5 with a callback, Rodas5) and TraitMakie (lines, scatter, save);
- collect every CodeInstance reachable through edges from the trait modules' code (ODECore, PlotCore and their conformance methods);
- classify the edges as concrete facts (a MethodInstance at a concrete signature) or abstract facts (match sets at non-concrete signatures, or MethodInstances at abstract signatures).

**Closure:** 3,533 CodeInstances; 3,043 concrete facts; 207 abstract facts (6%).

**E2:**
- Pirates from outside Julia that dispatch currently selects at a concrete fact: **0**.
- The stack brings OffsetArrays' 12 pirates of Base, plus StatsBase's and Durations'. None of them wins at any signature the demonstrators' code uses.

**E1:**
- **Where the abstract facts sit:** 42 methods hold them, and 6 of those were sampled at all over 30 runs of the work (94,426 samples).
- **The only one with a measurable share** is TraitWorld's declared-call path (`@call`, Cairo), at 1,500 samples (1.6%): an `invokelatest` result passed to `_wrap_result`. Under the facts design Cairo calls become ordinary direct calls, so this site disappears.
- **The other five** are TraitWorld machinery building `Dynamic` values (`_carries`, `_decode_traits`, the `Dynamic` constructors): 2 samples each, cold.
- **The remaining abstract facts were never sampled.** They are TraitWorld machinery (entries at `Any`, `Dynamic` operations, `_rep`/`_loadpart` on the object held as `Any`) and reflection or printing paths in Base (`_uniontypes`, `print` of types, `collect` of type variables).

## E0 (earlier): what invalidated ODECore (`../review-s23/invalidation_chains.jl`)

With CSV, DataFrames and CairoMakie loaded after TraitDifferentialEquations, the two chains that reached ODECore started at abstract edges:
- `TraitWorld._show_key(::IOBuffer, ::Any)`, the machinery's printing;
- `promote_type(::Type{Int64}, ::Type)`.

No chain started at a concrete fact.

## Reading

- **E3** confirms rule P on stock Julia: no runtime predicate is needed for exactness.
- **E2** finds no winning pirates in this stack, so following plain Julia (the core, without the strict mode) costs nothing here.
- **E1** finds abstract sites only in cold or machinery paths. The demonstrators' hot loops are concrete facts.

Limits:
- **Two small libraries, one stack of packages.** E2 should be repeated with larger trait-world code (more of Base used) and other stacks.
- **"Hot" here means sampled time in the demonstrators' workloads,** not per-element loops in general.
- **Under R, the abstract sites of the machinery would be dynamic calls.** The entries already are dynamic for untyped callers, so this changes little.

## hunt/: the adversarial G1 suite (session 24, 2026-10-17)

`batch1.jl` … `batch6.jl` hold 48 cases (about 125 checks), written by an adversarial subagent. Each compares plain Julia with `TraitWorld._facts_call` (dynamic, and inlined into a native wrapper) before and after redefinitions, added methods and deleted methods. `h.jl` is the harness. Two failure classes were found and fixed in TraitWorld f558180; the reproducers are `repro_*.jl`.

On f558180 everything passes except:
- **C16** (`promote_op` at `Type{Int}`): plain Julia gives `DataType` when the call is folded into compiled code and `Type{Int64}` at run time. Inference-dependent values have no single plain answer (G1 carve-out).
- **C24b**: a harness bug (the calls use different arguments); C24c is the corrected case and passes.

## E-198: strict mode on code of the facts owner, and pirates reported at an image's load (W-66 step 3), 2026-10-28

julia-1.13 8ceda6f9d6; TraitWorld d924f38 (before) and the branch `w66-strict-facts` (after, merged); [the note](../../writeup/plans/2026-10-28-strict-mode-on-facts-code.md). Logs `e198/logs/`, sessions `../ttfx/logs/e198-before/`, `../ttfx/logs/e198-after/` (a warm-up and two sessions each).

| Check | Before | After |
|---|---|---|
| C, strict mode: load / session | 10.20–10.34 / 16.60–16.64 s | 10.19–10.33 / 16.60–16.78 s |
| C: methods seen, pirates walked, owning, walking, misses | 79,138, 876, 0.85 s, 0.71 s, 0 | 79,138, 876, 0.91 s, 0.58 s, 0 |
| D, strict mode: load / session | 0.71 / 1.25–1.26 s | 0.70–0.71 / 1.24–1.25 s |
| D: methods seen, pirates walked, owning, walking, misses | 6,531, 52, 0.06 s, 0.19 s, 0 | 6,531, 52, 0.06 s, 0.15 s, 0 |
| refusals in C and D | none | none; no pirate reported at a load |

- **Case (d)** (`e198/compiler_chain.jl`): TraitWorld's machinery calls the compiler; a pirate at a signature of Julia's plain code that the compiler's code calls there is refused, at all three chains found (`getindex(::RefValue{Symbol})` twice, `isempty(::SimpleVector)`).
- **Part B** (`e198/pirate_before.jl`, `env_d`): `abs2(::Float64)` defined in `Main` before TraitDifferentialEquations loads is reported in strict mode, naming the pirate, `rodas5_step!` and the fact; a pirate that wins nowhere is not; strict mode off is silent. Both settings of strict mode compute the pirate's result.
- **Suites** (`../checks/logs/e198/`): every suite passes; under `all` TraitWorld's standing `verify_dynamic.jl:40` only, its strict tests included; the strict documentation example 5/5.
- **The walk is a small part of strict mode's cost:** C's strict load is about 6 s slower than without strict mode (4.2 s), of which owning and walking are 1.5 s; the narrowing does not change it. Where the rest goes is not diagnosed.
- The validation log kept on for the session costs nothing measurable here (C's strict load before and after).

## E-204: where C's strict-mode load goes, and two fixes (W-75), 2026-10-28

A profile of the workload's `using`s (`w75/profile_strict_load.jl`, 1 ms; strict mode on and off), julia-1.13 5071b67894. With strict mode on, 7,707 samples fell inside image restore against 1,836 off; under it, TraitWorld's image hook: the extensions' check 3.2 s, of which `_extension_parent`'s scan of all loaded modules per method 2.3 s (the image's own package is not registered yet, so the negative cache missed it); the extension warnings 1.2 s; the walk 1.6 s; ownership 0.8 s (`w75/strict1.log`).

Fixes (TraitWorld a72b176): extension parents memoized for an image's scan; the warnings' text built at most 20 times; the warning names the trait code's method instead of printing its CodeInstance.

| Strict mode on | before (TraitWorld b179274) | after |
|---|---|---|
| C load | 10.19–10.33 s | 7.24–7.28 s |
| C session | 16.60–16.78 s | 13.64–13.76 s |
| D load | 0.70–0.71 s | 0.65 s |
| D session | 1.24–1.25 s | 1.19 s |

- Left in C's strict load (`w75/strict1-after2.log`): the walk 1.6 s, the extensions' check 1.3 s, their 11 warnings 0.9 s, ownership 0.8 s. Without strict mode C loads in 4.0 s.
- C's second model took 0.36 s in both sessions after the change, against 0.19 s before; not diagnosed.
- Every suite passes (`../checks/logs/e204/`).
