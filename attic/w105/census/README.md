# E-263 and E-264: the ports' code under the draft reference

Two censuses for W-105 (the user, 2026-11-06: "Go for it."): do the ports' members share keys, and how many
methods at traits would need `@open` under `bounded`? Registry rows: `writeup/record/experiments.md` E-263,
E-264. Nothing is timed.

## How to run

```sh
source env.sh
experiments/w105/census/run.sh forks    # Tables, DataFrames, CSV forks; TraitMakie, MakieCompat; Graphs, GraphMakie ports; BaseTraits
experiments/w105/census/run.sh nd       # NetworkDynamics port; TraitDifferentialEquations, ODECore, TraitArrayTools, TraitIndexing, TraitNonlinearSolve, TraitRodas
experiments/w105/census/run.sh tables   # TraitTables, TraitCSV, TraitReport
python3 experiments/w105/census/structs.py "$PWD" > experiments/w105/census/logs/structs.tsv
```

Each session is one Julia job through `experiments/tools/jl` on julia-1.13 00dcc9994c with TraitWorld 33dd55e
(forks 77b9aab, TraitMakie ba46982, TDE e9e07ed, ndport 65ac255). Outputs: `logs/<session>.log` (the summary),
`logs/<session>-keys.tsv` (one row per membership), `logs/<session>-methods.tsv` (one row per method at a trait),
`logs/structs.tsv`. Not loaded in any session: TDE's `TraitImplicit`, `TraitLinSolvers`, `TraitNLSolvers`.

## Method

**E-263, keys.** Every membership TraitWorld records in the session's ports: the methods of `implementation`
(declared) and of `projection` (forwarding, field mappings). For each concrete member, its key by TraitWorld's own
`_key_and_slots`, which is the draft's key (traits §7.2): the receiver (the member itself where it serves an
operation by its own methods; the forwarding field's type where it forwards; none where defaults serve every
operation) and the declared fields' types. A family's members each have their own key unless the family forwards
or has no receiver. No family forwards: `by` appears in the ports only in TraitMakie's four concrete `Live`
memberships (`grep '@implement.* by '`); the six families with a projection record map declared fields.

**E-264, `@open`.** Every method with a trait position in the ports' modules (TraitWorld's workers), found by
walking the method table. Not counted: the operations' own methods (the trait's method per operation, 118) and
TraitWorld's machinery generated into users' modules (`_tgetprop`, `_tsetprop!`, 37). Each method is inferred at
archetypes (E-258's construction, with a trait parameter left open as `ParamOpen`, 73 methods). A method is
**open** under the draft (traits §7.3) when:
- TraitWorld's definition checker names a problem (an undeclared field, a call of a function not known when
  compiled, a call of an ordinary function with the argument); or
- a value's type is built from the argument's type outside TraitWorld's machinery: a struct parameter set from it,
  a closure capturing it, `typeof(keep(x))` (TraitWorld's `keep` is a `Kept`; the draft's is the value itself where
  compiled per key). `Kept{X}`, a slot typed by the trait, counts as the draft's `X`.

Public: the function's name exported or public in its own module (Base's functions are public). Structs with a
parameter bounded by a trait come from the sources (`structs.py`): TraitWorld erases such a bound to `Any`.

**Approximations.**
- A method is a worker: a source method with default arguments counts once per arity (`_enter_callback!` three
  times). 17 open methods are 13 functions.
- The checker's rule and the draft's differ at the edges; `addtype!` (`push!(types::Vector{CSVColumn}, c)`) is open
  by the checker's "an ordinary function" though it stores into a container typed by the trait.
- Public is per module: `ODEProblem` is internal to ODECore's file but exported by TraitDifferentialEquations.
- Three methods are not checked: `byrow` twice (a `Callable` position), `_object_of` (no trait position).

## Results (2026-11-06)

**E-263: 4 of 148 memberships share a key with another member (2.7 %).**

