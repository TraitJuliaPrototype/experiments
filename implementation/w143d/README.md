# W-143d: Base's surface, the census's patches built and counted; the compiler's record; subtyping's entry test (E-540)

The work queue's W-143 ([the work queue](../../../writeup/record/todo.md)), after its census (E-535, [`../w143c/README.md`](../w143c/README.md)). Three pieces:
1. the four patches of `../w143c/patches/` (a type's flags read by `getfield`; the type joins `up/03` left; `CyclePadding`; the task code's stores), each one commit on `next` in the julia worktree `wt/w143-julia` (branch `w143`), finished where a patch that stands without traits can, built, tested by Base's tests, and counted by the census on the three sessions;
2. the compiler's record (compiler C-160; open issue 218 (g)): a call of `!==` at a top-level union, and `TypeVar(…)`, `UnionAll(…)` recorded at `(Any, Any)`;
3. subtyping's entry test (GT-9): one test at the entry of subtyping and intersection in place of a bit read at each step of the walk.

## The registry's row (E-540), written before the run

- **The question.** (1) On `next` 683ea4fc16 (TraitWorld `unified` e2cb5d0, TraitDifferentialEquations 21a5aa5, the forks a3a37d6), what does each of the four patches to Base buy of the deep class (the G2 bit, compiler §3.2) in the census's three sessions (the forks' table work; upstream CSV and DataFrames compiled by facts; the ODE port), by the census's groups? Does each stand as a patch on plain Julia, with Base's tests for what it touches passing, and what does a package's method for its own type end of the system image's code before and after it (plain Julia's motivation)? (2) Can the compiler record the call of `!==` at a top-level union split into fact signatures (compiler §1.2), and `TypeVar(…)`, `UnionAll(…)` at the call's own signature, in a few lines, and what does each buy? (3) Does subtyping cost plain code on `next` what it costs on the traits series' first parts (+12 % in `jl_subtype`, E-539), and can one test at the entry of subtyping and intersection (does either side have a set in it) stand exactly for the tests the walk makes at each step?
- **The baseline.** Plain Julia: vanilla v1.13.2 (`julia-vanilla`, built on this host) for the micro-timings, plain code's first work and the invalidation probes. The deep class is a count plain Julia does not have: each patch's plain baseline is that it stands on v1.13.2 without traits, stated per patch. The census on the head before the patches (`next` 683ea4fc16) is a regression control, as E-535's numbers on cf0f039f51 are.
- **What would change the design or the list of patches.**
  - A patch that buys a point or more of a session alone, or is needed by hundreds of own instances, and passes Base's tests: a candidate for the patches for upstream (`up/20` and above).
  - A patch whose group stays needed after it (the census's "needed" column unchanged): its faults are not where the census put them; the group's predicate is read again.
  - A record fix that is not small (more than a few lines, or a gate fails): the deviation row (C-160) and open issue 218 (g) stand, with the text of what it would take.
  - The entry test not exact (a membership, an entry or `All` reached through a type that has no set in it at the entry: a type variable's bound, a type made during the walk): the tension GT-9 stands, with what exactness would cost. Exact and with the micro-timings at vanilla's within a few per cent: GT-9's subtyping part closes.
- **The setting.** Product setting, strict mode off, one thread, one fresh process per session; a depot of this item's own per Julia tree (`.julia-depot/agent-depots/w143d/<tree>` in front of the shared one), whose package images are written anew for each build; the machine's load before and after in each log. Builds `WIDE=0` (4 cores), one after another, at most six. Micro-timings: `../w19/motiv/h-micro.jl` (ns per call, minimum of 7 rounds), two processes per tree, the trees interleaved in the same hour.

## How to run

```sh
source env.sh                                           # TREE=julia-next by default; TREE=wt/w143-julia for the branch
TREE=<tree> bash run.sh <label> images                  # the package images of the three environments, once per build
TREE=<tree> bash run.sh <label> forks|facts|ode         # the census -> logs/<label>-<session>.log and .tsv; 1 to 2 minutes
TREE=<tree> bash run.sh <label> forks diag/culprit.jl Base.notify …   # culprits up close (as ../w143c)
TREE=<tree> bash run.sh <label> forks diag/kindprop.jl  # the culprits of the group "getproperty at a kind"
TREE=<tree> bash run.sh <label> forks diag/unionsplit.jl  # the culprits of the group "a top-level union"
TREE=<tree> bash run.sh <label> forks diag/mi_edges.jl  # the faults "a callee named by its MethodInstance", by pattern
python3 compare.py <label> <label>                      # two censuses side by side, by group
TREE=<tree> bash tests.sh <label> core reflection …     # Base's tests, one worker -> logs/tests-<label>.log
<tree>/julia --startup-file=no motiv/probes.jl <probe>  # a package's method for its own type: system image instances it ends
<tree>/julia --startup-file=no motiv/record.jl          # the edges of three calls (!== at a union, TypeVar, UnionAll)
<tree>/julia --project=.. motiv/lb_bit.jl               # the bit "a set occurs in this type" and a lower bound
bash plain.sh <label> <tree>...                         # plain code's first work (../w19/motiv/f-plain.jl), interleaved
bash motiv/micro.sh <label> <tree>...                   # ../w19/motiv/h-micro.jl, interleaved, two processes each
bash motiv/perfsplit.sh <label> sub|isect <tree>...     # perf: subtyping's own functions apart from the harness
```

- The trees: `julia-next` (`next` 683ea4fc16, the head before), `julia-vanilla` (v1.13.2), and `wt/w143-julia`, built twice: build 1 at `w143` 09cc082278 (the four patches as first made), build 2 at `w143-v2` bfaf484f55 (the patches finished, the two record fixes, the bit's lower bound).
- `envs/` are copies of `../w143c/envs/` (the census) and `../w19/envs/up` (plain code's session); a depot per tree under `.julia-depot/agent-depots/w143d/`.

## Results

### E-540 (2026-11-22)

Product setting, strict mode off, one thread, one fresh process per session. TraitWorld `unified` e2cb5d0, the forks a3a37d6, TraitDifferentialEquations 21a5aa5, experiments 927f32d7d7 (the logs name each). Load 3.9 to 29 of 128 (others' jobs; a census's counts do not depend on it). Builds `WIDE=0`, two of six (`logs/build1.tw-build.log`, `logs/build2.tw-build.log`): 881 s and 861 s; `sys.so` 211,669,072 and 212,330,304 bytes against `next`'s 211,809,176 (+0.25 %).

**The setup's departure:** the worktree's `deps/srccache` was copied from `julia-next` as `../w159/rows/oi225.sh setup` does, but not `stdlib/srccache`; build 1 fetched the sixteen standard libraries' source tarballs (1.9 MB) from GitHub before it was noticed.

#### The census on the head (the new before; `logs/head-*.log`)

| | the forks | upstream by facts | the ODE port |
|---|---|---|---|
| own facts instances in the class | 2,764 of 4,315 (64.1 %) | 2,818 of 3,567 (79.0 %) | 547 of 780 (70.1 %) |
| own image instances in the class | 3,955 of 5,704 (69.3 %) | 2,774 of 3,490 (79.5 %) | 540 of 758 (71.2 %) |
| culprits (a fault of their own) | 1,509 | 921 | 184 |
| culprits in a cone: median, most | 12, 410 | 19, 177 | 4, 67 |

The tables' sessions give E-535's counts exactly (cf0f039f51 → 683ea4fc16 changes no count). The ODE port moved (TraitDifferentialEquations 06c28c3 → 21a5aa5, the library a5ec7f0 → e2cb5d0): 547 of 780 against E-535's 523 of 717.

#### After the patches (build 2, `w143-v2` bfaf484f55; `logs/b2-*.log`; build 1's first form `logs/b1-*.log`)

| | the forks | upstream by facts | the ODE port |
|---|---|---|---|
| own facts instances in the class | 2,830 of 4,315 (**65.6 %**, +1.5) | 2,843 of 3,567 (**79.7 %**, +0.7) | 610 of 782 (**78.0 %**, +7.9) |
| own image instances in the class | 4,026 of 5,704 (70.6 %) | 2,799 of 3,490 (80.2 %) | 598 of 760 (78.7 %) |
| culprits | 1,438 | 867 | 159 |
| culprits in a cone: median, most | 6, 384 | 11, 155 | 3, 56 |
| build 1 (first form): own facts instances in the class | 2,779 (64.4 %) | 2,820 (79.1 %) | 610 (78.0 %) |

**By group** (culprits with such a fault; own facts instances that stay out with every other group fixed), head → build 2 (`python3 compare.py head b2`):

| group | the forks: culprits; needed | upstream: culprits; needed | ODE: culprits; needed | the patch that acts on it |
|---|---|---|---|---|
| record: `TypeVar`, `UnionAll` at `(Any, Any)` | 46 → 46; 835 → 835 | 41 → 41; 512 → 512 | 5 → 5; 82 → 82 | R2 (the faults move to the call's own signature, which is no fact: below) |
| record: a top-level union | 31 → **12**; 358 → 44 | 18 → **5**; 212 → 15 | 1 → **0**; 7 → 0 | R1 |
| lowering: a keyword body | 106 → 104; 1,056 → 334 | 61 → 59; 417 → 165 | 0; 0 | 04 (`schedule`'s body no longer reached) |
| Base: `getproperty` at a kind | 46 → **22**; 699 → 81 | 38 → **18**; 433 → 82 | 40 → **17**; 135 → 7 | 01, 02 |
| 218: a tuple with an abstract element | 129 → 128; 856 → 821 | 119 → 118; 474 → 463 | 10 → 9; 62 → 11 | 03 |
| 218 (b): a store into a container of `Any` | 87 → 86; 1,257 → 1,257 | 83 → 82; 611 → 611 | 10 → 10; 15 → 15 | — |
| 218: the task code | 6 → **1**; 1,000 → 833 | 6 → **1**; 329 → 235 | 0; 0 | 04 (left: `sync_end`'s push onto a `CompositeException`) |
| 219: a callee named by instance | 55 → 56; 500 → 780 | 29 → 30; 265 → 516 | 40 → 41; 96 → 98 | — (one new: below) |
| 218: any other call with a kind | 331 → 292; 918 → 621 | 198 → 167; 520 → 300 | 58 → 54; 63 → 59 | 01, 02 |
| 218: Base's function at an abstract argument | 997 → 965; 886 → 690 | 619 → 595; 545 → 422 | 49 → 47; 17 → 13 | 02, 04 |
| another module's function at an abstract argument | 148 → 148; 545 → 545 | 72 → 72; 247 → 247 | 21 → 21; 60 → 60 | — |

- **The ODE port** gains 7.9 points, nearly all from patch 01: `isbitstype` (19 instances, in 135 cones, 48 alone on the head) leaves the culprits; the group "getproperty at a kind" is then needed by 7 own instances (135).
- **The tables' sessions** gain 1.5 and 0.7 points. Their cones stay wide; the greedy order of groups on build 2 (the forks): kinds 66.6 %, the ports' own 67.7 %, 219 68.7 %, stores 69.8 %, the task code 75.4 %, `TypeVar` 79.7 %, tuples 84.0 %, Base at abstract 91.5 %, keyword bodies 97.8 %, `getproperty` at kinds 99.0 %, the union 100 %.
- **What each patch's first form left** (build 1, `logs/b1-culprits-forks.log`, `logs/b1-kindprop-*.log`): patch 02's helper `_promote_typejoin_union` was itself called at `Any`; `close` called `notify_error` at an `Exception`; `notify`'s call of `_schedule` named the compiled instance `_schedule(::Task, ::Any, ::Bool)` by its MethodInstance (it had no code when `notify` finished); `rewrap_unionall(::TypeofVararg, u)` and `_compute_eltype` (a tuple's `eltype`) read fields by `getproperty` (in 193 and 154 of the forks' cones). Build 2 finishes them (below).
- **A new culprit by instance** (`diag/mi_edges.jl`, `logs/b2-mi-*.log`): `promote_typejoin(::Type, ::Type)`, now reached through `invoke`, names `_promote_typesubtract(::Any)` by its MethodInstance: inference used the instance at `Type`, the code runs the one at `Any` (a `@nospecialize` argument), and that one had no code when the caller finished; it has code with the bit now. In 656 of the forks' cones (4 of the ODE port's). The same pattern as `_schedule` in build 1, which `@nospecializeinfer` resolves (patch 04). It is a pattern, not a case: a call whose inferred instance is narrower than its compiled one (a `@nospecialize` argument without `@nospecializeinfer`) names the compiled one by instance where it had no code yet. The tool lists every such fault with whether the callee has code with the bit now.

#### The patches (branch `w143-v2`, on `next` 683ea4fc16)

| # | Commit | What | Size | Base's tests | Plain motivation: a package's method for its own type, system image instances it ends (vanilla; `next` → build 2) | Guarantee for plain code it touches |
|---|---|---|---|---|---|---|
| 01 | 852bbaaafc | the type predicates (`isbitstype`, `isconcretetype`, `isdispatchtuple`, `isprimitivetype`, `datatype_ismutationfree`, `datatype_isidentityfree`) and the layout readers (`datatype_haspadding`, `_isbitsegal`, `_nfields`, `_fielddesc_type`, `_arrayelem`, `_layoutsize`, `DataTypeFieldDesc`, `ismutable`, `ismutabletype`) read a type's fields with `getfield`; `datatype_pointerfree` calls `datatype_npointers` through `invoke` | 1 file, +23 −23 | `core`, `reflection` pass | `getproperty(::Type{W143A}, ::Symbol)`: 4,977; 4,962 → **3,414** (the patch's methods 48 → 0) | none: the answers are the same; a package's `getproperty` of its own type no longer reaches the predicates (intended) |
| 02 | 82f488a248 | the joins under `promote_typejoin_union` (`typejoin_union_tuple`, `typejoin`'s `Type.body.name`), `_compute_eltype` (a tuple's `eltype`) and `rewrap_unionall` of a `Vararg` read fields with `getfield` and call through `invoke`; a free type variable takes the direct call, which has no method, as before | 3 files, +29 −21 | `core`, `tuple`, `missing`, `broadcast` pass | `typejoin(::Type{W143B}, ::Type{W143B})`: 1,938; 771 → **509**. `promote_typejoin(::Type{W143P}, b)`: 1,084; 1,087 → **150** | a package's `typejoin`, `promote_typejoin` or `getproperty` for its own type is no longer consulted inside these joins (as `up/03`) |
| 03 | 5331dadc00 | `CyclePadding`'s iteration reads its tuples with `getfield` | 1 file, +5 −4 | `reinterpretarray` passes | `getindex(::Tuple{W143C, Int}, ::Int)`: 2,528; 2,798 → **2,470** (`iterate` 104 → 92) | none |
| 04 | de2113b984 | `close` stores the exception with `setfield!` and calls `notify_error` through `invoke`; `notify_error` calls `notify` through `invoke`; `notify` calls `_schedule`, `schedule`'s positional body (`@nospecializeinfer`), through `invoke` | 3 files, +11 −7 | `channels` passes; `threads` 163 pass, 5 fail: the BLAS default-threads test under the host's CPU affinity, which gives the same answers on `next` (`[1, 1, 1, 2]` for 1 to 4 CPUs) | `schedule(::Task, ::W143S; error)`: 1,269; 939 → **7**. `setproperty!(::Channel, ::Symbol, ::W143E)`: 37; 37 → **0** | a package's `schedule`, `notify` or `setproperty!` method for its own value type is no longer called from the task code (intended, as `up/05`) |
| R1 | 4b08f7179f | the compiler: a call's edge at a top-level union, one fully covering match at a wider instance, is split as inference splits a call, each split with its own edge (`callsig_splits`, `stmtinfo.jl`) | 1 file, +19 | `Compiler/inference` passes; gates `f4_g2_bit`, `n21_callsig_backedge`, `f7_membership_edges` pass | `motiv/record.jl`: `!==` in `findfirst(==(c), s) !== nothing` recorded at `(Union{Nothing, Int64}, Nothing)` (no fact) on `next`; at `(Nothing, Nothing)` and `(Int64, Nothing)` (facts) on build 2 | a later method ends the caller where it did (the splits' union is the signature) |
| R2 | f7a5667000 | `TypeVar` and `UnionAll` declared `@nospecializeinfer`, matched at the call's own signature (`abstract_call_known`) | 2 files, +12 −9 | as R1 | `motiv/record.jl`: `TypeVar(:T, Char)` at `(Type{TypeVar}, Any, Any)` → `(Type{TypeVar}, Symbol, Type{Char})`, a fact; `UnionAll(v, Vector{Int})` at `(Any, Any)` → `(TypeVar, Type{Vector{Int64}})`, a fact | as `!==` (compiler §3.1) |
| B | bfaf484f55 | the runtime: `has_open_set` follows a type variable's lower bound too (`open_set_witness`) | 2 files, +6 −4 | `subtype` passes; gates `m1_*`, `m2_*`, `n2_*` and all in force pass | not plain: a soundness fix of the trait mechanism (point 3) | none: types without a set keep their bit clear |

- **Base's tests on build 2** (`logs/tests-b2.log`, one worker, load 16 to 29): `core`, `reflection`, `tuple`, `missing`, `reinterpretarray`, `channels`, `broadcast`, `subtype`, `worlds`, `Compiler/inference` pass (7,677,469 pass, 63 broken); `threads` as above.
- **The gates on build 2** (`logs/gates-b2.log`): 75 in force pass, 9 stage gates pass. **The library's tests** (`TraitWorld/test/runtests.jl` as a file, `logs/traitworld-tests-b2.log`): pass, rc 0.
- **Plain code's first work** (`logs/plain-b2.log`; upstream CSV and DataFrames compiled plainly, a warm-up and 3 runs each, interleaved, load 16 to 20): `next` 4.43–4.45 s, build 2 4.46–4.48 s; the load 679–705 ms and 690–705 ms; digests equal. Valid CodeInstances after the load 119,540 → 118,937 (`TypeVar`, `UnionAll` and `_schedule` inferred once), those with the G2 bit 90,581 → 91,225.
- **The probes** (`logs/probes.log`, one process each): the `notify(::GenericCondition, ::W143N, all, error)` probe ends 56 instances on all three (the loader's callers of `notify` at a payload of unknown type, not the task code's).

#### What stays out, by kind

- **`TypeVar`, `UnionAll` (R2):** the 46, 41 and 5 culprits keep a fault, now at the call's own signature: `UnionAll(::TypeVar, ::Type{AbstractArray{#s188, 1}})`, where `AbstractVector{<:T}` is made at run time in `collect` (`logs/b2-culprits-forks.log`). `Type{X}` with a free variable in `X` is no dispatch tuple, so the signature is no fact (compiler §1.2): the record is done; whether such a signature should be a fact is the rule's matter (open issue 218 (g)).
- **A top-level union (R1):** the 12, 5 and 0 culprits left (`logs/b2-unionsplit-forks.log`) have edges at a union that are not a single match at a wider instance: `string(::String, ::String, ::String, ::Union{Char, SubString{String}, String, Symbol}, ::String)` in `temp_cleanup_purge_prelocked`'s closure (32 cones), `reduce_first(::typeof(add_sum), ::Union{UInt8, UInt16, UInt32})` (4), `_realtype(::Union{typeof(abs), typeof(abs2)}, ::Type{String})` (2). Not read further.
- **Base: `getproperty` at a kind (01, 02):** the 22, 18 and 17 left are show and print paths (`show_datatype`, `show_typealias`, `print_without_params`, `make_wheres`, `modulesof!`), `parentmodule(::DataType)`, `unionlen`, `_uniontypes` (`logs/b1-kindprop-*.log`): (iii), dynamic by purpose, but for the last three.
- **The type joins' store** `c[i] = ci` into a `Vector{Any}` (`typejoin`, `typejoin_union_tuple`): open issue 218 (b).

### Point 3: subtyping's entry test (GT-9)

**The micro-timings on `next` beside vanilla** (`../w19/motiv/h-micro.jl`, ns per call, minimum of 7 rounds, two processes per tree interleaved; `logs/micro-next-vanilla.log`, load 17; `logs/micro-b2.log`, load 15–24):

| | vanilla 45b6d15e34 | `next` 683ea4fc16 | build 2 bfaf484f55 |
|---|---|---|---|
| `jl_subtype` | 238.6–240.0 | 263.4–264.0 (+10.2 %) | 272.3–274.4 |
| `jl_type_intersection` | 278.0–279.5 | 314.4–315.9 (+13 %) | 323.1–326.7 |
| method matching | 177.2–180.2 | 190.9–197.3 (+8 %) | 200.5–201.8 |
| the type cache | 77.6–77.9 | 78.5–78.7 | — |

- **What the micro-timing holds** (`motiv/perfsplit.sh`, perf at 4 kHz over 8 s of `motiv/loop.jl`; `logs/perf-sub-next.log`, `logs/perf-isect-next.log`, `logs/perf-sub-b2.log`): of `jl_subtype`'s 254 ns on vanilla (281 on `next`), 98 (108) are the harness (the loop's dynamic calls, tuple types, allocation) and 157 (172) subtyping's own functions: the walk costs 15 ns (+10 %) more, in `obvious_subtype` (+4), `subtype` (+6), `forall_exists_equal` (+4, the wrapper that counts `noentry`), the rest under 1 each; the harness 11 ns more (the dispatch path, `apply_generic_reach`). For the intersection: 194 → 215 ns of subtyping (+11 %; `obvious_subtype` 46.5 → 52.3, `subtype` 14.8 → 22.5, `obviously_disjoint` 7.5 → 11.0), the harness 103 → 121.
- **Build 2 against `next` with the same `subtype.c`:** 9–11 ns slower (+3.5 %), 8.7 ns of it in subtyping's functions, whose source build 2 does not change (B touches `datatype.c` and a comment in `julia.h`, which every runtime file includes). So two builds of one walk differ by about 3–4 % in this micro-timing: the layout's noise floor. The walk's own excess on `next` (+10 %) is about three times it.

**Can one test at the entry stand for the walk's tests? Exact, once the bit is complete; not small, if it is to save the cost.**
- Where the walk consults a membership (`src/subtype.c`): `subtype_membership` where the right side's name is a set (`yd->name->open_set`: the chain missed; a type value `Type{S}`), `subtype_all_right`/`_left` (`jl_is_all_type`), the kind's meeting with a set (`kind_meets_set`), `obviously_disjoint`'s and `obvious_subtype`'s abstentions, `intersect_membership` and the intersection's set branches. Each is reached at a step whose operand is a set or an `All`. Every operand of a step is a part of the two sides, a variable's bound (lower or upper; of a variable bound in either side or free), or a type the walk makes from those (a union, a meet, an instantiation), whose bit its parts give. So "neither side has a set in it" at the entry stands for every step, **if the bit says whether a set occurs anywhere, the bounds included**.
- **It did not:** `open_set_witness` followed a variable's upper bound only. `motiv/lb_bit.jl` on `next` (`logs/lb_bit-head.log`): for `A = Ref{S} where S >: LX` and `B = Ref{S} where S >: Union{LX, LM}` the bit is clear on `A`, `B` and `Vector{A}`; after `@implement LX LM`, `A == B` and `Vector{A} <: Vector{B}` are true; and `q() = Vector{A2} <: Vector{B2}`, compiled before the membership, still returns `false` after it (asked afresh, `true`). A negative was folded with no edge, because the gate (`has_open_set`) said no set was there: a soundness defect of compiler §4.8 for a set that occurs only as a lower bound. Commit B fixes it (2 lines); on build 2 the bits are set and `q()` is `true` after the membership (`logs/lb_bit-b2.log`).
- **Why the test is not built:** each of the walk's tests is already one bit read on the type at hand (`name->open_set`, `has_open_set` in `jl_is_all_type`) or one counter (`noentry`). A flag set at the entry would be read at the same places in their place, so it saves nothing; what costs is the tests' presence on the hot paths (and `forall_exists_equal_` no longer inlined into its caller). Saving it takes a walk compiled without them: the functions of `subtype.c` reached from `jl_subtype_env` and the intersection compiled twice (a macro parameter, about 3,000 lines of the walk built a second time), the entry choosing the copy. That is not small, and its gain is 15 ns of 157 per question, of the order of the layout's noise. The tension stands, with this cost; the exactness part (the bit) is built.
- **The membership machinery's other readers of a set's place** (`open_sets_in`, `membership_entries_visit`, `subtype.c`) also follow a variable's upper bound only: the entries a positive membership's fold records (compiler §3.1) miss a set in a lower bound. Not changed here; a deviation candidate.
