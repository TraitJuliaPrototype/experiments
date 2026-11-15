# W-152: the probes for the review of 2026-11-15

Small runs that test proposals P2 to P7 of `writeup/reviews/2026-11-15-conceptual-design.md` (§4, §8). Each takes seconds to two minutes. Current numbers: `writeup/design/evidence.md` §1, "The review's probes". Registry: E-394 to E-400 in `writeup/record/experiments.md`. What they mean for each proposal: the review's second addendum.

## How to run

```
source ../../../env.sh; export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
J=../../../julia-unified/julia; E=../w134; CSV=../../interfaces/App/data/sample.csv
LOADS="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
$J --project=$E/env_lib   p4/late.jl $CSV lib|box                              # E-394
$J --project=$E/env_forks p3/deep.jl $CSV p3/logs/env_forks.jls $LOADS          # E-395 (a), (b); env_facts likewise
JULIA_COMPILE_BY_FACTS=1 $J --project=$E/env_forks p3/types.jl p3/logs/env_forks.jls   # E-395 (c), under the test bed
SITES_ROOTS=CSV,DataFrames,Tables $J --project=$E/env_forks p5/sites.jl CSV DataFrames  # E-396
AGREE_ROOTS=CSV,DataFrames,Tables $J --project=$E/env_forks p2/agree.jl CSV DataFrames  # E-397; p2/mistakes.jl is its control
$J --project=$E/env_demo  p7c/census.jl TraitWorld TraitCSV TraitTables TraitMakie TraitDifferentialEquations   # E-398
SPLIT_FIRST="$LOADS" $J --project=$E/env_forks p6/split.jl CSV DataFrames       # E-399
$J --project=$E/env_lib   p7b/case.jl                                            # E-400
```

The environments are W-134's (`../w134/env_*`). The `.jls` files that `deep.jl` writes for `types.jl` are not committed.

## Results (2026-11-15)

Build: `unified` 7b374f39ce, TraitWorld-unified e11c7cc, forks-unified 439bae7. Product setting but for E-395 (c); strict mode off; one thread; one process per row; load 0.3 to 0.8 of 128. The counts are of one run each; no time is claimed.

### E-394 (P4): a required operation as a method at an open set, against a method at the box alone

