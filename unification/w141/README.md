# W-141: a membership is a method. The findings (E-367)

The build plan: `writeup/plans/2026-11-11-membership-as-method-build.md`. The proposal: `writeup/plans/2026-11-11-membership-as-method.md`. This file is the one log of findings: one row per trade-off, filled as each stage runs. Small cases only; the machine's load is given with each table.

## How to run

```
source env.sh
julia-unified/julia --startup-file=no experiments/unification/w141/probe_scaling.jl
julia-unified/julia --startup-file=no experiments/unification/w141/probe_family.jl
cd experiments/unification
JULIA_LOAD_PATH="$PWD:@stdlib" ../../julia-unified/julia --startup-file=no w141/costs.jl 2000
JULIA_LOAD_PATH="$PWD:@stdlib" ../../julia-unified/julia --startup-file=no gates/n29_membership_method.jl
cd ../../TraitDifferentialEquations-unified
../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w141/edges_stats.jl TraitDifferentialEquations
../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w141/by_hand.jl
cd ../experiments/unification
../../julia-unified/julia --startup-file=no w141/probe_valuesig.jl
JULIA_LOAD_PATH="$PWD:@stdlib" ../../julia-unified/julia --startup-file=no w141/probe_refused.jl
```

**Decided (2026-11-12, the user):** a membership behaves as a method does and is not defined as one. Stage 1 is kept as the implementation of the edges (compiler §5.6); stage 2 is removed on `unified` 8b4fde6e84: a program defines no method of `Core.implements`. So `by_hand.jl` (2) and (3) and `probe_refused.jl` ran on the builds named with their results and are refused at the head. The tables below are the record of what was built and measured.

**The baseline** is `julia-unified-base/`: a copy of the tree with the sources of `unified` b1c0b50f4c (the build with cells), built beside it. It is not a git checkout. A copy's `usr/share/julia/{base,Compiler,test}` links point into the original tree and must be pointed at the copy, and the copy's `Compiler/src` touched, before it is built: otherwise it compiles the original's compiler.

The logs are in `logs/`.

## Stage 0: the method table's side, on plain functions (2026-11-11, `unified` b1c0b50f4c, one run each, load 1 to 2 of 128)

| Probe | Result |
|---|---|
| 2,000 concrete members of one trait, spelled `(::Type{X}, ::Type{S})` | insertion constant, 0.72 ms each with the struct's definition; `methods` 1.6 ms |
| the same spelled `(::Type{X}, ::Type{<:S})` | insertion grows with the members: 1.7, 3.4, 6.3, 12.6 ms each at 250, 500, 1,000, 2,000; `methods` 21 s at 2,000 |
| 2,000 families of one trait with an input, `(::Type{Col{T}}, ::Type{F{T}}) where T` | insertion constant, 0.95 ms each; `methods` 2.0 ms; the instance of a member is the match's static parameter (`svec(Int64)`) |
| a lookup, repeated | 0.1 to 0.3 µs (cached), hit or miss |
| a first lookup per family, 2,000 methods | 17.8 µs each; a repeated hit at a family 8.3 µs |
| a lookup at `Type{<:AbstractVector}` over 2,000 families | 6.3 ms, no match |
| an abstract member, `(::Type{Shape}, ::Type{<:Poly})` | its subtype and itself match; another type does not |
| 5,000 traits with one member each | 0.16 ms per method beyond the type's definition |

## What is built (2026-11-12)

| Stage | Build | What it does |
|---|---|---|
| 1 | `unified` 90fb8ff97a | Each membership has a method of `Core.implements`, defined by the runtime in the declarer's module, in the entry's world. A folded negative holds a missing-method edge at the pair's signature; the method's insertion ends the code. A folded positive holds an edge to the method. Cells are not used |
| 2 | `unified` 5d036a41db | A method of `Core.implements` written by a program declares the membership: the pair from the signature, the receiver from the body. A folded positive holds an `invoke` edge to the method's instance. Deleting such a method is refused |
| cleanup | `unified` b66cdc66f2 | The cell type and the entry's check as an edge removed; the library's definition hook sees a membership's method written by hand |

