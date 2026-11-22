# W-143c: the census of Base's surface on the head (E-535)

W-143's first step ([the work queue](../../../writeup/record/todo.md)): `../w157/census.jl` on the freeze's heads. Which places below a port's code compiled by facts keep that code out of the deep class today, by kind and by name, largest first. Open issues 179, 181, 218, 219 and GT-8 in [the open issues](../../../writeup/open-issues.md). The tool is W-157's ([`../w157/README.md`](../w157/README.md)), copied here and adapted where the head's records differ. `../w143/` holds an earlier proxy of the item (the session's fully typed report over twelve broad types, E-368); it is not changed.

## The registry's row (E-535), written before the run

- **The question.** On the freeze's head (`next` cf0f039f51, TraitWorld `unified` a5ec7f0, the forks a3a37d6), which places below a port's code compiled by facts keep that code out of the deep class (the G2 bit, compiler §3.2)? In three sessions: the forks' CSV and DataFrames work; upstream CSV and DataFrames compiled by facts (the round's copies, `../w159/pkgs-facts-head`); the ODE port (TraitDifferentialEquations, Lorenz with Tsit5 and Robertson with Rodas5), a port that is not a table. Per session: the own facts instances in the class, of how many; the culprits (an instance outside the class by a fault of its own) by kind and by method name, with what fixing each buys alone and in the greedy order. For the ten largest culprits: the fault read up close, and its class: (i) a patch to Base that stands without traits, (ii) a rule's matter (open issue 218 or 219), (iii) dynamic by purpose (`show`, the REPL, loading), (iv) the library's or a port's own code.
- **The baseline.** The deep class is a count that plain Julia does not have; the plain baseline of each candidate is that it stands as a patch on vanilla v1.13.2 without traits (compiler §11), stated per candidate and not built here. E-478's last numbers (`next-s3` bc844be7c0: the forks 63.1 %, upstream by facts 79.0 % of own facts instances in the class) are a regression control, not a baseline.
- **What would change the design or the list of patches.**
  - A culprit that carries a point or more alone and is Base's plain code fixable without traits: a patch for the list of W-19 (`w143c/patches/`, not applied).
  - A share held by one rule's pattern (stores into a container of `Any`, open issue 218 (b); a query that names the matched instance, 219): that proposal moves from the synthesis to a decision for the user.
  - The library's own code among the largest culprits: a fix in the library, not in Base.
  - A share on the head below E-478's on the same packages: a regression since `next-s3`, to be traced to its commit.
- **The setting.** Product setting, strict mode off, one thread, one fresh process per session; no build of Julia; a depot of this item's own (`.julia-depot/agent-depots/w143` in front of the shared one); the machine's load before and after in each log.

## How to run

```sh
source env.sh                                    # the workspace's env.sh; depot agent-depots/w143 before the shared one
# the images, once after a rebuild of Julia (no Pkg operation: `using` precompiles what it loads)
$JN --project=envs/forks -e 'using CSV, DataFrames'; $JN --project=envs/facts -e 'using CSV, DataFrames'
$JN --project=envs/demo -e 'using TraitWorld, TraitDifferentialEquations'
bash run.sh <label> forks|facts|ode census.jl            # the census -> logs/<label>-<session>.log and .tsv; 1 to 2 minutes
bash run.sh <label> forks diag/culprit.jl Base.typejoin …  # culprits up close: faults, a path of callers, direct callers
KEYS=TypeVar,UnionAll OPT=0 bash run.sh <label> forks diag/code_of.jl Base.collect '_norm_eq##2'   # the statements behind a fault
```