After upstream CSV's and DataFrames' work, compiled plainly (E-381's session). `p4/logs/late.log`.

| Added after the work | plain instances ended | the log |
|---|---|---|
| the library (`using TraitWorld`) | 201 of 120,335 | 548 entries |
| the same operations' methods at `Core.Dynamic` only (eleven methods of `length`, `iterate`, `getindex`, `firstindex`, `setindex!`, `push!`, `resize!`, `haskey`, `get`) | 0 of 120,335 | empty |

Every instance the library ends is ended by a required operation's method at an open set: by insertion `length(::HasLength)` 97, `iterate(::Iterable{T})` 59, `haskey(::Keyed{K, V}, ::Any)` 26; by the membership walk's replay `iterate(::Iterable{T}, ::Any)` 14, `resize!(::Resizable{T}, ::Any)` 5.

The probe measures what the methods cost plain code. It does not show that inference can read a declared result from the contract without the method.

### E-395 (P3): deep G2 on the nine loads

An instance is deep G2 when it has the G2 bit and so has every CodeInstance among its edges, transitively. An instance whose edges are bindings only counts as having the bit (below). E-392's session, order A. `p3/logs/deep.log`, `types-forks.log`.

| | the forks | upstream by facts |
|---|---|---|
| own image instances | 4,799 | 3,490 |
| with the G2 bit | 4,667 | 3,438 |
| deep G2 | 1,983 (41 %) | 1,382 (40 %) |
| own facts instances that are not deep G2 | 1,934 of 3,465 | 2,156 of 3,567 |
| ended by the nine loads (image code, and code the work made) | 49, 0 | 14, 5 |
| of those ended: deep G2 | 0 | 0 |
| of those ended: with the G2 bit | 40 | 15 |
| callees outside the own modules, below the own facts instances | 32,844 | 27,517 |
| of them deep G2, and ended | 26,336, 0 | 22,054, 0 |
| of them not deep G2, and ended | 6,508, 281 | 5,463, 109 |
| of them without the bit themselves (the culprits) | 1,596 in 385 method names | 1,167 in 316 |
| culprits under one own facts instance that is not deep, median | 10 | 6 |
| with calls that only throw taken as run-time sites: own image instances deep G2 | 2,917 (61 %) | 2,215 (63 %) |

- **No deep-G2 instance is ended** by an unrelated load, own or below, in either configuration. Every ended instance is not deep. The bit as built does not tell them apart: 40 of the forks' 49 carry it.
- **The culprits most own instances rest on:** `Core.throw_inexacterror(::Symbol, ::Type, ::T)` (five integer types), `DomainError(::Any, ::Any)`, `Base.typesplit`, `typejoin`, `promote_typejoin` and `_promote_typesubtract` at `Any`, `Val(::Int)`, `push!(::Vector{Any}, ::Any)`, the task code under a lock (`yieldto`, `wait`, `notify`, `Base._wait`), `Base.string_index_err`. By name, most often: `Base.Sort._sort!`, `iterate`, `similar`, `collect`, `mapreduce_impl`, `_compute_eltype`, `ntuple`, `print_to_string`.
- **(c) Types, the forks** (under the test bed, where a neutral method takes the policy of the code that reaches it): of 701 callees that an own facts instance calls directly and that are not deep G2, inference by facts all the way down gives the plain result type at 520 (74 %), a wider one at 130 (19 %; `Any` at 70; the plain type was concrete at 63), another at 51. The wider ones by function: `pairs` 36, `iterate` 18, `collect` 13, `NamedTuple` 12, `nonmissingtype` 7, `disallowmissing` 5, `map` 5. A value of a kind in an argument is a frequent cause (`iterate(::Dict{Symbol, DataType})`: `Tuple{Any, Int64}` for `Tuple{Pair{Symbol, DataType}, Int64}`).
- **Found on the way:** 2,341 (the forks) and 1,787 (upstream) of the instances below carry no G2 bit and hold binding edges only (`getproperty(::Module, ::Symbol)` at a constant name, an instance made for a constant-propagated result). G2 allows a binding edge, so the probe counts them as having the bit. With them counted as culprits, 1,367 of the forks' own image instances are deep.

### E-396 (P5 (b)): run-time sites by who owns the callee

Each own facts instance inferred again by the facts rule (the top frame) and its optimized code read for calls left to run time. `p5/logs/sites-forks.log`, `sites-demo.log`.

| | the forks (CSV, DataFrames, Tables) | TraitCSV, TraitTables, TraitMakie | the ODE packages |
|---|---|---|---|
| own facts instances read | 3,440 | 234 | 422 |
| calls left to run time | 4,606 | 152 | 280 |
| at Base's or Core's function | 73.6 % | 37.5 % | 40.4 % |
| at an own function, not public, every method the owner's | 678 (14.7 %) | 33 (21.7 %) | 116 (41.4 %) |
| at an own function, public or exported | 7.1 % | 40.8 % | 8.6 % |
| the owner-only sites where plain inference of the call gives a concrete type | 356 | 33 | 66 |
| an abstract type or a union | 201 | 0 | 38 |
| `Any`, or more than three methods match | 121 | 0 | 12 |

### E-397 (P2): the definition-time check against the method read at the box

For each method at a trait argument: `TraitWorld.classify(m)`, against the method inferred by the facts rule at its signature with `Dynamic{X}` in each trait argument's place. A fault at the box: a call left to run time that takes a value known by a trait or a box (an operation of that trait excepted), a call with such a value that can only throw, a call that found no method. `p2/logs/`.

| | compared | both pass | the check reports, the box is clean | the check passes, the box has a fault | both report |
|---|---|---|---|---|---|
| the library and the table demonstrators | 59 | 58 | 1 | 0 | 0 |
| the ODE packages | 73 (2 not formed) | 68 | 4 | 1 | 0 |
| the forks | 33 (1 not formed) | 31 | 2 | 0 | 0 |
| the control (`mistakes.jl`): five uses outside the contract | 7 | 2 | 1 | 0 | 4 |

- **The seven the check reports and the box takes:** `asvector` (stores the value with its type), four methods of the ODE port's `ODEProblem` front end (an adapter that passes the function to helpers; keyword bodies), two of `Tables.byrow` (`promote_op(f, T)`). Six of the seven are marked `@unbounded`.
- **The one the box flags:** `ODECore._sync_in!`, a `setproperty!` with a name that is no constant, which takes the box.
- **The control:** `size(t)`, `sum(t)`, a field the trait does not declare, and a use through an unannotated function are found by both. `typeof(t)` is reported by the check and is no fault at a box.
- **Limits.** The reader looks at the top frame's optimized code on today's build, where a `Dynamic{X}` argument below the top frame takes today's compilation signature. No port holds a method the check refuses, so the corpus tests agreement on what passes; the control tests what is found. Times were not measured.

### E-398 (P7 (c)): the `Callable` census

`p7c/logs/demo.log`, `forks.log`.

| | methods naming `Callable` | with an argument typed by one | pairs told apart by two `Callable`s of different signatures | a `Callable` method beside an untyped one |
|---|---|---|---|---|
| the library, the demonstrators, the ODE packages | 58 | 17 | 0 | 5 |
| the forks | 5 | 3 | 0 | 2 |

A pair counts where the other arguments leave both methods open to one call. The seven pairs with an untyped method: `ODEProblem` (four, `ODECore/src/frontend.jl` 67, 71 against 75: "a function that is no `Callable` at the state's type"), `TraitIndexing.Getter` (one), `Tables.byrow` (two, `Tables.jl` 717, 718: "a function with no method at the cells' types"). NetworkDynamics' port names no `Callable`.

### E-399 (P6): what a load validates, by deep G2

The instances a load brings from images, after the unrelated loads. "Call by signature" is the lookup validation pays for (E-304, E-325). `p6/logs/split-forks.log`, `split-demo.log`.

| | the forks' CSV and DataFrames | TraitCSV, TraitMakie, TraitDifferentialEquations |
|---|---|---|
| instances from images | 7,367 | 1,608 |
| deep G2: instances, edges, calls by signature | 3,707, 11,297, 50 | 1,022, 2,709, 10 |
| the bit, not deep | 2,712, 30,859, 47 | 432, 4,608, 24 |
| no bit | 948, 10,111, 295 | 154, 1,215, 18 |
| deep G2's share of instances, edges, calls by signature | 50.3 %, 21.6 %, 12.8 % | 63.6 %, 31.8 %, 19.2 % |
| methods of packages in the session; pirates by the letter | 55,532; 821 | 52,390; 816 |

### E-400 (P7 (b)): GT-18's case on the head

`p7b/case.jl`, `p7b/logs/case.log`. `v::Vector{Union{X, S}}`, made before `S` joins `X`.

| Asked | before the membership | after it |
|---|---|---|
| `v isa Vector{X}`; `T == Vector{X}`; `T === Vector{X}` | false | false |
| `T <: Vector{X}` and `Vector{X} <: T` | — | true, true |
| a method at `Vector{X}`: the call, a caller compiled before, `which`, a caller compiled after | the untyped method | the untyped method |
| `v isa AbstractVector{X}` at the top level | false | true |
| the same test in a function compiled before | false | false |
| a method at `AbstractVector{X}`: the call, a caller compiled before, `which`, a caller compiled after | the untyped method | the untyped method |

- At the concrete type, `isa`, `==` and dispatch never take the two types as one. Only `<:` between them turns true.
- At the abstract type, a fresh `isa` says yes, an `isa` compiled before says no, and dispatch takes the untyped method.
- By `grep`: the library and the ports write a union inside a parameter only of concrete types (`Union{Missing, S}`).
- The rule the review proposes (no type equality by membership) needs a change in `subtype.c` and a build. Not run.