**Not built:** the method as the only record (the entries stay as the index subtyping reads, with their worlds); an image's own list of memberships and their activation; the library's `@implement` lowering to the method's definition; the library's membership rule in `ownership.jl` replaced by the method's; taking a membership back.

**Checks on stage 2** (one run each, load 1 to 8 of 128): gates 68 pass with the new `n29_membership_method` (the nine `m3_*` fail as before); TraitWorld 81 test sets; TraitTables 3; TraitDifferentialEquations 34; five small programs build under `--trim=safe` and run (stage 1); E-358's composition in one order: 160 instances, none lost, the same digest as before.

## Stage 1 and 2: what it costs (2026-11-12, one run each unless said, load 1 to 5 of 128)

`costs.jl` with 2,000, the runtime's entry point, no library:

| | cells (`unified` b1c0b50f4c) | a method per membership (stage 2) |
|---|---|---|
| declare a member of one trait, 2,000 in a row | 18 to 36 µs each | 30 to 40 µs each |
| fold a negative (inference included), 2,000 at one trait | 1.99 to 2.03 ms each | 2.10 to 2.28 ms each, rising with the count |
| a membership at the trait with 2,000 folded negatives (it ends one) | 613 µs | 666 µs |
| a membership of a fresh type, with 2,000 negatives folded at another trait | 17 µs | 328 µs |
| a membership at a new trait, the same session | 7.5 µs | 293 µs |
| a plain method definition | 237 µs | 241 µs |

Loads, a fresh process each, five runs, the builds alternating (`logs/loads.log`):

| | cells | a method per membership |
|---|---|---|
| `using TraitWorld, TraitTables` (53 memberships) | 0.102 to 0.103 s (one run 0.134) | 0.104 to 0.105 s |
| `using TraitDifferentialEquations` (126 memberships) | 1.03 to 1.04 s (one run 1.11) | 1.00 to 1.01 s |

Membership edges in a session's code (`edges_stats.jl`): with TraitTables loaded, 21 positive and no negative among 80,698 code instances; with TraitDifferentialEquations, 185 positive and 6 negative among 86,831 (cells: 187 and 7).

## The trade-offs

