# E-182: loading stubs and the waist at small scale (W-60's X7)

The memo [`writeup/plans/2026-10-27-lean-core-old-apis.md`](../../writeup/plans/2026-10-27-lean-core-old-apis.md) §4 (X7), testing [its review's](../../writeup/reviews/2026-10-27-lean-core-memo.md) B1–B3 with TraitMakie (trait) against PlainPlots (plain).

**How to run:** `bash run.sh <tag>` runs every case of `x7.jl` in fresh sessions (logs in `logs/<tag>/`); the hand-over case alone: `X7_KIND=trait X7_CASE=handover X7_FORM=direct|handover julia --project=env x7.jl`.

**What it builds:**
- `pkgs/X7Stats`, `pkgs/X7StatsSparse`: a trait module with a histogram recipe of its own (`Hist2`) implementing TraitMakie's `Plot`; the second also loads SparseArrays, as a statistics tree does.
- `pkgs/X7PlainStats`, `pkgs/X7PlainStatsSparse`: the plain control, a type with methods of PlainPlots' `datalimits` and `draw!` (PlainPlots' way to add a recipe).
- `x7.jl`: a loading stub in plain code (`Base.require` at the first `hist2!`, then the provider's own function through `invokelatest`), and the cases.

## Results, 2026-10-27

julia-1.13 6800be7839, TraitWorld `session-cache` 25419a7 (the cache off), TraitMakie 9436157; product setting; fresh sessions, two runs where a time is measured; `logs/r1/`.

**(i) World age (B1):** a first `hist2!` (the provider loaded by the stub) and a `save` in one function.

| | `save` direct | `save` through `invokelatest` |
|---|---|---|
| trait | error: the render, in the caller's world, finds no implementation of `Plot` for `Hist2` (`_narrow(::Type{Plot}, ::NoTrait)`) | ok |
| plain | error: `MethodError: no method matching datalimits(::Hist2P)` | ok |

**(ii) The waist (B3):** a first render of the core's recipes, the provider loaded, the same figure rendered again.

| | the core's CodeInstances invalidated | the render after the load (compiled) | the provider's load and first call |
|---|---|---|---|
| trait, provider | 0 of 689 (483 of owner `:facts`) | 7.2–7.6 ms (0 ms) | 0.14 s |
| trait, provider with SparseArrays | 0 of 689 | 7.2–8.3 ms (0 ms) | 0.31–0.32 s |
| plain, provider | 3 of 223 (`save`, `render_png`, a closure) | 70–73 ms (63–66 ms) | 0.03 s |
| plain, provider with SparseArrays | 8 of 223 (also `datalimits`, `draw!`, `steppoints`, …) | 162 ms (155 ms) | 0.19 s |

**(iii) The hand-over (B2):** a plot type of a plain module, its attributes in a `Dict{Symbol, Any}`, implementing `Plot`; its operations call the module's plain helpers directly, or through `Dynamic{Callable}`s (closures the old machinery would register). Each form in its own session; the CodeInstances of the module's helpers after the first render:

| form | the helpers' code that runs | the other owner | the first render's compilation |
|---|---|---|---|
| direct | owner `:facts`, native | `nothing`, inferred only | 199–201 ms |
| hand-over | owner `nothing` (plain), native | `:facts`, inferred only, no native code | 262–269 ms |

Also: the direct form's operation must assert its declared result (`old_limits(a)::NTuple{4, Float64}`): `@implement` refuses an operation whose inferred result is `Tuple{Any, Any, Float64, Any}`.

**(iv) Cost per call:** the stub 150–170 ns (trait), 230–245 ns (plain), against the provider's function called directly 115–142 ns; `save` through `invokelatest` 6.23–6.38 ms against 6.23–6.41 ms direct.

**What it says:**
- **World age is Julia's, not the trait world's:** both kinds fail with a direct `save` and work through `invokelatest`. The memo's rule (user-facing entries through `invokelatest`) works, at no measurable cost per `save`.
- **The waist holds at this scale, and it is trait-specific:** the provider's load invalidates none of the trait core's code, with or without SparseArrays; the plain twin loses its render path and recompiles 63–155 ms. The named exception (SparseArrays' `vcat`) did not occur: TraitMakie's core does not reach it.
- **The hand-over keeps the old machinery's code plain where it runs,** as compiler §3.1 states for `:caller_world` pointers; without it, the core's calls compile that code by facts. But code compiled by facts still infers through the callable into the plain helpers, making no code, and the first render costs about 65 ms more at this scale. Whether the hand-over pays depends on the facts mode's cost on the old machinery's untyped code at scale (B5's 21.9 against 6.5 s), not measured here.
