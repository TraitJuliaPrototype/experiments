# E-253 (U5): the coherence rule's cost

The question (registry row E-253; exploration `writeup/explorations/abstract-types-as-traits.md` §11.1, §11.2 C3/C4, §11.5, §14.4): how often do the demonstrators and the four ports bound a foreign function by a set that has foreign members? For each such hit: does a typed method of the function shield every foreign member?

**Would change the plan:** zero or a handful of hits, each with an own-function spelling or a shield: the rule costs nothing in practice, and the recommendation stands. Many unshielded hits, or `Base.show` everywhere: the mode's default and the static check's severity are weighed again.

## The answer

**Zero hits in every code base.** Of 131 bounded methods, none is on a foreign function, and none is defined in a package extension. The recommendation (C4 with C3 as its static face) stands on this evidence.

Two qualifications:

- **The zero is partly built in.** Today's lowering lets only a function's owner add a bounded method of a new shape (lowering L-3). The code bases were written under that limit, so the census counts what was built, not what was wanted. The two wishes on record, checked against the census:
  - **CommonSolve's `solve` (W-36, exploration §14).** A bounded `solve(prob::ODEProblemTrait, alg::ODEAlgorithm)` by TDE would be allowed under C3: both sets are members by owner (ODEProblemTrait 1 member, ODEAlgorithm 5 members, every one declared in its own package, TraitRodas' included). So are `NonlinearProblemTrait` and `NonlinearAlgorithm`. This confirms §14.4 for the front end.
  - **`Base.show` on a trait.** Asked hypothetically for every open set (`*-hypo-show.tsv`): Base's typed `show(::IO, ::T)` methods shield every foreign member of every open set except two: `LinearAlgebra.Factorization` in BaseTraits' `Solvable`, and `IO` in the CSV fork's `CSVSource`. (BaseTraits' integer union is shielded piecewise by `show(::IO, ::Signed)` and `show(::IO, ::Unsigned)`; the script reports it unshielded because it asks for one method over the whole union.) So a `Base.show` on an open set over Base's types is harmless. It is also dead code for those members, since the typed method wins.
- **The terms need two refinements to fit the code** (see "Findings for the exploration").

## Results (2026-10-29)

Build: julia-1.13 `00dcc9994c`; TraitWorld `33dd55e`; TraitTables `438ac2b`; TraitCSV `9c6477b`; TDE `w34` `e9e07ed`; TraitMakie `c0d5c36`; forks `943b065`; ndport `a5bdc75` (NetworkDynamics `ports` `dfc6663`, GraphMakie `ports` `498be7c`, Graphs `port` `54632125`). Product setting, strict mode off, one session per code base, `jl` slot depot `w83u5`. Not a measurement: counts read from TraitWorld's registries after loading.

