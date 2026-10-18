# Experiments

The smaller experiments of the trait-bound Julia design: prototypes around TraitWorld, measurements, and one-off studies. The design is in the design repository (`../writeup/notes/`). TraitWorld, the patched Julia and the two large rewrites (TraitDifferentialEquations, TraitMakie) are repositories of their own beside this one.

Until 2026-10-16 this was the `poc/` directory of the design repository; its history came along. Paths in older session notes and findings that start with `poc/` now start with `experiments/`.

| Directory | What | Write-up |
|---|---|---|
| `world/` | TraitWorld's first prototype libraries (Columns, Stats, Rows, UserTypes, App), benchmarks, concrete mode, the trimmed binary, the definition-checking demo | `world/README.md` |
| `interfaces/` | the prototype around DataFrames and Makie: trait wrappers, calls upward, sealing audits, view caches, ComboCache, the full and trimmed App binaries, Makie dispatch tracing (x1–x16), the Python baseline | `interfaces/README.md` |
| `errors/` | where unreadable error messages come from: C++ templates and concepts, SciML | `errors/README.md`; design-findings §17 |
| `lens/` | the cost of a field reference against a held value | design-findings §18 |
| `solvers/` | stock SciML baselines: time to first solve, callbacks, automatic differentiation | `../writeup/explorations/solvers.md` |
| `runtime-injection/` | the load-time invalidation filter injected into stock Julia 1.12.2 and 1.13.2 | `runtime-injection/README.md`; `../writeup/explorations/runtime.md` |
| `examples/` | small cases that stress-test the design (session 29): strict mode on real pirates and split-core pairs, a glue extension, heterogeneous collections, errors at definition, warnings that teach, redefinition at the prompt | `examples/README.md` |
| `facts/framing/` | the framing's acceptance cases: S1–S10, a Vararg splat, a pirate in each order under both tiers, G1.16 | `facts/framing/README.md` |

**Environments.** The environments under `world/env` and `interfaces/env` develop TraitWorld from `../../../TraitWorld`, the sibling repository.

**Running on the shared machine:** one Julia job at a time, niced; full juliac builds alone, under a memory guard.
