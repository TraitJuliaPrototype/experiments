# The experiments' attic

Experiments of earlier iterations of the design that no current script or document reads. Each was at `experiments/<name>/` and is unchanged.

- **Their rows** are in the experiments' ledger, `../../attic/writeup/record/experiments-archive.md`, which names them by their old paths.
- **Their scripts** ran on Julia 1.13 with the library of that time (tag `pre-unified` in each repository), from `experiments/<name>/`. A script that names a sibling by a relative path (`../tools/jl`, `../facts/`) needs that path adjusted to run from here.

| Directory | What |
|---|---|
| `aot/` | trimmed binaries on 1.13 |
| `baseline-1.13/`, `baseline-1.13.md` | stock 1.13.2 baselines of the first demonstrators |
| `carry/`, `fallback/`, `l50/`, `lens/` | single measurements: carried values, the fallback, a field reference against a held value |
| `demos/`, `phase2-round/` | the demonstrators' measurement rows of the earlier library |
| `docs-examples/` | three scripts of the documentation's examples, at `experiments/docs-examples/` before: `ahead_invalidation.jl` (entry methods compiled ahead), `reference.jl` (the references' examples of October 2026), both for the library of `pre-unified`; `keep_at_prompt.jl` (`keep` at the prompt, open issue 175) and its log, for TraitWorld `unified` 05991fc. `reference.jl` reads `common.jl` beside it, which stays in `experiments/docs-examples/` |
| `dyncomp/` | the dynamic and compiled forms of the earlier library |
| `keys-proto/` | the runtime as methods, prototyped |
| `overnight-2026-10-21/`, `overnight-2026-10-22/` | two nights' runs |
| `plotwork/` | a plotting session with upstream packages only, plain against the test bed |
| `review-2026-10-26-references/`, `review-s23/` | reviews' cases |
| `runtime-injection/` | the load-time invalidation filter injected into stock Julia |
| `w57/`, `w78/`, `w81/`, `w91-callable-entries/`, `w92-forks-invalidation/`, `w93/`, `w94/`, `w105/`, `w130/`, `w131/`, `x7/` | work items' experiments of the earlier library |