| Session | Memberships | Concrete | Families | Receiver not the member itself | Keys with two members or more |
|---|---|---|---|---|---|
| forks (BaseTraits 43, TraitMakie 28, CSV 5, Tables 2, DataFrames 2, Graphs 1, MakieCompat 1) | 82 | 41 | 41 | 4 (TraitMakie's `Live{…} by val`) | 2 (4 members) |
| nd (ODECore 32, NetworkDynamics 9, TraitNonlinearSolve 9, TraitRodas 6, TraitArrayTools 1, TraitIndexing 1) | 58 | 7 | 51 | 0 | 0 |
| tables (TraitCSV 5, TraitReport 2, TraitTables 1) | 8 | 7 | 1 | 1 (TraitReport's `Job`, fields only) | 0 |
| **all** | **148** | **55** | **93** | **5** | **2 (4 members)** |

The two shared keys each pair a wrapper with what it wraps: `Live{Matrix{Float64}}` with `Matrix{Float64}` as
`Positions`, and `Live{Vector{NTuple{2,Float64}}}` with `Vector{NTuple{2,Float64}}`. Every other member serves
its operations by its own methods, so it is its own key: code per key is code per type.

**E-264: 3 of 52 public methods at traits are open; 14 of 77 internal ones.**

| Port | Methods | Public: bounded / open / unchecked | Internal: bounded / open / unchecked |
|---|---|---|---|
| BaseTraits | 3 | 2 / 0 / 0 | 0 / 0 / 1 |
| CSV fork | 4 | 3 / 0 / 0 | 1 / 0 / 0 |
| DataFrames fork | 26 | 9 / 1 / 0 | 16 / 0 / 0 |
| Tables fork | 3 | 1 / 0 / 2 | 0 / 0 / 0 |
| TraitMakie | 25 | 12 / 0 / 0 | 13 / 0 / 0 |
| NetworkDynamics port | 11 | 2 / 0 / 0 | 8 / 1 / 0 |
| ODECore | 23 | 5 / 1 / 0 | 9 / 8 / 0 |
| TraitArrayTools | 1 | 1 / 0 / 0 | 0 / 0 / 0 |
| TraitIndexing | 9 | 4 / 0 / 0 | 5 / 0 / 0 |
| TraitNonlinearSolve | 10 | 0 / 0 / 0 | 7 / 3 / 0 |
| TraitCSV | 2 | 0 / 1 / 0 | 1 / 0 / 0 |
| TraitReport | 3 | 3 / 0 / 0 | 0 / 0 / 0 |
| TraitTables | 9 | 5 / 0 / 0 | 2 / 2 / 0 |
| **all** | **129** | **47 / 3 / 2** | **62 / 14 / 1** |

The open ones, by what opens them:
- **A struct built with the argument's type** (the draft's `Problem{typeof(k)}` idiom): `core_problem` (public),
  `_steady`, `nl_core`.
- **A closure capturing the argument:** `refine!` (public), `check_feedforward_leaves`, `sortperm_col`, `take`.
- **A function not known when compiled:** `_enter_callback!`, `_enter_step_callback!` (three arities each),
  `with_problem`, `nl_with_problem`.
- **An undeclared field:** `_sync_in!`.
- **`push!` into a container typed by the trait:** `addtype!` (public).

**Structs with a parameter bounded by a trait: 11** (`structs.tsv`): BaseTraits' `IndexableVector`; DataFrames'
`CellVector`; ODECore's `CoreProblem`, `Newton`, `ODEProblem`; TraitNonlinearSolve's `NLCoreProblem`,
`NewtonRaphson`, `NonlinearProblem`, `TrustRegion`; TraitRodas' `DualJacobian`, `Rodas5`. Julia generates each
one's default constructor, which sets the parameter from the argument's type: an open method under the draft's
rule.

## What it means

- **E-263: below the registered threshold (a tenth).** In the ports, a key is shared only between a forwarding
  wrapper and what it wraps. Code compiled once (`Dynamic`) and code per type serve every other case.
- **E-264: below the registered threshold (a quarter of the public methods).** `bounded` by default with `@open`
  needs 13 functions marked (3 public), and the exported-only rule 3. The 11 structs' default constructors are
  open by the draft's own idiom (traits §8.2): the draft must say `bounded` does not refuse them.
