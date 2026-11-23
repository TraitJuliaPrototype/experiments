
# Seventh part: the series follows `next`, T16 in three, the tests of the last parts

The brief: rows 182 to 195 of the inventory (`next` 3e9c193025) into the parts where their code is made, in a new
stack; T16 cut in three; testsets in Julia's `test/` for T11 to T17; the parts not built alone built; on the head the
gates, Base's tests, the library's suite and the examples, the trimmed programs, the set-folds report in its three
modes, the nine loads and what plain code pays; Julia's static check of GC roots; every message and comment read
once more.

## How to run (seventh part)

```
python3 k/k-restack.py wt/w19-patch k/steps-v3.txt [--resume]   # the stack, from v1.13.2: picks, the rows' patches, tests, messages
python3 k/k-t16-cut.py wt/w19-patch <S3> <T16> <out>            # T16 cut in three (k/patches/t16{a,b,c}.patch)
<tree>/julia k/k-rowtests.jl [02d.jl ...]                       # the rows' testsets standalone (fail on the sixth part's S3)
<tree>/julia k/k-tests-standalone.jl                            # the testsets of T11 to T17 standalone
<tree>/julia k/k-imagetest.jl                                   # row 193's image case standalone
bash k-run-head.sh <tag> [steps]                                # the head: gates, Base's tests, suite, examples, set-folds, micro, plain, loads
bash k-mbuilds.sh <tag>                                         # the four trimmed programs on wt/w19-julia (agent-depots/w19)
bash k-parts.sh <n> <label> <commit> "<tests>" [tw]             # one part built alone, its tests and the gates
bash k-compile-checks.sh <log> <commit>...                      # make -C src and the Julia files parsed, per commit
```

`k/` holds the restack's inputs: `steps-v3.txt` (one line per commit), `patches/` (each row's hunks as applied at
its part, adapted where the part's text differs from `next`'s; the fixes of comments), `k-tests/` (the testsets and
the anchors they are inserted at), `msgs/` (the messages that changed), `k-msgfilter.py` (the wording pass over
every message), `k-hunks.py`, `k-basetree.sh`, `k-filepatch.sh`, `k-scrub.py` (tools used to cut the patches).

## 1. The stack

The stack `w19-traits-v3-head` (a168645b2e; `w19-traits-v3`, 515923d3eb, has the same tree, its T16a and T16b before the fix below) on v1.13.2: **68 commits, 85 files, 13,320 lines added, 659 removed**
(`logs/k-series.tsv`). Its parts:

- **G, `w19-stack-v3`** (4365ea8679): `w19-stack-v2`'s 24 patches (`up/01` to `up/18`, `up/20` to `up/25`) and
  **`up/27`** (row 183: `_promote_typesubtract` and `fieldname`'s error path `@nospecializeinfer`, inferred at the
  instance that runs; standalone branch `up/27-promote-typesubtract-once` 05a669aa46 on v1.13.2, 3 files, +13 −3,
  test in `test/reflection.jl`). The messages of `up/20`, `up/22`, `up/25` no longer name other branches.
- **F**: `w19-facts-tests-v2`'s 16 commits cherry-picked on G. F7 no longer carries the `!==` clause, which G's
  `up/20` holds: its message drops that bullet; its test of a `!==` method in `test/worlds.jl` stays (it needs S1).
  Then the dispatch profiler's call site (E7) and **row 179** (`callsig_splits`), with the sixth part's test fix
  (16b) folded in: it follows the facts series, whose constant it reads (`traits-v3/00-callsig-union-split`).
- **T**: the 25 parts below, each with its rows; T16 in three. The sixth part's additions 10a (row 181) and 10b
  (rows 175 to 180 and 179) are gone from between T10 and T15: row 181 is in T1, rows 175 to 180 are G's.

### Where each row went