- **The environments** (`envs/`) are copies of the round's head settings (`../w159/envs/H/{forks,facts,demo}`, made by `../w159/mkenv.py`): the forks and TraitWorld at their heads; upstream CSV and DataFrames compiled by facts from `../w159/pkgs-facts-head` (the head's one line `@compiler_options facts=true bounded=false no_pirates=false`, owner-only off); the demonstrators' environment for the ODE port.
- **The sessions.** `forks` and `facts`: E-392's table work (`CSV.read`, `describe`, `sort`, `combine` of a `groupby`) twice, on `experiments/interfaces/App/data/sample.csv`. `ode`: Lorenz with `Tsit5` and Robertson with `Rodas5`, `../w135/apps/ode.jl`'s `main` without its printing, twice. The own modules: the eight table packages (W-157's list); for the ODE port TraitDifferentialEquations and its eight packages under `lib/`. The library TraitWorld is not counted as own; its instances below the own code are reached and judged as any other.

## The tool's changes against W-157's copy

- **What is the same.** The bits' masks (`JL_CI_FLAGS_G2` 0x10, `JL_CI_FLAGS_FACTS` 0x20) and the edges' forms (`CallSigBackedge`, a binding, a membership's instance, an absence signature) are the head's as they were on `next-s3`. The test of a dispatch edge is the compiler's own `is_fact_sig`, so owner-only functions (and the open-operation flag) are facts in the census exactly where they are in the build; a membership's instance and an absence signature are read with the compiler's `is_membership_mi` and `is_absence_sig`.
- **The own modules and the work** are chosen by `CENSUS_OWN` and `CENSUS_WORK` (`table`, `ode`): the ODE port is a third session.
- **A callee named by its MethodInstance whose code names the caller back** is a member of the caller's inference cycle, which the predicate judges as one (`is_own`): no fault of its own. W-157's copy counted it as a callee named by instance alone.
- **The replay's check:** instances with the bit that have a fault of their own. 0 in each session, and no instance without the bit lacks both a fault of its own and a callee without the bit: the replay agrees with the bit.
- **Owner-only edges:** the dispatch edges that are facts only as calls of an owner-only function, counted.
- **The candidates' groups** (new): each fault is put in the first group whose predicate it meets, by the fix it stands for: the compiler's record (`TypeVar` and `UnionAll` inferred at `(Any, Any)`; a top-level union whose splits are facts), lowering (a keyword body `#f#N` called at an abstract argument), Base (a type's field read by `getproperty` at a kind), open issue 218's patterns (a tuple with an abstract element indexed; a store into a container of `Any`; the task code; any other call at a kind; any other call of Base's at an abstract argument), open issue 219 (a callee named by instance), and the rest (another module's function: the port's, the library's, the compiler's). Per group: alone, needed (the own facts instances that stay out with every other group fixed), and the greedy order.
- **The TSV** names each method's root module. `diag/code_of.jl` (new) prints the statements of a culprit's code that carry its faults.

## Results

### E-535 (2026-11-22): the census on the freeze's head

`next` cf0f039f51 (the binary names `cf0f039f51*`: its tree had a tracked change when it was built and is clean now), TraitWorld `unified` a5ec7f0, the forks a3a37d6, TraitDifferentialEquations 06c28c3, experiments 49b09e5; product setting, strict mode off, one thread, one fresh process per session; load 2.7 to 13.7 of 128 (others' jobs). The counts do not depend on the load; two runs of each census gave the same counts. `logs/e535-{forks,facts,ode}.log` and `.tsv`; up close `logs/e535-culprits-{forks,ode}.log`, `logs/e535-code-collect-forks.log`.

| | the forks | upstream by facts | the ODE port |
|---|---|---|---|
| own facts instances in the class | 2,764 of 4,315 (64.1 %) | 2,818 of 3,567 (79.0 %) | 523 of 717 (72.9 %) |
| own image instances in the class | 3,955 of 5,704 (69.3 %) | 2,774 of 3,490 (79.5 %) | 516 of 692 (74.6 %) |
| made by the work, in the class | 8 of 12 | 44 of 77 | 7 of 25 |
| culprits (a fault of their own); method names | 1,509; 383 | 921; 259 | 174; 76 |
| culprits in a cone: median, most | 12, 410 | 19, 177 | 3, 64 |
| outside the class below the own facts instances, outside the own modules (the copies P3's demand rule would make) | 2,252 | 1,772 | 504 |
| dispatch edges that are facts only as calls of an owner-only function (own facts instances) | 2,036 | 0 (owner-only off) | 202 |

**The regression control** (E-478, `next-s3` bc844be7c0, TraitWorld-s3, forks 439bae7): the forks 63.1 % (2,654 of 4,204) there, 64.1 % here; upstream by facts 79.0 % (2,818 of 3,567) there and here, the same counts; own image instances 68.9 % and 79.5 % there. No regression. The forks' and the library's trees differ between the two, so the forks' point is not attributed.

**The candidates' groups** (own facts instances in the class: with the group alone; needed, i.e. that stay out with every other group fixed):

| group (the fix it stands for) | the forks: alone; needed | upstream: alone; needed | ODE: alone; needed |
|---|---|---|---|
| record: `TypeVar`, `UnionAll` inferred at `(Any, Any)` | 64.1 %; 835 | 79.8 %; 512 | 73.4 %; 33 |
| record: a top-level union whose splits are facts (`!==` at `Union{Nothing, Int64}`) | 64.1 %; 358 | 79.0 %; 212 | 72.9 %; 7 |
| lowering: a keyword body `#f#N` called at an abstract argument | 64.1 %; 1,056 | 79.0 %; 417 | 72.9 %; 0 |
| Base: a type's field read by `getproperty` at a kind | 64.1 %; 699 | 79.0 %; 433 | **79.4 %**; 146 |
| 218: a tuple with an abstract element, indexed | 65.3 %; 856 | 79.1 %; 474 | 74.6 %; 58 |
| 218 (b): a store into a container of `Any` | 64.3 %; 1,257 | 79.3 %; 611 | 72.9 %; 42 |
| 218: the task code (a payload typed `Any`) | 64.1 %; 1,000 | 79.0 %; 329 | 72.9 %; 0 |
| 219: a callee named by instance (`hasmethod`) | 64.9 %; 500 | 79.4 %; 265 | 73.6 %; 86 |
| 218: any other call with a kind among its arguments | 65.1 %; 918 | 79.2 %; 520 | 72.9 %; 46 |
| 218: any other call of Base's at an abstract argument | 64.2 %; 886 | 79.1 %; 545 | 72.9 %; 44 |
| another module's function at an abstract argument (the port's, the library's, the compiler's) | 64.6 %; 545 | 79.1 %; 247 | 75.5 %; 83 |

- No group buys more than 1.2 points alone in the tables' sessions: the cones are wide (a median of 12 and 19 culprits). In the ODE port, reading a type's flags by `getproperty` buys 6.4 points alone (`isbitstype`, `isconcretetype`).
- Every group is needed by hundreds of the tables' own instances: no group can be left out. The largest needs are the stores into containers of `Any` (1,257 of the forks' 1,551 outside), the keyword bodies (1,056) and the task code (1,000: DataFrames' threaded paths).
- The greedy order of groups (the forks): tuples 65.3 %, kinds 66.3 %, the ports' own 67.4 %, Base at abstract 68.5 %, 219 69.4 %, stores 70.5 %, `TypeVar` 71.0 %, `getproperty` at kinds 74.3 %, the union 75.5 %, keyword bodies 76.8 %, the task code 100 %. Upstream: `TypeVar` 79.8 %, …, 90.8 % before the task code. ODE: `getproperty` at kinds 79.4 %, the port's own 83.4 %, 219 86.2 %, tuples 90.7 %, `TypeVar` 93.6 %, … stores 99.0 %.

**By method name, greedy** (each on top of the ones before): the forks 64.1 %; `Iterators.iterate` 64.9 %; `hasmethod` 65.7 %; `_iterate_dict` 66.1 %; `iterate` 66.7 %; then less than 0.3 point each; 68.6 % after 25. Upstream 79.0 %; `collect` 79.6 %; …; `schedule` +1.4, `typejoin_union_tuple` +2.9, `sync_end` +1.9 late in the order; 87.6 % after 25. ODE 72.9 %; `isbitstype` 79.4 %; `ODECore._problem` 82.1 %; `iterate` 83.8 %; `ODECore.solve_ode` 87.0 %; `collect` 90.0 %; `hasmethod` 91.6 %; 98.2 % after 25.

**Who owns the culprits** (culprit instances by the method's root module): the forks Base 1,266, the forks' own modules 142 (Tables 55, DataFrames 33, CSV 24, Parsers 12, PooledArrays 9, others 9), Statistics 48, Core 25; upstream Base 858, own 8, Core 17, Statistics 16; ODE Base 139, the port's own 20 (ODECore 17, TraitRodas 3), the compiler's 6 (`declared_field_type`, `declared_field_in`, reached from the library's `_dynamic_field_type`). Show and print paths (dynamic by purpose): 155, 99 and 27 culprit instances.

### The ten largest, read up close

Cones: own facts instances whose cone holds the culprit instance named (or, where the row names a method, any of its culprit instances), the forks; upstream; ODE; – where it is not among the session's culprits. The class: (i) a patch to Base that stands without traits; (ii) a rule's matter (open issue 218 or 219); (iii) dynamic by purpose; (iv) the library's or a port's own code. Two are neither of these: a fault in how the compiler records an edge.

| # | culprit, and its fault | cones | class |
|---|---|---|---|
| 1 | the task code: `notify(::GenericCondition, ::Any, ::Bool, ::Bool)` calls `schedule(t, arg; error)` at `Any`, whose keyword forwarder calls the body `#schedule#610` at `Any`; `close(::Channel{Any}, ::Exception)` stores `c.excp` by `setproperty!`; `notify_error` passes an `Exception`; `sync_end` pushes onto a `CompositeException` | 1,000; 329; 0 | (i) in part: `close`'s store by `setfield!` and `notify_error` through `invoke` (`patches/04`, 2 lines); the keyword body: lowering's matter (below); the payload typed `Any`: (ii) 218 |
| 2 | `push!(::Vector{Any}, ::Any)` → `__safe_setindex!(::Vector{Any}, ::Any, ::Int)` | 877; 319; 7 (`push!` at a container of `Any`) | (ii) 218 (b) |
| 3 | `typejoin(::Any, ::Any)`: `Type.body.name` read by `getproperty`; `c[i] = …` into a `Vector{Any}` | 776; 425; 8 | (i) the read (`patches/02`, 1 line); the store (ii) 218 (b) |
| 4 | `collect` of a generator: inference matches `TypeVar(…)` and `UnionAll(…)` at `(Any, Any)` and keeps that as the edge, as it did for `!==` before row s3-8; the call's own types are `TypeVar(::Symbol, ::Type{Char})` (`logs/e535-code-collect-forks.log`) | 484; 292; 22 | the compiler's record (compiler §3.1): match at the call's own signature, as row s3-8 does for `!==` |
| 5 | `typejoin_union_tuple(::DataType)`, `promote_typejoin_union(::Type)`: `getproperty` at `DataType`, `Union`, `Type`; `unwrapva`, `isvarargtype` at `Any` | 483; 291; – | (i) what `up/03` left (`patches/02`, 16 lines) |
| 6 | an abstract `Vector`: `length(::Vector)` → `size(::Vector)`; `Vector{T}(undef, n)` at a computed `T`; `similar(::Vector, ::Type)` (from CSV's column allocation, `Tables.allocatecolumn`, PooledArrays' `_invert`) | 429; 135; – | (ii) 218 (an element type not inferred); the callers (iv) |
| 7 | `in(::Char, ::String)`: the edge of `!==` keeps the call's signature `(Union{Nothing, Int64}, Nothing)` unsplit, which is no fact; each split is | 334; 193; 7 | the compiler's record (compiler §1.2: a top-level union is split, each split a fact) |
| 8 | a tuple with an abstract element, indexed: `iterate(::Enumerate{Vector{AbstractVector}})` reads `n[1]`; `indexed_iterate(::Tuple{Any, Any}, ::Int)`; `iterate(::CyclePadding)` reads `y[1]` of an `svec`'s iteration | 236; 194; 50 | (ii) 218; where Base reads its own tuple, (i) by `getfield` (`patches/03`: `CyclePadding`, 9 lines) |
| 9 | `hasmethod(f, Tuple{…})` folded with an edge to the matched instance: DataFrames' `groupreduce_init`, `_stats`; in the ODE port the box's test at `Callable` (23 instances: closures, `lorenz!`, `robertson!`). Alone +32, +7, +5; the group of callees named by instance is needed by 500, 265, 86 | 42; 7; 33 | (ii) 219 |
| 10 | `isbitstype(::Type{X})`, `isconcretetype(::Type{X})`: `t.flags` read by `getproperty(::DataType, ::Symbol)` (reached from `unsafe_copyto!` of a `Memory` of the port's callback records) | 141 and 81; 12 and 82; 120 and 34 | (i) `patches/01` (6 lines): as `up/02` has the introspection helpers do; 6.4 points of the ODE port alone |

- **(iii), dynamic by purpose:** the show and print paths (`print_to_string`, `show_unquoted`, `with_output_color`, `escape_string`, `merge` of an annotation's `NamedTuple` reached from `repr`): 155, 99 and 27 culprit instances, the largest cone 334 (the forks). Recorded, not patched.
- **(iv), the ports' and the library's own code:** in the forks Tables 55, DataFrames 33, CSV 24 culprit instances (a call at a computed type, an abstract column). In the ODE port: `ODECore._problem` calls `_names` at a union of kept forms (`Union{Compiled{<:IndexProvider{K}}, Dynamic{<:IndexProvider{K}}}`); `ODECore.solve_ode` names `param_integrator` by instance (it had no code when the caller finished); `TraitRodas.rodas5_start`, `rodas5_initdt!`, `dual_jacobian` call at `where` types; the library's `_dynamic_field_type` calls the compiler's `declared_field_type` at a type typed `Any` (6 culprits, 27 cones).
- **Lowering's matter, new:** a keyword method's forwarder calls the body that lowering makes (`#schedule#610`) at the forwarder's argument types. No other module defines a method of that body (a keyword method elsewhere gets a body of its own), so the body is owner-only by its making; the rule does not say so. 106 of the forks' culprits have such a fault; the group is needed by 1,056 of their own instances.

### The candidates, in order (not built)

| # | candidate | kind | size | what it buys (own facts instances; alone, needed) | file |
|---|---|---|---|---|---|
| 1 | `isbitstype`, `isconcretetype`, `isdispatchtuple`, `isprimitivetype` and two `datatype_*` helpers read `flags` with `getfield` | Base, stands without traits | 6 lines, `base/runtime_internals.jl` | ODE +46 alone (6.4 points); the `getproperty`-at-a-kind group needed by 699, 433, 146 | `patches/01-introspection-flags-getfield.diff` |
| 2 | `TypeVar(…)` and `UnionAll(…)` matched at the call's own signature, kept in the edge (as row s3-8 for `!==`) | compiler, the record | a few lines, `abstractinterpretation.jl` | upstream +27 alone; needed by 835, 512, 33 | — |
| 3 | a top-level union of concrete types whose splits are facts is a fact signature (the edge of `!==` at `Union{Nothing, Int64}`) | compiler, §1.2 | a few lines, `facts.jl` | needed by 358, 212, 7 | — |
| 4 | the type joins `up/03` left: `typejoin`'s `Type.body.name`, `typejoin_union_tuple`, `promote_typejoin_union` by `getfield` and `invoke` | Base, stands without traits | 18 lines, `base/promotion.jl` | part of groups 4 and 9 | `patches/02-typejoin-union-tuple-getfield-invoke.diff` |
| 5 | `CyclePadding`'s iteration reads its tuples with `getfield` | Base, stands without traits (`up/01`'s family) | 9 lines, `base/reinterpretarray.jl` | ODE: `iterate(::CyclePadding)` in 50 cones | `patches/03-cyclepadding-getfield.diff` |
| 6 | the task code: `close` stores the exception by `setfield!`; `notify_error` calls `notify` through `invoke` | Base, stands without traits (`up/05`'s family) | 4 lines, `base/channels.jl`, `base/condition.jl` | part of the task group (1,000; 329); `notify`'s keyword call of `schedule` at `Any` stays | `patches/04-task-payload.diff` |
| 7 | a keyword body made by lowering is owner-only | lowering, facts §3 | the flag set where lowering makes the body | needed by 1,056, 417, 0 | — |
| 8 | open issue 218 (b): a store's value position into a container of `Any` | a rule | — | needed by 1,257, 611, 42 | — |
| 9 | open issue 219 (a): an edge "dispatch at an instance" | a rule | — | needed by 500, 265, 86 | — |

The diffs are against `julia-next` cf0f039f51 and are applied to no tree. Patch 02 leaves the calls of `promote_typejoin_union` at `Any` (a call that has no method there would raise a different error through `invoke`). None is built or tested.
