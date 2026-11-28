
# Eighth part: the series follows `next` 7fdfa7e0f8, every part built alone

The main session alone (2026-11-28; the user: "Continue with the work, one item at a time. Do not use any subagents
this round."). The seventh part's handover: rows 196 to 203 into the series; the parts not built alone, built; the
method-matching cost into the open issues; the inventory §5 and the plan. And what W-171's fourth part added on
`next` meanwhile: rows 204 to 208, and row 209 (below, §3).

## How to run (eighth part)

```
python3 l/amend-msgs.py                    # as a rebase's `exec` after each pick: the parts' messages for the rows
<tree>/julia l/run-tests.jl [file ...]     # the rows' testsets standalone (l/tests/, with subtype.jl's helpers)
TREE=<tree> bash l-queue.sh l-queue-<x>.txt  # a lane of parts built alone (l-parts.sh: build, Base's tests, gates)
python3 l/parts-table.py                   # the table of §4 from logs/l-part-*.log
bash k-run-head.sh <tag> [steps]           # the head's checks (as in the seventh part)
bash k-mbuilds.sh <tag>                    # the four trimmed programs on wt/w19-julia
```

## 1. The rows in the series

The seventh part's restack tool (`k/k-restack.py`) rebuilds the stack from `steps-v3.txt`; here the rows were carried
by history instead, in four steps in `wt/w19-patch`:

1. **The rows on the old head.** Each of `next`'s commits 20d5c1eaed to ba98f879c5 (rows 196 to 208) cherry-picked
   onto `w19-traits-v3-head` (branch `w19-v4-rows-raw`), the conflicts resolved by hand in the series' wording; then
   the comments scrubbed of the references' section numbers, each scrub folded into the row that wrote the line
   (by blame; branch `w19-v4-rows`, the target tree).
2. **Each row into its part** by a rebase with the rows as fixups (`git rebase -i` with a written todo): a row goes to
   the part that makes the functions it changes (by `git log -S`/`-G` over the series).
3. **What a row needs from a later part** was left out at its part's step and folded into that part in a second
   round: `may_intersect` at `Callable`'s argument test (row 200) into T12; row 197's drop at a member of a pattern
   bounded by a set, which reads row 195's `jl_chain_has_set_bounded_pattern`, into T14.
4. **The testsets** (§2) and the parts' messages (`l/amend-msgs.py`), each as fixups and a rebase.

The head's tree equals the target tree but for the place of `may_intersect`'s definition in `typeutils.jl` and the
wrapping of one comment.

| Row | `next` | Part | How |
|---|---|---|---|
| 196 (the walk replays the patterns bounded by a set) | 20d5c1eaed | T5 | `membership_bounded_patterns` beside the walk; `jl_membership_replay_sigs`, T9c's, follows in row 205 |
| 197 (a lookup at a set records its drops' absences) | 79e9f3321a | T7, its clause at a bounded pattern T14 | `ml_matches_dropped`, `drop_cells` need T7's absence signatures |
| 198 (a listed interference asked again in the query's world) | 9c12940b58 | T4 | where the interference clause for sets is made |
| 199 (past the walks' depth; a lower bound with parameters) | 268aef4b91 | T5 | `sig_places_past_depth`, `lower_bound_meets` placed before T5's `index_lower_bound_method` (the series has no per-function list) |
| 200 (a builtin's check is no proof about a set) | f708a0171a | T2d, its `Callable` site T12 | `may_intersect` beside T2d's `negative_fold_blocked` |
| 201 (a union's nesting is no depth) | e45b5b4198 | T5 | with row 199 |
| 202 (an unproved store test is not consistent) | 20730dea1c | T7 | with row 187 |
| 203 (a declaration's walk before the counter advances) | 0bbd759c13 | T5 | the counter's store moved after the walk in T5's and T6's forms |
| 204 (an image's activation walked before its world is published) | 196b8e344a | T8 | |
| 205 (the replays name the patterns bounded by the set) | 52a9913232 | T9c | |
| 206 (a lookup asks a lower bound's entries only of a marked method) | 545349d2e2 | T5 | the mark is a field of its own, `Method.sig_lower_bound`: `next` keeps it in `Method.declared_covers` bit 2, a field the series does not have (plan §5) |
| 207 (a listed interference between closed signatures read from the list) | 726ef30981 | T4 | with row 198 |
| 208 (an opaque closure's test about a set) | ba98f879c5 | T7 | needs `names_open_set` (T7) |
| 209 (the static check's three places) | 7fdfa7e0f8 | T5 (rows 196, 199), T7 (row 197) | §3 |

## 2. The rows' testsets

The gates of the rows as testsets in Julia's `test/subtype.jl`, in the plain style of the earlier rows (`@set`,
`member!`, `jl_delete_membership`), in the part that carries the fix (`l/tests/`). Each file passes on `next` and
fails on a build without the rows (`wt/w143-julia` d1e64d8b56; `l/run-tests.jl`):

| Part | Testset | Gate |
|---|---|---|
| T2d | "a builtin's check by an empty intersection about a set is no proof" | `n54` (its builtins) |
| T4 | "a listed interference is asked again in the query's world" | `n52` |
| T5 | "a membership's walk replays a pattern bounded by the set", "the walks reach past their depth and below a lower bound's top" | `n50` (at a pattern of the test's own: the kept forms come in T14), `n53` |
| T7 | "a lookup at a set records the pairs whose absence dropped a method", "a store's test about a set that inference did not prove is not consistent", "an opaque closure's call decides its test about a set only with a record" | `n51`, `n54` (its store), `n58` |
| T9c | "what a membership would replay names the patterns bounded by the set" | `n57` (at a pattern of the test's own) |

Not as testsets: `n55` and `n56` (races between threads, by their nature not a deterministic test) and `n49` (the
report's slice: a tool, not a case).

## 3. Julia's static check of the collectors' roots

On the head with rows 196 to 208 the check (`w163/sagc.sh`) finds **4 places in `gf.c`, all of the audit's rows**,
and `next` ba98f879c5 the same (`logs/l-sagc-head.log`): a union's component passed unrooted (`lower_bound_meets`,
row 199); the walk over the patterns bounded by a set re-reading the entries' table inside its loop, where the outer
loop could then read a table it did not test (row 196); a lookup's drops read where `cells_out` may be NULL (row 197,
twice; the drops are collected only where it is given). The audit's merges into `next` ran no static check. Fixed on
`next` (7fdfa7e0f8, row 209) and folded into T5 and T7; the check then finds 0 on `next` and on the head (15 files;
`logs/l-sagc-v5.log`, `../w171/logs/sagc-next-7fdfa7e0f8.log`). The playbook's list of checks says it for a merge.

**The C++ files** (`codegen.cpp` with `cgutils.cpp`, `engine.cpp`, `runtime_ccall.cpp`; `logs/l-sagc-cpp.log`):
`engine.cpp` and `runtime_ccall.cpp` 0. `codegen.cpp` 107 findings on `next` and 107 on vanilla with the same
analyzer, 104 equal by file, message and source line and the other 3 the same calls on lines the design rewrote.
