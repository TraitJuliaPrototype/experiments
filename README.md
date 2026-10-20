# Experiments

The smaller experiments of the trait-bound Julia design: prototypes around TraitWorld, measurements, and one-off studies. The design is in the design repository (`../writeup/design.md`; the map of the record is `../writeup/record/INDEX.md`). TraitWorld, the patched Julia and the two large rewrites (TraitDifferentialEquations, TraitMakie) are repositories of their own beside this one.

Until 2026-10-16 this was the `poc/` directory of the design repository; its history came along. Paths in older session notes and findings that start with `poc/` now start with `experiments/`.

**The registry of experiments** (questions, statuses and outcomes, by ID) is in the design repository: `../writeup/record/experiments.md`. Add a row there before running a new experiment.

| Directory | What | Write-up |
|---|---|---|
| `world/` | TraitWorld's first prototype libraries (Columns, Stats, Rows, UserTypes, App), benchmarks, concrete mode, the trimmed binary, the definition-checking demo | `world/README.md` |
| `interfaces/` | the prototype around DataFrames and Makie: trait wrappers, calls upward, sealing audits, view caches, ComboCache, the full and trimmed App binaries, Makie dispatch tracing (x1–x16), the Python baseline | `interfaces/README.md` |
| `errors/` | where unreadable error messages come from: C++ templates and concepts, SciML | `errors/README.md`; design-findings §17 |
| `lens/` | the cost of a field reference against a held value | design-findings §18 |
| `solvers/` | stock SciML baselines: time to first solve, callbacks, automatic differentiation | `../writeup/explorations/solvers.md` |
| `runtime-injection/` | the load-time invalidation filter injected into stock Julia 1.12.2 and 1.13.2 | `runtime-injection/README.md`; `../writeup/explorations/runtime.md` |
| `plotwork/` | a plotting session with upstream packages only (CSV, DataFrames, CairoMakie, no trait code), plain against the test bed `all`: what the facts mode saves on recompilation against what it costs per round of work (E-140) | `plotwork/README.md` |
| `examples/` | small cases that stress-test the design (session 29): strict mode on real pirates and split-core pairs, a glue extension, heterogeneous collections, errors at definition, warnings that teach, redefinition at the prompt | `examples/README.md` |
| `facts/framing/` | the framing's acceptance cases: S1–S10, a Vararg splat, a pirate in each order under both tiers, G1.16 | `facts/framing/README.md` |
| `facts/` | wrapping by facts: the acceptance suite (`acceptance_compiler.jl`, 19 checks on the facts compiler), the hunt, `g2all` (no compiled code lost over twelve loads), `g2strict` (strict mode on a real stack), `typedbench` (typed against untyped calls) | `facts/README.md` |
| `factscompiler/` | the facts compiler's measurements (session 29): BaseBenchmarks under `all`, the recovery cases (raytrace, `dynmicro`), the control (`control/`), the facts system image's build script, and `session29/`: the performance phase's scripts and logs | `factscompiler/README.md`; `session29/README.md` |
| `sysimage/` | TraitWorld in the patched system image (session 26): the policy in the platform, a prototype superseded by the facts compiler | `sysimage/` |
| `aot/` | trimmed binaries on 1.13 (session 25): TraitMakie, 4.07 MB | `aot/` |
| `demos/` | the demonstrators' measurement rows before the facts compiler (sessions 26–27) | `demos/` |
| `keys-proto/` | the runtime as methods, prototyped before TraitWorld adopted it (session 23) | `keys-proto/` |
| `review-s23/` | the review of session 23's cases | `review-s23/` |
| `baseline-1.13/`, `baseline-1.13.md` | stock 1.13.2 baselines | `baseline-1.13.md` |

**Environments.** The environments under `world/env` and `interfaces/env` develop TraitWorld from `../../../TraitWorld`, the sibling repository.

**Running on the shared machine:** one Julia job at a time, under `flock /tmp/claude-1000/julia-review.lock`, niced; full builds alone, under a memory guard (`../session-notes/00-environment-and-workflow.md`).