Per code base (from `logs/summary.txt`). A set belongs to the package that declares it. Its members are counted in the session where it has the most (TDE's sets in `tde`, where the three solver packages outside `env_r5` are loaded).

| code base | sets | members by owner (strict / refined) | open (strict / refined) | bounded methods | of them bounded by an open set (own functions) | on a foreign function or in an extension | hits | unshielded |
|---|---|---|---|---|---|---|---|---|
| BaseTraits (in TraitWorld) | 9 | 1 / 1 | 8 / 8 | 2 | 2 | 0 | 0 | 0 |
| TraitTables | 1 | 0 / 0 | 1 / 1 | 9 | 9 | 0 | 0 | 0 |
| TraitCSV (with its InlineStrings extension) | 1 | 0 / 0 | 1 / 1 | 2 | 2 | 0 | 0 | 0 |
| TDE (`w34`: ODECore and the seven split packages) | 24 | 24 / 24 | 0 / 0 | 45 | 0 | 0 | 0 | 0 |
| TraitMakie, MakieCompat, MakieCompatStats | 7 | 1 / 2 | 6 / 5 | 25 | 24 | 0 | 0 | 0 |
| the forks (CSV, DataFrames, Tables) | 6 | 0 / 0 | 6 / 6 | 33 | 33 | 0 | 0 | 0 |
| NetworkDynamics on the ports (ND, Graphs) | 4 | 0 / 4 | 4 / 0 | 11 | 9 | 0 | 0 | 0 |
| **all** | **52** | **26 / 31** | **26 / 21** | **127** | | **0** | **0** | **0** |
| TraitWorld's internal workload modules (`_PC`, `_PCF`) | 2 | 1 / 1 | 1 / 1 | 4 | 3 | 0 | 0 | 0 |

- `summary.txt` counts BaseTraits' `HasProperty` twice (the trait and its family `HasProperty{:ps}`, whose one member is ODECore's `ParamIntegrator`). The table counts it once.
- **Strict:** a membership is the owner's only if the declaring package owns the member's outer type name. Joint owners count. Extensions never count.
- **Refined:** two more kinds count as the owner's. Both put the declaring package in every caller's dependency tree:
  - `by_owner_param`: owned through a type parameter. TraitMakie's `Vector{ColorName}` and `Vector{MarkerName}` are owned by TraitMakie under ownership rule 3. These two are counted as the owner's in both columns.
  - `generic_own_ub`: a generic implementation `@implement X A where {A <: S}` over the declarer's own abstract type `S`. Examples: NetworkDynamics' `FunctionDynamics`, Graphs' `AbstractGraph`, MakieCompat's `OldAPI.Plot` (a joint owner of TraitMakie), and BaseTraits' own `CompiledItems`/`DynamicItems`.
- **Bounded methods:** 127 in the code bases, 131 with TraitWorld's internal workload. Every one is on a function its own package owns. The Callable positions (Tables' `byrow`, TraitWorld's `pcmap`) are not sets with declared members, and none is on a foreign function either.
- **Memberships by kind** (`logs/*.log`, `*-members.tsv`):
  - Open sets are open because they adopt Base's types: BaseTraits' containers, columns as Base vectors, Makie's attribute values (`NTuple{4, Float64}`, `typeof(log10)`).
  - Memberships in extensions: TraitCSV's `String15` column; the CSV fork's 18 `InlineString` columns; Tables' `PooledVector`, and a `CategoricalVector` in an extension whose trigger is not in `env_forks`, so it was not loaded. It joins an open set already.
  - TDE's 24 sets have only memberships by owner.
- **The self-test** (`selftest.jl`, `logs/selftest.log`) checks the detector and the shield check on a planted case. `U5B` adds `U5A.ga(x::XB)` for its set `XB`, with the foreign members `Float64` and `String`. The census finds the hit. It names `U5A`'s typed `ga(::AbstractFloat)` as the shield for `Float64` and reports `String` unshielded. Its joint method `ga(x::(XA, XB))` is reported for both bounds.

## Findings for the exploration

1. **No code base needs the forbidden combination.** The ports bound their own functions, by their own capability sets or by BaseTraits'. This is the pattern §11.2 C3 read from the sources ("bound their own functions"). The census confirms it for all 127 methods. Because of L-3, the census cannot show demand that L-3 suppressed. The known demand is W-36's `solve`, and C3 allows it (finding above).
2. **"Members by owner" should be read through ownership rule 3 and through the declarer's own abstract types.** As the task defines it, a generic implementation over a type the declarer does not own makes a set open. That reading calls ND's `ComponentDynamics`/`VertexDynamics`/`EdgeDynamics`, Graphs' `GraphInterface` and TraitMakie's `Plot` open.
   - Under §11.1's own argument they are members by owner. A type `T <: S` is declared in `T`'s package, which depends on `S`'s package, which holds the generic implementation. So the membership is in every caller's tree.
   - In C4's terms: `T` consented to `S`, and `S`'s owner put `S` in `X`. Consent is transitive through a generic implementation by `S`'s owner in `S`'s package.
   - The same holds for a member owned through a parameter (`Vector{ColorName}`): ownership rule 3 already gives it to the declarer.
   - With both readings, the ports' domain sets are all members by owner: TDE 24 of 24, ND 4 of 4. The open sets are exactly the sets that adopt Base's types: 21 of 52.
