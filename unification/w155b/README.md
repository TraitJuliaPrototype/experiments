# W-155, continued: D-9, D-11, D-12, D-13 (the third wave)

The plan's rows D-11 (a membership adds no type equality), D-12 (a pirate reported by default), D-9 (owner-only functions) and D-13 (a membership taken back), built in `julia-s3` (branch `next-s3`, from `next` 9b6dacf5c5) with the library in `TraitWorld-s3` (branch `s3`, from `unified` bb4ad00). Registry: E-431, E-456 to E-459 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md` §1, "The third wave on `next-s3`". The agent's session note: `session-notes/2026-11-15-agent-w155b.md`.

## How to run

```
source env.sh        # the workspace's env.sh, a depot of this agent's own in front of the shared one, $JS, $CSVFILE, $LOADS
$JS --project=env_lib gate_d11.jl                         # E-456: D-11's gate, the unions inside a parameter
bash suites.sh julia-s3 <label> [tests library digests gate]   # Base's core, subtype, Compiler/inline,
                                                          # Compiler/inference; the library's suite; the forks' digests
bash owner_only/run.sh <label>                            # E-431: precompile the three environments, then the census
$JS --project=<env> diag/why_not_deep.jl [csv] <pkg>...   # open issue 211's tool: why each instance is outside the class
```

- **Environments.** Copies, so that no gate loads a tree another agent changes. `env_forks`, `env_facts`, `env_session` are W-155's (`../w155/`), the library at `TraitWorld-s3`. `env_demo` is W-134's (`../w134/env_demo`): the library at `TraitWorld-s3`, the ODE packages at `TraitDifferentialEquations-s3`, a detached worktree of `TraitDifferentialEquations-unified` at the tag `prototype-2026-11` (b730628); TraitCSV, TraitTables, TraitMakie from their `-unified` trees. `env_lib` is W-134's, the library at `TraitWorld-s3`.
- **The depot.** `.julia-depot/agent-depots/w155b` in front of the shared depot: every rebuild of `julia-s3` precompiles the environments again there.
- **`owner_only/census.jl`** (E-431): every method whose function belongs to another owner, who names the definer no joint owner, and is neither exported nor `public` there; by the function's module: (a) declares `facts`, (b) a package's module that does not, (c) Julia's own. For (a) and (b): whether the owner's own code compiled by facts calls the function, and whether code compiled by facts relies on the method.
- **`diag/why_not_deep.jl`** (open issue 211): every valid instance outside the deep class, by the first edge that keeps it out. The reason "membership" counts the pattern: an edge kind the class allows that the predicate tests as a callee.

## Results

### E-456 (2026-11-15): D-11's gate

`next-s3` e967266d9e against the baseline 9b6dacf5c5; TraitWorld-s3 bb4ad00, forks 439bae7; product setting, strict mode off, one thread; load 4 to 6 of 128. `logs/e456-gate.log`, `logs/e456-gate-before.log`, `logs/d11-*`, `logs/base-*`.

| | the baseline | D-11 |
|---|---|---|
| `gate_d11.jl`: checks failed of 33 | 7 | 0 |
| Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` | pass (W-155's `final-*` logs, the same commit) | pass |
| the forks' digests | equal (W-155) | equal, 26 steps |
| the library's suite | fails 8 checks of `test/strict.jl` | the same 8 (open issue 211) |

- The first build left `<:` unchanged: a question asked afresh from inside the walk (`jl_subtype` in `local_forall_exists_subtype`, the tuple walk's separable elements, intersection's fast paths) dropped the walk's rule. Fixed in the commit (`subtype_fresh`).

### E-431 (2026-11-15): methods that extend another package's internal function

`next-s3` e967266d9e (the count does not depend on D-9); TraitWorld-s3 bb4ad00, forks 439bae7, the ODE packages b730628, TraitMakie c862914; after the loads (and the CSV work in `env_forks`, `env_facts`); load 6 to 8 of 128. `logs/e431-census.log`.

| | the forks and the loads | upstream by facts and the loads | the trait demonstrators, the ODE packages and the loads |
|---|---|---|---|
| methods of packages | 55,711 | 54,876 | 52,595 |
| (a) the function's module declares `facts` | 0 | 86: CSV → Tables 53, DataFrames → Tables 27, StructArrays → Tables 6 | 12: TraitMakie → TraitWorld 8 (`_fwd`, `_like`), TraitRodas → ODECore 4 (`step_*!`) |
| (a): the owner's facts code calls the function; facts code relies on the method | — | 71; 15 | 1; 1 |
| (b) a package's internal function, its module without `facts` | 479 | 394 | 369 |
| (c) Julia's internal functions | 3,951 | 3,843 | 3,595 |

- The forks' modules that CSV and DataFrames extend (`Tables` itself) do not declare `facts`: their 79 methods are in (b).
- Upstream by facts is the path's first step: one line per module. Under a default for every module that declares `facts`, the Tables interface that CSV, DataFrames and StructArrays extend (`istable`, `getcolumn`, …; 71 of the 86 methods are of functions Tables' own facts code calls) would be owner-only, and those methods pirates.
- TraitMakie's 8 are methods the library's lowering generates in the member's module (forwarding, `like`) at the library's own internal functions; TraitWorld declares `facts` by `@compiler_options`, not as a trait module.
