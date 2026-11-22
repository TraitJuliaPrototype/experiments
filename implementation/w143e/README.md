# W-143e: what the census's patches left: callees named by instance, the sets in a lower bound, the unions of another shape (E-541)

The work queue's W-143 ([the work queue](../../../writeup/record/todo.md)), after its patches (E-540, [`../w143d/README.md`](../w143d/README.md)) and its census (E-535, [`../w143c/README.md`](../w143c/README.md)). Four pieces:
1. a callee named by its MethodInstance where that instance had no code when the caller finished (open issue 219; `_promote_typesubtract` below `promote_typejoin`): every such edge in the three sessions, by callee; the record's fault or a missing declaration;
2. the sets in a type variable's lower bound, for a positive answer through an entry (compiler C-161): a probe, then a fix if it shows a wrong answer;
3. the unions of another shape (compiler C-160): what each edge is, and what compiler §1.2 says of it;
4. the census before and after, by group.

## The registry's row (E-541), written before the run

- **The question.** What is left below a port's code after the census's patches: which callees are named by their instance where it had no code, and is the fault the record's or a missing declaration; does a positive answer through an entry, about a set that occurs only in a variable's lower bound, outlive its entry (C-161); what shape are the unions still unsplit (C-160)?
- **The baseline.** The head before (`next` bfaf484f55, `julia-next/`) is a regression control for the share. Plain Julia (vanilla v1.13.2, `julia-vanilla/`) for each declaration's effect on the system image and on plain code.
- **What would change the design or the list of patches.**
  - The record's rule (compiler §3.1, §3.2: an edge names the callee's code where it exists when the caller finishes) not met for a reason inside the compiler (the order in an inference cycle, the compile queue): a fix at the rule, built where it is small; else its size, and the declarations stand in.
  - A callee compiled once (a `@nospecialize` argument) whose instance inference does not use: `Base.@nospecializeinfer` on it, a declaration of what already happens, a patch that stands without traits.
  - A positive answer through an entry, about types where the set occurs only in a lower bound, that compiled code keeps after the entry ends: a soundness defect (compiler §4.8), fixed with the probe as a test. No such case possible: C-161 is no hole, and the row says why.
  - An unsplit union whose splits are each one match at a fact: a record fix if it follows from compiler §1.2 and is small; a union whose splits match several methods each or are no facts: the section's matter, stated.
- **The setting.** Product setting, strict mode off, one thread, one fresh process per session; a depot of this item's own per Julia tree (`.julia-depot/agent-depots/w143e/<tree>` in front of the shared one), whose package images are written anew for each build; the machine's load before and after in each log. TraitWorld `unified` e2cb5d0, the forks a3a37d6, TraitDifferentialEquations 21a5aa5. Builds `WIDE=0` (4 cores), one after another, at most four, in the worktree `wt/w143-julia` on a branch `w143e` from `w143-v2` = `next` bfaf484f55.

## How to run

```sh
source env.sh                                           # TREE=julia-next by default; TREE=wt/w143-julia for the branch
TREE=<tree> bash run.sh <label> images                  # the package images of the three environments, once per build
TREE=<tree> bash run.sh <label> forks|facts|ode         # the census -> logs/<label>-<session>.log and .tsv; 1 to 2 minutes
TREE=<tree> bash run.sh <label> forks diag/mi_edges.jl  # the faults "a callee named by its MethodInstance", by callee
TREE=<tree> bash run.sh <label> forks diag/unionsplit.jl  # the culprits of the group "a top-level union"
TREE=<tree> bash run.sh <label> forks diag/culprit.jl Base.promote_typejoin …   # culprits up close
TREE=<tree> bash run.sh <label> forks diag/mi_why.jl    # the faults "a callee named by its MethodInstance", by callee and cause
TREE=<tree> bash run.sh <label> forks diag/edges_of.jl  # the faults at a top-level union, each in its caller's edge group
TREE=<tree> bash seq.sh <label> forks facts ode:diag/mi_why.jl …   # runs one after another
python3 compare.py <label> <label>                      # two censuses side by side, by group
bash after.sh <label>; bash after2.sh <label>           # what ran after the build: images, census, diagnostics, probes, the library's tests
<tree>/julia --project=.. motiv/lb_entries.jl           # C-161: a positive answer whose entry has its member in a lower bound
<tree>/julia --project=.. gate/f7_lower_bound_entries.jl   # the same as a gate (asserts)
<tree>/julia --startup-file=no motiv/widened.jl         # an edge to the compileable instance, with and without @nospecializeinfer
<tree>/julia --startup-file=no motiv/plainfx.jl         # what plain code sees of the two declarations
TREE=<tree> bash tests_each.sh <label> core …           # Base's tests, one file per run
bash gates.sh <label> '<pattern>' …                     # the gates by pattern
bash plain.sh <label> <tree>...                         # plain code's first work, interleaved
<tree>/julia --project=TraitWorld traitworld_each.jl    # the library's test files one by one
```