| # | Trade-off | Found | Handled | Left, and where it is flagged |
|---|---|---|---|---|
| R1 | One function with every membership | **The spelling decides.** `Type{<:S}` for a concrete member makes insertion linear in the trait's members and `methods` unusable (21 s at 2,000). `Type{S}` is constant | The signature is `(Type{X}, Type{S})` for a concrete member and a family, `Type{<:S}` only for an abstract member. The runtime refuses the other spelling | Abstract members of one trait cost each other; few in practice, not measured on a port |
| R2 | A trait's inputs under `Type{…}` | Works: the instance of a member is the match's static parameter | none needed | "One instance per member" stays the runtime's check, not ambiguity's |
| R3 | An abstract pair, an unmet intersection | The negative's edge is `(Type{<:X}, Type{S})`, or `(Type{<:X}, Type{<:A})` for an abstract `A`. `Type{<:X}` reaches a membership in a subtrait | built; `n18`, `n20`, `n29` (5) | none |
| R4 | Image validation by lookup | A positive is validated by a pointer compare and a flag, about what an entry cost. A negative needs a lookup (8 to 18 µs; 6 ms at `Type{<:A}` over 2,000 methods). Sessions hold 0 to 6 negatives | none needed; the loads show no cost | A program that folds thousands of negatives pays the lookups at each load. Not seen |
| R5 | Insertion into one table | **Every folded negative of the session is in one list** (under `Core.implements`' type). Each membership scans it: 0.15 µs per negative, 293 µs with 2,000 where a cell cost 7.5 µs | not handled. The fix: index those backedges by the trait's name, as Julia indexes keyword calls by another argument; an insertion then looks under the trait and its supertraits | open issue 180 (a) |
| R6 | Older worlds | Unchanged: subtyping reads the entries, which keep their worlds; the method's `primary_world` is the entry's | none needed at this stage | arises again when the entry's worlds are dropped |
| R7 | Cost to code that uses no trait | A plain method definition: 237 against 241 µs. The loads above | none needed | the plain session (E-356) waits for the measurement round |
| R8 | Bootstrap | No membership is declared before Base | none needed | none |
| R9 | The method's piracy rule | The library's rule for methods (`owned_method`) agrees with its membership rule on 125 of 126 memberships of a session. The one: `Dynamic{Z}` in `Callable{A, S}`, both Core's, declared by the library. A third party's membership written by hand is `owned_method == false` | the definition hook now sees a hand-written membership's method, so `no_pirates` refuses it | the library's own membership rule is not removed; the warning for a pirate in default mode is `@implement`'s; open issue 180 (b) |
| R10 | Taking a membership back | **Not a method's deletion alone.** Code that folded the membership holds an edge and is ended. Code that only *called* a trait's method at the member holds an edge to that method, not to the membership | deleting a membership's method is refused | open issue 180 (c): the walk of the trait's methods, in reverse |
| R11 | Two memberships that apply | **Not an ambiguity.** A member of two subtraits of one trait is in the trait twice: `Indexable`, `Keyed` and `Resizable` are each in `HasLength`. `Test.detect_ambiguities` reports 12 pairs in the library | The method is never called, only asked for; the library's test leaves `implements` out | Aqua and other tools report them; the proposal's row "method ambiguity, reported as Julia reports it" is wrong; open issue 180 (d) |
| R12 | A membership an image's load refuses | The entry is refused (another instance for the member), yet its method is activated. A positive edge to it would validate | not handled | open issue 180 (e); goes away when the method is the only record |
| R13 | An overlapping membership | A membership whose method meets one that code folded (the same type in the same trait by another route) drops the session's dispatch cache, as any method that meets a compiled one does | none | open issue 180 (f); not measured |
| R14 | A membership written by hand is not checked | `Core.implements(::Type{Sized}, ::Type{Bad}) = nothing` is accepted; the missing operation shows at the call, as `MethodError` | none: the check is `@implement`'s, as for `struct S <: X` | the teaching says so; open issue 180 (g) |
| R15 | Size of the implementation | Net +44 lines in Julia at stage 2 and cleanup (332 added, 288 removed): the method's creation and reading replace the cells. The entries, the image's list and the library's rule are still there | — | the reduction the proposal lists comes only with the method as the only record |
| R16 | A refused membership written by hand (2026-11-12, `unified` f6ad3008b4, `probe_refused.jl`) | The method is added to the table before the checks. Refused for a second instance, it stays in the table: one entry at the signature, never activated, seen by no query | not handled | open issue 180 (h): add the method after the checks |
| R17 | Another spelling: the member as an argument type, `(::Type{X}, ::S)` (2026-11-12, plain functions, `probe_valuesig.jl`, one run, load 2 of 128) | 2,000 concrete members 0.72 to 0.75 ms each; 2,000 abstract members 0.52 to 0.57 ms each, constant (`Type{<:A}`: 1.5, 3.3, 6.1, 12.5 ms); `methods` 1.4 ms (19.6 s). `Test.detect_ambiguities` reports nothing for 20 abstract members under either spelling | not tried in the runtime | open issue 180 (j) |

## After the decision (2026-11-12, `unified` 8b4fde6e84, one run each, load 15 to 19 of 128)

| Check | Result |
|---|---|
| A method of `Core.implements` written by a program | refused; nothing in the table (gate `n29_membership_method` (3)) |
| A membership refused for a second instance | no method in the table (R16 fixed; the same gate) |
| A membership refused at an image's load, both load orders | its method is in force in no world: `methods` at the pair is empty (R12 fixed; gate `n12_image_instances`) |
| The gates | 69 pass; the nine `m3_*` fail as before (`logs/gates_kept.log`) |
| The suites | TraitWorld 82 test sets, TraitTables 3, TraitDifferentialEquations 34: all pass (`logs/*_kept.log`) |

The review of the built state, with its addendum on the decision: `writeup/reviews/2026-11-12-w141-membership-as-method.md`.