| Row | `next` | Part | How |
|---|---|---|---|
| 181 (the bit sees a lower bound) | bfaf484f55 | T1 (C), T2d (its testset) | the witness is T1's; the testset needs sets. With row 192 the testset's caller asks `A <: B` at the top, where a membership counts, not `Vector{A} <: Vector{B}`, which is false in every world now |
| 182 (a positive records the entries of both sides) | 21a9652b44 | T6 | `jl_membership_entries_for` is T6's; adapted to the series' comment |
| 183 (`_promote_typesubtract`, `throw_field_access` once) | d1e64d8b56 | `up/27` (G) | general |
| 184 (absence worlds) | dd42dc8c3f | T7 | already there (fifth part) |
| 185 (`jl_could_join`: Vararg tail, `Type{S}`, a declared supertype) | 461605c7f2 | T2d | adapted by hand (the series' comments) |
| 186 (taken back: an instance with no code) | 04bafd8f52 | T5 | as is |
| 187 (an unfolded set answer is not consistent) | edb0e3dcae | T7 | its `new` hunk needs T6's frame form, its `typeutils.jl` context T7's absence edge |
| 188 (`jl_subtype_via_membership`: Vararg tail, a declared supertype) | 2ddbe12394 | T2d | adapted by hand |
| 189 (a match at a kind: the type-value entries' worlds) | 86cc20d662 | T7 | needs `open_sets_in` (T6); written by hand on top of row 190's T5 form |
| 190 (methods with a lower bound replayed) | aa362a2ddd | T5, the replay signatures' hunk T9c | the walk, the index, the match worlds in T5 (written by hand: no implements check before T6, which T6's pick adds; no kind clause before T7); `jl_membership_replay_sigs` is T9c's |
| 191 (a choice at a set not consistent; `hasmethod`'s negative) | 9970f8799a | T7 | needs `MethodLookupResult.cells` (T7) |
| 192 (`noentry_depth`) | 3c7394979a | T2b | adapted by hand (no `entryinst` before T3) |
| 193 (an image's methods asked in their world) | 054016ea75 | T8 | as is |
| 194 (an entry at every instance meets a method's instance) | d7b373bf92 | T5 | as is |
| 195 (a type in a pattern bounded by a set is no final non-member) | 3e9c193025 | T14 (the kept forms' pattern, as the brief places it) | written by hand into the series' `jl_membership_final` (no loaded marks) |

The rows' comments lost the references' section numbers and work items (`k/k-scrub.py`). Where the brief named
another part (the entries' collection and the shortcuts in T2b/T2c), the code is made later: `jl_could_join` and
`jl_subtype_via_membership` in T2d, `jl_membership_entries_for` in T6; the rows follow the code.

### The testsets the rows add

Each audit gate's cases (`gates/n37` to `n48`) as testsets in plain style through the runtime's entry points
(`jl_set_open_set`, `jl_declare_membership`, `jl_delete_membership`), in the part that carries the fix
(`k/k-tests/`). Each fails on the sixth part's S3 build (2ee6d6876e, which lacks rows 182 to 195; rows 185 and 187
stop the process at a typeassert folded to `unreachable`, as their gates say) and passes on `next` 3e9c193025
(`k/k-rowtests-w19-julia-s3.log`, `k/k-rowtests-julia-next.log`, `k/k-imagetest.jl`):

| Part | Testset (`test/subtype.jl` unless named) | Gate |
|---|---|---|
| T2d | "a set in a type variable's lower bound"; "a negative at a Vararg tail, at Type{S} and at a declared supertype's parameter"; "a variable bound inside an invariant parameter compares its bounds with no entry" | 10a's, `n39` (negatives), `n45` |
| T5 | "a positive at a Vararg tail and at a declared supertype's parameter, taken back"; "a membership taken back ends the callers of an instance with no code"; "a membership replays the methods whose lower bound the member meets" (declared, taken back, a path of two); "a membership at every instance reaches a method at one instance" | `n39` (positives), `n40`, `n43`, `n47` (with a set of the test's own: `Callable` comes in T12) |
| T6 | "a positive answer through entries records the entries of both sides" (and taken back) | `n38` |
| T7 | "an answer about a set that inference does not fold is not consistent"; "a match at a kind holds only while the set's entries for type values do"; "a choice among methods at a set, and `hasmethod` at a set, are not folded" | `n41`, `n42`, `n44` |
| T8 | `test/precompile.jl` "memberships in package images": two packages more, an image that declares a set a member of another | `n46` |
| T14 | "a type in a pattern bounded by a set is no final non-member" | `n48` |

`n37` (row 184) has its case in T7's earlier testsets ("memberships compose", "a membership taken back").

## 2. T16 cut in three

`k/k-t16-cut.py` takes T16's tree and works backwards: (c) the whole, (b) without the check in a session and the
verifier, (a) without the closed splits. Each compiles on the one below (`make -C src`; only T16a changes C) and
parses; every name a part's Julia code calls is defined in its tree (a scan of `closed_*` and `CLOSED_*`).

| Part | Branch, commit | Subject | Size | What |
|---|---|---|---|---|
| T16a | `traits-v3/16a-closed-members-v2` 40da8b5149 | Compiler: a closed build counts a set's members by use, in rounds | 6 files, +800 −37 | `CLOSED_OUTPUT`, `closed_build`, the members by use (`closed_note_used!`, `note_used_type!`, `note_closed_flow!`, `closed_candidates`, families, `closed_entry_free`), an operation's split over every member (`operation_split_type(atype, closed_rules)`, `SplitCallInfo.closed`, no table), the rounds in `typeinf_ext_toplevel` with the callers inferred again, `jl_set_enumerable`, `jl_set_member_patterns`, `JULIA_CLOSED_BUILD_REPORT` |
| T16b | `traits-v3/16b-closed-splits-v2` 0bfa5f620d | Compiler: a closed build branches over a set's members | 2 files, +466 −5 | `closed_member_split` with the static-parameter, wrapper and choice bits, the forwarders, `closed_bound`, `closed_callable_split`, `closed_set_signature` (the inliner), the `Callable` kind of a split |
| T16c | `traits-v3/16c-closed-check-v2` a168645b2e | Compiler: a closed build's check in a session, and its verifier | 7 files, +208 −25 | `closed_check`, `ClosedCheck`, `NativeInterpreter`'s `closed` and `overlay_table`, `method_table` reading the overlay, the build's queue following an invoke that names its instance (`MAX_NAMED_INSTANCES`), the verifier's policy check |

**The first cut did not build:** T16a's system image stopped in the compiler's bootstrap (`FieldError: FailedMethodMatch has no field valid_worlds`, build 2): the removal of T16b's lines in `abstract_call_gf_by_type` took out the `isa(matches, FailedMethodMatch)` return that sits between them. Fixed in the cut script; the pushed `traits-v3/16a-closed-members` and `16b-closed-splits` are that first cut, the `-v2` branches the fixed one (the trees of T16c are equal). **Hand-made in the cut:** `closed_build`
and `closed_process` take no `NativeInterpreter` method before T16c; `abstract_call_gf_by_type`'s keywords
`member_split` and `closed_bound` come with T16b (T16a keeps `max_union_splitting`, which its operation split
uses); `split_fallback_table(…, closed)` and `handled_all_cases` for a closed split are T16a's, `handle_call!`'s
`Callable` kind T16b's; `closed_kept_form` stays in T16a, which `closed_record_family` reads.
`closed_build_reinfer!` and `closed_invalidate_callers!` keep their `owner` argument (`nothing` before T16c).

**A defect of the sixth part's T16, found while cutting:** `method_table(interp::NativeInterpreter)` did not read
the check's overlay (`next` has `function method_table(interp::NativeInterpreter); ot = interp.overlay_table; …`),
so `closed_check(mis, world, overlay)` built the overlay table and never used it. T16c has the final tree's form.
Three of T16's comments still carried the scrub's leftovers ("(compiler\n# )", ", :"); `src/datatype.c` had a
comment of `jl_candidates_of` above `jl_set_enumerable` and two section numbers: fixed in T16a.

## 3. Testsets for T11 to T17

| Part | Testset | From |
|---|---|---|
| T15 | `test/subtype.jl` "an operation's result is checked where the member's code does not check it" (declared result inferred, the `trusted` effect set, a member's method redefined to `UInt` raises `TypeError` through the trait, a dynamic call returns it) | `n22`'s assertion |
| T11 | `test/subtype.jl` "an operation's call split over its set's candidates, and the table past them" (candidates in declaration order, the first four tested in the optimized code, the fifth through the table) | `n22` |
| T12 | `test/subtype.jl` "Callable{A, S}" | `n8`, `n14` |
| T13 | `test/show.jl` "IO's contract and IOContext{IO}" | `n19` |
| T14 | `test/subtype.jl` "the kept forms Dynamic{X} and Compiled{T}" (ordinary structs; an argument `@nospecialize(x::P{T})` compiled at `P{Int}`; `jl_set_erases`; `jl_open_set_methods_of`) | `m1_no_wrappers`, `n33` |
| T17 | `Compiler/test/inference.jl` (the interpreter infers a method, calls the hook at each known call, leaves no code in the session's cache) | the library's use |
| T16c | `test/subtype.jl` "a closed build's check: the members of a set are those the program has" (a concrete member and the one instance of a family the program uses); `Compiler/test/verifytrim.jl` (an invoke resolved by its code or its instance's code of the policy asked, refused for the other policy only) | `n34` |

`test/trimming` does not run here: its first step is `Pkg.instantiate()` with a registry (offline). The testsets
pass on `next` (`k/k-tests-standalone-next.log`) and on the head (Base's tests below).

## 4. The head

Built as `w19-traits-v3-built` 9a25e86ff3 (build 1); the pushed head a168645b2e differs from it in six comment
lines (`src/gf.c`, `src/datatype.c`) and one test line (below), and was checked out on the built binary for the
rerun of `Compiler/inference` and everything after the gates.

- **The gates** (`run_all.sh`, `logs/k-gates-head.log`): **84 of 87 pass, the 9 stage gates pass.** `n38` passes now
  (row 182). `n16`, `n18`, `n20` read `Method.declared_covers` or call `jl_set_closed_after_load` and
  `jl_module_is_loaded`, which the series does not make; their copies `gates/i-n16`, `i-n18`, `i-n20` pass on the
  head (`logs/k-gates-copies-head.log`).
- **Base's tests** (`logs/k-tests-head.log`): `subtype`, `core`, `worlds`, `reflection`, `Compiler/inference`,
  `Compiler/invalidation`, `Compiler/effects`, `Compiler/verifytrim`, `facts`, `show`: 7,828,647 pass, 78 broken,
  1 error: `up/20`'s test asked `only(methods(!==))`, and `test/worlds.jl`, run before it in the worker, defines a
  method of `!==` (F7's test). The test now asks `which(!==, Tuple{Any, Any})` (`up/20` in `w19-stack-v3`; the
  standalone branch `up/20-noteq-once` keeps the old line); `Compiler/inference` then passes, 1,862 pass, 10 broken
  (`logs/k-tests-head-inference-rerun.log`). `precompile` alone: 469 pass (`logs/k-tests-head-precompile.log`).
- **The library's suite** (TraitWorld 0f54043, read only, as a file): 120 testsets, exit 0
  (`logs/k-traitworld-head.log`). **The examples:** `intro.jl`, `tutorial.jl`, `strict.jl` exit 0
  (`logs/k-examples-head.log`).
- **The trimmed programs** (`k-mbuilds.sh head`: `w166/build_c.sh` with `JULIA_TREE=wt/w19-julia`, depot
  `agent-depots/w19`; `logs/k-mbuilds-head.log`): table, report, plot, ode: **0 errors each**, each binary's output
  equal to a session's, the PNGs equal.
- **The set-folds report** (the tool as it stands in the working tree, with the third part of W-171's new shapes, a
  snapshot not committed by that work): stub mode 557 cases, 189,704 checks, 7,982 mismatches in 847 groups;
  library mode 551 cases, 185,352 checks, 7,966 in 858; image mode 1,409 checks, **0 mismatches**. **The same tool on
  `next` 3e9c193025 gives the same counts and the same groups** (`logs/k-folds-*-next-control.log`): the mismatches
  are W-171's open shapes (`redeclared`, `deep9`, `mrs` …), not the series'.
- **The nine loads** (`f-loads.sh`, unchanged; `logs/k-loads-head.log`; a warm-up and 2 runs per cell, load 4.1–5.2):
  by facts **14 of 3,490** own image instances lost (G2 2,799), plainly 426 of 4,694 (G2 2,673); the work after the
  loads (A) **1.39 s by facts against 5.38–5.40 s**; order B 2.45–2.53 s against 6.21 s. Digests equal.
- **What plain code pays** (no set declared; one thread):
  - micro-timings (`motiv/h-micro.jl`, `logs/k-micro-head.log`, `logs/k-micro-head-vs-next.log`, ns per call,
    minimum of 7 rounds, two rounds; vanilla / `next` 3e9c193025 / the head): `jl_subtype` 238–241 / 274 / 263–265
    (+11 %); `jl_type_intersection` 278–279 / 322–323 / 315–318 (+14 %); the type cache 77 / – / 81 (+5 %);
    **method matching 179 / 204–208 / 216–221 (+21 %)**, where the sixth part's head paid +8 %: rows 189 and 190
    ask each method a lookup visits for a kind in the query and for entries at its lower bounds
    (`jl_type_has_kind`, `jl_sig_lower_bounds_have_memberships`, in the typemap's visitor and `ml_matches_visitor`).
    `next` pays +15 % there; the head's other 5 % are the series' forms of `ml_matches` (the earlier parts' wrapper
    `ml_matches_c`). A tension of GT-9's kind, grown by the audit's rules;
  - the plain session (`motiv/f-plain.jl`, upstream CSV and DataFrames plainly, a warm-up and 3 runs interleaved,
    load 3.8–4.0; `logs/k-plain-head.log`): `using CSV, DataFrames` 671–674 ms against 648–657 ms (runs 2 and 3; the
    first runs 745–748 ms both), +3 %; the first work 4.44–4.45 s against 4.43–4.44 s; digests equal.

### The head against `next` 3e9c193025

`git diff --stat 3e9c193025 a168645b2e` (`logs/k-head-vs-next.txt`): 73 files, 3,349 lines added, 2,297 removed. The
kinds of the sixth part's account, and what changed in them:
- **the series' tests**: 10 files under `test/` and `Compiler/test/`, 1,412 lines (the sixth part 919): the rows'
  testsets, those of T11 to T17, `up/27`'s in `test/reflection.jl`;
- **comments**: the series' wording, without the references' section numbers, work items or experiments;
- **plan §5's removals** (nothing reads them): `closed_after_load` and its functions, the modules' loaded marks,
  `Method.declared_covers`, `membership_walk_invalidates`, `membership_prune`, each function's list of methods at
  sets, `JULIA_DEBUG_EXTERNAL_CIS`'s counters, row 137's casts;
- **the earlier parts' forms**: `ml_matches_c`, `is_implements_sig`, functions placed in another order in
  `datatype.c` and `gf.c`, an `if` written as `||`.
Nothing of rows 182 to 195 is missing: `git diff w19-traits-v2-head <head> -- src Compiler/src base` against
`git diff 8884715703 3e9c193025` (the rows on `next`) differs in comment lines only (the series' wording), but for `method_table` reading the overlay. And the one hunk of the
final tree the sixth part's series lacked, `method_table` reading the overlay, is in T16c.

## 5. The static check of the collectors' roots

`w163/sagc.sh julia-next wt/w19-julia` (the tool tree's clang and plugin; the files `next` changes, the head's
code): **15 files, 0 findings** (`logs/k-sagc-head.log`; `ast.c`, `builtins.c`, `datatype.c`, `gc-stock.c`, `gf.c`,
`init.c`, `interpreter.c`, `jltypes.c`, `method.c`, `module.c`, `staticdata.c`, `subtype.c`, `task.c`, `toplevel.c`,
`typemap.c`). The `.cpp` files (`analyzegc`) were not run.

## 6. The wording

- **Subjects:** 43 subjects shortened to Julia's length (at most 80 characters, most under 72), the detail kept in
  the body (`k/k-msgfilter.py`, `SUBJECTS`).
- **Names a reader does not know:** the first mention of the design's gates in a message says "outside Julia's
  suite, the design's gate …"; `up/03`, `up/19`, `up/20` named by what the patch does; "the facts series" in G's
  `up/20` and S3, "the fourth part's rule", "the gates the earlier part left out", "not gated" reworded; E-364 and
  E-510 out of T16a and T16b.
- **Comments:** `(M6 replays them)` and `(open issue 189: …)` in T5's walk; four section numbers and "the library,
  compiler §10.4" in T11's and T14's `datatype.c`; T16's leftovers (above); "a caller kept over an equal result (the
  code slot)" names a mechanism the series does not have.
- What is left as it was: the series' structure in the messages ("the second of four parts"), the gates named in the
  Test lines of F2 to F8 and T11 to T16 beside Julia's tests (they need a trait library or are not in Julia's
  suite yet).

## 7. Builds (seventh part)

PARTS_TABLE

## 8. The whole series

SERIES_TABLE

## 9. Where the plan was wrong or incomplete (seventh part)

- **Row 183 is general**: `up/27`, not a traits row.
- **Rows 185 and 188 are T2d's, 182 T6's**: the functions they change are made there, not in T2b or T2c.
- **Row 190 spans three parts**: the walk and the match worlds (T5), the replay signatures (T9c, strict mode's), and
  its kind context (row 189, T7). Its index entry needs T6's implements check, which T6's pick adds.
- **The sixth part's T16 lacked `method_table` reading the overlay** (above).
- **Method matching pays +21 %** at the head, against +8 % at the sixth part's: the audit's rows 189 and 190 (GT-9).
- **T16's cut** is 800, 466 and 208 lines added, not the plan's 550, 600 and 270: the members by use carry the
  operation split and the rounds' bookkeeping; the check is small once the verifier's lines are counted with it.

## 10. Not done, not verified (seventh part)

NOT_DONE