- The tools are copies of `../w143d/`'s (`census.jl`, `census_lib.jl`, `run.sh`, `compare.py`, `diag/`, `motiv/lb_bit.jl`, `motiv/record.jl`), with the depot of this item; changes and new programs are named in the results.
- `envs/` are copies of `../w143d/envs/`.

## Results

### E-541 (2026-11-22)

Product setting, strict mode off, one thread, one fresh process per session. TraitWorld `unified` e2cb5d0, the forks a3a37d6, TraitDifferentialEquations 21a5aa5 (the logs name each). Load 2.5 to 38 of 128 (others' jobs; a census's counts do not depend on it). The trees: `julia-next` (`next` bfaf484f55, the head before), `julia-vanilla` (v1.13.2), and `wt/w143-julia` built once (`WIDE=0`, 800 s, `logs/build1.tw-build.log`) at `w143e` d1e64d8b56: two commits on bfaf484f55.

| # | Commit | What | Size |
|---|---|---|---|
| 1 | 21a9652b44 | runtime: a positive answer through an entry records the entries on both sides' TypeNames whose set reaches a set of either side, each variable's lower and upper bound included (`open_sets_in`, `membership_entries_visit`, `jl_membership_entries_for`) | `src/subtype.c`, +15 −8 |
| 2 | d1e64d8b56 | base: `_promote_typesubtract` and `fieldname`'s `throw_field_access` declared `@nospecializeinfer` (the latter's type argument `@nospecialize`) | `base/promotion.jl`, `base/runtime_internals.jl`, +4 −3 |

#### 1. A callee named by its instance where it had no code (open issue 219)

`diag/mi_why.jl` (new) lists every fault "a callee named by its MethodInstance alone" with why the edge names an instance (`logs/head2-mi_why-*.log`, `logs/b1-mi_why-*.log`). Three causes, each a callee whose code did not exist in the caller's worlds when the caller finished, so that `name_callee_code` (compiler §3.2) had none to name:

| why | the forks: faults; most cones | upstream by facts | the ODE port | where the edge comes from |
|---|---|---|---|---|
| widened | 2; 656 (`_promote_typesubtract`), 32 (`throw_field_access`) | 2; 361, 5 | 1; 4 | the inliner calls the compileable instance (`compileable_specialization`), wider than the one inference used (`@nospecialize`; Julia's despecialization of a type argument); no inference makes it; the compile queue (the JIT's `add_codeinsts_to_jit!`, an image's `compile!`) infers it after the caller is finished |
| query | 11; 12 (`hasmethod` at `typemax`, `typemin`) | 7; 1 | 32; 18 (`hasmethod` at closures, the right-hand sides: the box's test at `Callable`) | `hasmethod` folded with an edge to the matched instance (`VirtualMethodMatchInfo`) |
| static | 83; 236 (`show_list`, `show_block`: the show path), 235 (`print`), 135 (`materialize!`), 133 (`lock`, `ntuple`, `sizehint!` under DataFrames' grouped paths), 40 (`CSV.makevalueopts`) … | 28; 186, 67, 30 … | 8; 24 (`ODECore.param_integrator`), 7 (`print`) | an ordinary call with one match, recorded as the matched instance (the one-edge format), where inference's result left no code (a recursion cut, a limited result); the compile queue makes it after |

- **The widened callees are compiled once,** so `Base.@nospecializeinfer` on each declares what already happens: inference infers the instance that runs, and the caller's edge names its code. Commit 2. On build 1 the widened faults are 0 in all three sessions (`logs/b1-mi_why-*.log`); the group "219" is needed by 500 of the forks' own instances (780 on the head), 265 of upstream's (516), 96 of the ODE port's (98).
- **`motiv/widened.jl`** (`logs/b1-widened-*.log`): `kh(a::Type) = invoke(h1, Tuple{Any}, a)` with `h1(@nospecialize(a))`: the edges are `h1(::Type)`'s code and the instance `h1(::Any)` alone, on vanilla, the head and build 1 alike (plain Julia's record); with `@nospecializeinfer` the edge is `h1(::Any)`'s code and the caller carries the bit.
- **Plain Julia** (`motiv/plainfx.jl`, `logs/b1-plainfx-*.log`): inference's answers where `promote_typejoin` is used (`[x, nothing]`, `[x, missing, 1.0]`, `promote_typejoin` at types and at constants, `map(identity, Any[1, nothing])`), the results and `fieldname`'s error message are the same on vanilla, the head and build 1. Instances of `_promote_typesubtract` in a fresh session after the probe: vanilla 31, the head 33, build 1 **1**.
- **The fix at the rule is not small.** The record names a callee's code where it exists when the caller finishes, and the bit is decided then, with no walk (compiler §3.2). Two ways would make it name the code that comes later:
  - (a) the record follows the code: when the compile queue caches a CodeInstance of an instance some finished caller names by instance, the caller's edge is upgraded and its bit decided again, then its callers' (their bits were decided from it): a walk over backedges at each such inference, a CodeInstance's edges changed after it is published, and the rule's "final when the callee finishes" given up. Of the order of 60 to 100 lines in `typeinfer.jl` and `gf.c`.
  - (b) the inliner infers the instance it calls where it has no code (`typeinf_ext` from `compileable_specialization`): 5 to 10 lines, but an inference nested in the optimizer, where the engine's reservation on one thread reads its own lease as a cycle and lets a duplicate inference of the caller run, so it needs a bound such as `MAX_POLICY_CROSSINGS`; and it changes plain Julia's order of inference for every call of a `@nospecialize` method that is not inlined, inferring instances whose caller is never compiled.
  Neither is built: the declarations cover the two Base callees that carry cones; the "static" and "query" faults stay (open issue 219's proposals).

#### 2. The sets in a type variable's lower bound (C-161)

`motiv/lb_entries.jl` (new; `logs/lb_entries-head.log`, `logs/b1-lb_entries-*.log`): `A = Tuple{SZ, Ref{LY}}`, `B = Tuple{LZ, Ref{T}} where T >: LX`, after `@implement LZ SZ` (entry 1) and `@implement LY LX` (entry 2); `A <: B` rests on both (T = LY needs LX <: LY: the member in B's lower bound, the set in A).

| | the head bfaf484f55 | build 1 |
|---|---|---|
| `p() = A <: B`: folded, entries in the record | `true`, entry 1 only | `true`, entries 1 and 2 |
| the code's worlds start at | entry 1's | entry 2's |
| `p()` run in the world between the entries (asked afresh: `false`) | **`true`** | `false` |
| `p()` after entry 2 is taken back (`jl_delete_membership`; asked afresh: `false`) | **`true`** | `false` |
| `p3()` (both sides' sets in lower bounds) | the same wrong answers | `false`, `false` |
| `p1() = Ref{LY} <: Ref{T} where T >: LX` (the lower bound alone) | not folded (no entry found: no target) | folded, entry 2 recorded |

- **A soundness defect** of compiler §3.1, §4.8: code kept a positive answer after its membership ended. The walk took the open sets of the right side, upper bounds only, and the entries on the left side's TypeNames; a lower bound turns the question around (`LX <: LY`: the member on the right, the set on the left). Commit 1 takes the sets and the entries of both sides, both bounds of each variable: a superset of the entries the walk can use (each entry the walk uses has its member on a TypeName reachable from one side and a set that reaches a set occurring in one side).
- **The probe as a gate:** `gate/f7_lower_bound_entries.jl` (asserts; a candidate for `gates/`): fails on the head (`logs/b1-f7_lower_bound_entries-julia-next.log`), passes on build 1.
- **What the superset changes:** a question that `jl_subtype_via_membership` cannot rule out (a type variable in the right side) and whose right side names no set was not folded, for want of an entry to rest on; with the left side's sets as targets it now finds one and folds. The answer is true by structure, and the record holds entries it does not need. Two places seen: `Dynamic{Shape} isa Dynamic` in a forwarder's body (TraitWorld `test/bytype.jl:93` expects the two boxes made by `new` in `code_typed(BT.pair, (Circle, Sq))`; on build 1 the body folds to `(:box, :box)` and makes none: the test's one failure), and `F <: Dynamic` in `ODECore.core_problem` at a boxed `F`: the dead branch's `_member_checked` is no longer compiled (4 instances: the ODE port's own facts instances 782 → 778, `logs/head2-own_list-ode.log`, `logs/b1-own_list-ode.log`).

#### 3. The unions of another shape (C-160)

`diag/edges_of.jl` (new; `logs/head-edges_of-*.log`) reads each fault of the group "a top-level union whose splits are facts" in its caller's record. Every one is the same shape: a lookup of several matches at a call whose signature has an abstract argument, `string(::String, ::String, ::String, ::Any, ::String)` (3 matches, the `@warn` in `temp_cleanup_purge_prelocked`), `reduce_first(::typeof(add_sum), ::Any)` and `reduce_first(::typeof(mul_prod), ::Any)` (3 matches, from `mapreduce_first(::Function, …)` and `_accumulaten!`), `_realtype(::Function, ::Type{String})` (2 matches, from `_reducedim_init`). The union is a matched method's own signature met with the call's (`string(a::Union{Char, String, SubString{String}, Symbol}...)`, `reduce_first(::typeof(add_sum), x::SmallSigned)`), the instance one of the lookup's; each culprit also has the fault at the call's signature, which is no fact (compiler §1.2: an abstract argument). So the union is not at the call's top level, and the record does what §1.2 says: there is nothing to split. C-160's rest is no deviation; these culprits are open issue 218's (a call of Base's at an abstract argument; the `@warn` path, dynamic by purpose).

**The tool's change** (`census_lib.jl`, `lookup_sigs`): a fault at an instance that a lookup of several matches names counts at the lookup's signature, where that is no fact either. The predicate's verdict is the same; the faults are grouped by the call. With it the group "a top-level union" is 0 on the head too (`logs/head2-*.log`), its faults in "218: a call at an abstract argument, Base's or Core's function", and faults of the group "a store into a container of `Any`" that were instances named by a lookup of several matches move to the group of their call's signature (the forks' culprits there 86 → 28; the instances that need the group unchanged, 1,257).

#### 4. The census, before and after (`python3 compare.py head2 b1`)

| | the forks | upstream by facts | the ODE port |
|---|---|---|---|
| own facts instances in the class, the head (`head2`) | 2,830 of 4,315 (65.6 %) | 2,843 of 3,567 (79.7 %) | 610 of 782 (78.0 %) |
| build 1 (`b1`) | 2,830 of 4,315 (**65.6 %**) | 2,843 of 3,567 (**79.7 %**) | 606 of 778 (**77.9 %**) |
| culprits | 1,438 → 1,434 | 867 → 863 | 159 → 158 |
| culprits in a cone: median, most | 6, 384 → 5, 380 | 11, 155 → 11, 151 | 3, 56 → 3, 56 |

By group (culprits with such a fault; own facts instances that stay out with every other group fixed), the head → build 1, with the tool above on both:

| group | the forks | upstream | ODE |
|---|---|---|---|
| record: `TypeVar`, `UnionAll` at `(Any, Any)` | 46 → 46; 835 → 835 | 41 → 41; 512 → 512 | 5 → 5; 82 → 82 |
| record: a top-level union | 0; 0 | 0; 0 | 0; 0 |
| lowering: a keyword body | 104 → 104; 334 → 334 | 59 → 59; 165 → 165 | 0; 0 |
| Base: `getproperty` at a kind | 22 → 22; 81 → 81 | 18 → 18; 82 → 82 | 17 → 17; 7 → 7 |
| 218: a tuple with an abstract element | 128 → 127; 821 → 821 | 118 → 117; 463 → 463 | 9 → 9; 11 → 11 |
| 218 (b): a store into a container of `Any` | 28 → 28; 1,257 → 1,257 | 25 → 25; 611 → 611 | 7 → 7; 15 → 15 |
| 218: the task code | 1 → 1; 833 → 833 | 1 → 1; 235 → 235 | 0; 0 |
| 219: a callee named by instance | 56 → **54**; 780 → **500** | 30 → **28**; 516 → **265** | 41 → 40; 98 → 96 |
| 218: any other call with a kind | 288 → 283; 621 → 621 | 166 → 161; 300 → 300 | 53 → 53; 59 → 59 |
| 218: Base's function at an abstract argument | 952 → 953; 690 → 690 | 588 → 589; 422 → 422 | 47 → 47; 13 → 13 |
| another module's function at an abstract argument | 148 → 148; 545 → 545 | 72 → 72; 247 → 247 | 21 → 21; 60 → 60 |

- **No session's share moves:** `_promote_typesubtract` was in 656 of the forks' cones, each with other culprits; the group of callees named by instance is needed by 280 and 251 fewer own instances. The greedy order of groups on build 1 (the forks): kinds 66.6 %, the ports' own 67.7 %, 219 68.7 %, stores 69.8 %, the task code 75.4 %, `TypeVar` 79.7 %, tuples 84.0 %, Base at abstract 91.5 %, keyword bodies 98.1 %, `getproperty` at kinds 100 %.
- **The ODE port's 4 fewer own instances** are the `_member_checked` branches commit 1's folds remove (point 2), all with the bit: the share moves by their count, not by a fault.

#### Checks on build 1

- **Base's tests** (one worker, one file per run, `logs/tests-b1-*.log`): `core`, `reflection`, `tuple`, `missing`, `broadcast`, `subtype`, `worlds`, `Compiler/inference` pass.
- **The gates** (`logs/gates-b1.log`, `logs/gates-b1-all.log`): `f7_*`, `m1_*`, `m2_*`, `n2_*` pass (37); all: 75 in force pass, 1 fails, 9 stage gates pass. The one that fails is `n37_absence_worlds` (new, the main session's), which fails on `next` bfaf484f55 by design: its fix is the julia branch `absence-worlds`, merged with this branch.
- **The library's tests** (`TraitWorld/test/runtests.jl` as a file stops at the first failing file, `logs/traitworld-tests-b1.log`; each file apart, `traitworld_each.jl`, `logs/traitworld-each-b1.log`): every file passes but `bytype.jl`, 20 of 21 in its test set "the trait's default as generated methods": line 93 counts the boxes made by `new` in `code_typed(BT.pair, (Circle, Sq))`, which commit 1's fold of `isa Dynamic` removes (point 2). The library's test, not a wrong answer.
- **Plain code's first work:** `plain.sh` (upstream CSV and DataFrames compiled plainly, `../w19/motiv/f-plain.jl`; a warm-up and 3 runs each, interleaved, load 8 to 9; `logs/plain-b1.log`): the first work 4.45–4.47 s on the head, 4.45–4.48 s on build 1; the load 676–1,093 ms and 687–781 ms; digests equal. Valid CodeInstances after the load 118,998 → 119,092, those with the bit 91,232 → 91,210 (not attributed).