3. **What default fits.**
   - With `open` as `@trait`'s default (today's), no existing set needs a declaration. No existing method is refused, because none is on a foreign function.
   - With members by owner as the default, the 21 open sets would each need `open`. That is every set that adopts Base's types: 8 in BaseTraits, the tables and columns (TraitTables, TraitCSV, the forks), and 5 of TraitMakie's 7.
   - The 31 sets that are members by owner are domain sets: problems, algorithms, dynamics, graphs, plots. They have the shape of abstract types. This fits C3's split: members by owner for `abstract type`, open for `@trait`.
4. **The static check's severity (§14.4):** there is no case here to weigh. No hit exists, shielded or not. The hypothetical `Base.show` shows the shape §14.4 predicted for SciMLOperators: refused by C3, yet shielded by typed methods for nearly all members. So the evidence supports §14.4's proposal: a warning in trait modules, and strict mode's refusal where a definition would win.

## How to run

From the design repository's root, one Julia job per code base (offline; `JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1`; `J="experiments/tools/jl --name w83u5 julia-1.13/julia --startup-file=no"`, `C=experiments/w83/u5/census.jl`):

```
$J --project=TraitWorld $C tw
U5_SELFTEST=1 $J --project=TraitWorld $C selftest
$J --project=experiments/w83/u5/env_tables $C tables TraitTables TraitCSV InlineStrings
$J --project=experiments/w83/u5/env_tde $C tde TraitDifferentialEquations ODECore TraitArrayTools TraitIndexing TraitRodas TraitNonlinearSolve TraitImplicit TraitLinSolvers TraitNLSolvers
$J --project=experiments/w83/u5/env_makie $C makie TraitMakie MakieCompat MakieCompatStats
$J --project=forks/env_forks $C forks Tables DataFrames CSV InlineStrings PooledArrays
$J --project=ndport/env_r5 $C ndport NetworkDynamics GraphMakie Graphs NetworkLayout Observables Static SymbolicIndexingInterface MakieCompat TraitMakie TraitDifferentialEquations ODECore TraitArrayTools TraitIndexing TraitNonlinearSolve TraitRodas
python3 experiments/w83/u5/summary.py
```

Each run prints a report to stdout (`logs/<label>.log`) and writes, beside the script:

- `<label>-sets.tsv`: each set's mode, strict and refined;
- `<label>-members.tsv`: every membership with its kind and declaring module;
- `<label>-bounded.tsv`: every bounded method, its function's owner, its bounds;
- `<label>-hits.tsv`: the combination, with unshielded members and the shields;
- `<label>-hypo-show.tsv`: the hypothetical `Base.show` per open set.

The scratch environments `env_tables`, `env_tde` (TDE with all eight split packages; three of them are in no other environment) and `env_makie` point at the repositories by `[sources]`. `ndport/env_r5` is setting PT's environment (ndport README); the run took the package sources from `~/.julia` and compiled into the slot depot, not `depot-ports`.

**What the script reads** (TraitWorld `33dd55e`):

- **Memberships:** the methods of `TraitWorld.conformance(::As{X}, u::T)`, one per implementation, family or generic implementation, with the declaring module.
- **Bounded methods:** the methods with a `TObj` (or `CObj`) argument, the workers, of every function in a trait module's `__tw_entries__` or `__tw_extended__`. The bound is read with `TraitWorld._tobj_lb`.
- **Owners:** `TraitWorld.owner`, `owns` (joint owners) and `_extension_parent`.
- **Set membership** includes the members of subtraits (`trait_closure`).
- **A shield** is a typed method of the function (not a worker, an entry or a tagged fallback) whose signature covers the bounded method's signature at the member, and whose type at the bounded argument is not `Any`. This is types first (traits §5.5).
