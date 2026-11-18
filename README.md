# Experiments

The gates, measurements and tools of the trait-bound Julia design. The design is in the design repository (`../writeup/`), and this repository sits inside it.

- **The registry** of experiments (the question, the baseline, the build, the outcome, by ID `E-n`) is `../writeup/record/experiments.md`. A new experiment gets its row there before it runs.
- **The current numbers** are in `../writeup/design/evidence.md`. A README here says how to run, and keeps dated tables of its own results.
- **What to run after a change:** `../writeup/record/playbook.md` §3.

## The implementation's experiments

| Directory | What |
|---|---|
| `unification/` | the gates (`gates/`), the acceptance cases of the facts mode (`test/acceptance/`), the audit's probes (`audit/`), and one directory per piece of work or experiment (`w…`, `e…`, `x…`). [Its README](unification/README.md) lists them |
| `docs-examples/` | the examples of `../writeup/intro/` and of the references, as scripts that run |
| `docs-checks/` | checks of the documents: links, quotes, tables |
| `tools/` | `jl` (a Julia job in a slot, with its own depot and a memory guard), the A/B harness (`ab/`), the documentation lint (`doclint/`), the tools for finding slowdowns. [Its README](tools/README.md) |

## Plain Julia and Python: the baselines

| Directory | What |
|---|---|
| `ttfx/` | the first-use workloads, in plain Julia and in Python (SciPy, matplotlib, pandas); the Python versions |
| `solvers/` | plain SciML: the first solve, callbacks, automatic differentiation |
| `errors/` | where unreadable error messages come from: C++ templates and concepts, SciML |
| `world/concrete/` | what one abstract field deep in a type hierarchy costs |
| `interfaces/` | what compiling per user type costs a plotting library (`scripts/x8_types.jl`) |
| `facts/` | plain Julia's invalidation at a concrete signature (`e3_exact.jl`); the acceptance cases' origin |
| `w83/u6/` | how plain Julia loads a package extension |

## Earlier work that scripts still read

`checks/`, `examples/`, `factscompiler/`, `hetero/`, `hetero-idiomatic/`, `loadcosts/`, `sysimage/`, `w34-sciml/`, `w66/`, `w80/`, `x3/` and the rest of `facts/`, `interfaces/`, `world/` and `w83/` belong to earlier iterations of the design, on Julia 1.13 with the library of that time (tag `pre-unified` in each repository). A script or a README of the directories above still reads them. Their rows are in the experiments' ledger, `../attic/writeup/record/experiments-archive.md`.

## The attic

[`attic/`](attic/README.md) holds the earlier experiments that nothing reads.

## Running

- `source env.sh` in the design repository first on a shared host.
- One Julia process per gate or cell, 4 cores. `tools/jl` gives a job its slot.
- Environments name TraitWorld and the demonstrators by paths relative to the workspace. Scripts find the workspace from their own place; `TW_ROOT` overrides it.
- Logs are committed, in the experiment's directory.
