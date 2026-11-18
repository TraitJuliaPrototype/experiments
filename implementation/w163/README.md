# W-163: the crash in dispatch's cache (open issue 234, E-502)

The teaching pages' script `experiments/docs-examples/tutorial.jl` ended with a segmentation fault in 2 of 6
runs on `julia-next` 32a2235abd: `jl_object_id` of the key a dispatch looked up in the leaf cache
(`apply_generic_reach` → `jl_lookup_generic_` → `jl_mt_assoc_by_type` → `lookup_leafcache`,
`docs-examples/logs/tutorial-next-32a2235abd-b-segfault.log`).

## The fault

`jl_lookup_generic_` (gf.c) makes the call's tuple type with `arg_type_tuple` and holds it in a C local
only. Vanilla Julia does the same and is sound: it reaches `jl_mt_assoc_by_type`, which roots the type,
with no allocation in between. The design put `member_hook_at_dispatch` (the member hook at dispatch,
compiler §10.4; commit ec4f9a8714 on `trait-world-1.13`) between the two. It allocates (a method lookup)
and runs the library's hook (Julia code). A tuple type with a `Type{…}` parameter is not concrete, and
Julia's type cache holds only tuples of concrete types (`Tuple{typeof(f), Type{Int}, X}` is a fresh
object at each `arg_type_tuple`). A collection in that window freed it; the lookup that followed hashed
freed memory. The key `lookup_leafcache` hashed (iddict.c:118, `keyhash(key)`) is the looked-up type
itself, not a key stored in the cache: the cache was sound, its query was not.

Why it was rare: the hook's method match usually holds the same object (`spec_types` is the tuple type
itself when it is a subtype of the method's signature), and the match is rooted while the hook runs. The
window is a collection inside the method lookup, before the match exists.

## The pattern

**A value a C function makes and holds unrooted, because no allocation follows before it is rooted, and a
call that allocates or runs Julia code (a hook) inserted into that window.** Its relatives, which the same
tool finds: a fresh value passed as an argument to another allocating call (`jl_svec(…, jl_box_ulong(w))`);
a local read from a cache or a list that the analyzer cannot see is rooted; a global holding a heap value
that no root list names.

## The tools

| Tool | What it finds | How to run |
|---|---|---|
| `sagc.sh` | Julia's static check of GC roots (the clang static analyzer with `src/clangsa`'s GC checker, as `make -C src clang-sagc-<file>` runs it), over every runtime `.c` file the design changed, in any tree | see below |
| `roots.sh` | every global annotated `JL_GLOBALLY_ROOTED` in the changed files, and whether a root list names it; file-scope heap pointers without the annotation | `bash roots.sh <julia tree>` |
| `gc_in_hook.jl` | the fault's case, with a full collection in the member hook; deterministic under the stressed collector | from `TraitWorld/`: `<julia> --project=. --startup-file=no ../experiments/implementation/w163/gc_in_hook.jl` |
| `repro.sh` | one of the teaching pages' scripts N times, one process at a time; counts faults | `bash repro.sh <julia> <label> <N> [script]` |

**`sagc.sh`.** Needs a built tree with the analyzer's dependencies once:
`make -C <tree>/src install-analysis-deps clangsa` (downloads the Clang JLL of the tree's LLVM; the
plugin is built with the host's gcc). Then `bash sagc.sh <tool tree> <tree to check> <log> [files]`. A tree
that is not built (vanilla, an older commit) needs the four generated files in its `src/`
(`julia_version.h`, `jl_internal_funcs.inc`, `jl_data_globals_defs.inc`, `julia_flisp.boot.inc`), copied from
a built tree of the same version. The `.cpp` files run with `make -C <tree>/src analyzegc`
(`codegen.cpp` and `rtutils.c` are skipped by Julia's Makefile). gf.c takes about a minute; all files
about ten. The analyzer stops a path at its first finding, so a second run after fixes can show more.


**`window_gc.patch`** (a diagnostic, never committed to the julia branch): applied to `src/gf.c` of a tree
built with `WITH_GC_DEBUG_ENV=1` in `Make.user`, and run with `W163_GC_IN_WINDOW=1`, the runtime makes a
full collection at the start of `member_hook_at_dispatch`, inside the fault's window, at every call that
reaches it, and prints whether the call's tuple type survived. `window_case.jl` is the smallest case; the
three example scripts, the library's suite and the gates are the wide ones.

**A stressed collector.** `WITH_GC_DEBUG_ENV=1` turns on the collector's verification at every
collection and its scrub (an unmarked object the C stack points to is overwritten with 0xff, so a use
faults at once). `JULIA_GC_ALLOC_OTHER=min:interval` forces a collection every `interval` allocations
of the runtime (in this version `JULIA_GC_ALLOC_POOL` is read but unused: both kinds of allocation
count under `OTHER`). `gc_in_hook.jl` sets the same counter from Julia (`W163_STRESS=N`) around its calls.

**Building the variants without a full build.** Only `libjulia-internal` differs: `make -C src
libjulia-internal-release` after deleting the objects of `src/`'s SRCS (seconds at -j16), the library
copied into a directory of symbolic links to the tree's `usr/` (`bin/julia` a copy, `lib/` links but for
`libjulia-internal*`, and `share`, `tools`, `libexec`, `etc`, `include`). The tree's own build is
untouched for the checks.

## The findings of the static check, with a verdict each

The first pass over 768850cff7 (32a2235abd made to compile under clang; `logs/sagc-768850cff7-before.log`):
24 findings in builtins.c, datatype.c, gf.c, method.c, subtype.c; two more in the second pass, once the
first were fixed (25, iddict.c's `jl_eqtable_put` through builtins.c; 24b). The commit a5bd871cce says
"one more": 24b was annotated in it too. Vanilla 45b6d15e34, the same 15 files: 0
(`logs/sagc-vanilla-45b6d15e34.log`). After a5bd871cce: 0 (`logs/sagc-a5bd871cce-after.log`). Lines are
768850cff7's. The iddict.c entries of the two older logs are the tool's mistake of the time (an included
file checked alone), since excluded.

| # | Place | The value | Verdict | Done |
|---|---|---|---|---|
| 1 | gf.c:7459 `jl_lookup_generic_` → `member_hook_at_dispatch` | the call's tuple type from `arg_type_tuple`, across the hook's method lookup and the hook | **the fault** (E-502): freed when it has a `Type{…}` parameter | rooted by the caller across the call |
| 2 | gf.c:604 `jl_type_infer_policy` | inference's CodeInstance across the compile queue's drain (runs the hook) | **real**: a CodeInstance not cached has no other root | the drain runs inside the frame |
| 3 | builtins.c:1134 `attributed_call_reach` | `jl_box_ulong(world)` passed to `jl_svec`, which allocates first | **real** | boxed and rooted before |
| 4 | gf.c:2960 `invalidate_code_instance` | `deep_ending_cause`: a file-scope global no root list named | held elsewhere in practice | the two globals annotated and rooted for both collectors |
| 5–9 | gf.c:3651, 4193; datatype.c:805, 1397, 1398 | the old cause and kind kept in callers' locals across invalidations | held elsewhere in practice | push returns whether it set the cause; pop clears it (the same behaviour, no old values) |
| 10 | gf.c:4035 `jl_method_table_activate` | the method across `index_func_set_method` | held by `newentry` | in the function's GC frame |
| 11 | gf.c:5682 `jl_attributed_mi` | the match's signature and method | held by `matches` | rooted, promised |
| 12 | gf.c:7075 `jl_member_checks_passed_here` | the activated checks' list across pushes | held by `jl_member_states` under the lock | rooted |
| 13 | method.c:1559 `method_def` | the first method of an expansion across the next definitions | held by the method table | rooted |
| 14 | datatype.c:1467 (removing a membership) | the entry found in the member's list | held by the TypeName's list | rooted |
| 15 | gf.c:6872 `chain_has_memberships` | a NULL supertype (the core checker) | a type not yet complete only | the walk ends at NULL |
| 16, 17 | gf.c:3159, 5029 (backedge walks) | the call's signature read from a backedge | held by the backedge list, as vanilla's caller is | promised, as vanilla promises the caller |
| 18 | gf.c:3355 `_typename_invalidate_backedges` | the replayed method | held by the method table | promised |
| 19, 20 | datatype.c:1002 (×2) `jl_unmet_final_cells` | `final_pair_component`'s result | false: reached from its argument | `JL_PROPAGATES_ROOT` |
| 21, 22 | datatype.c:1128, 1212 | `instance_body`'s result | false: a part of its argument, no allocation | `JL_PROPAGATES_ROOT`, `JL_NOTSAFEPOINT` |
| 23 | subtype.c:1411 | an entry passed to `entry_counts` | false: allocates nothing | `JL_NOTSAFEPOINT` (and `jl_typename_reaches`) |
| 24 | datatype.c:567 `membership_absence` | the signature after it is stored in the list | false: the checker moves a root into the svec a value is stored in, then drops it | promised |
| 25 | iddict.c:149 `jl_eqtable_put` (vanilla code; seen through builtins.c, which includes iddict.c) | the table a rehash made | false: its last allocation | promised |
| (24b) | datatype.c:1395 `jl_declare_membership` (second pass) | the `member` argument after `register_candidate` stores it | false: the same checker behaviour as 24 | promised |

Counts: 26 findings. 3 real (one of them the fault), fixed. 14 held in practice by a reference the checker
cannot see: 11 now rooted or restructured, 3 promised as vanilla promises the same reads. 1 NULL
dereference guarded. 8 false (the checker's model), annotated.

**The pattern, named:** *a value held in a C local only, because no allocation follows before it is
rooted, and a call that allocates or runs Julia code put into that window* (1, 2; 3 is its argument-list
form). The design adds such windows wherever it calls the library from the runtime (the member hook, the
compile queue's drain, the definition and expansion hooks): each call site of a hook was read
(`gf.c`: `member_hook_at_dispatch`, `jl_member_queue_drain`'s three callers, `call_library_hook`'s five
callers; `method.c`: the expansion and definition hooks in `method_def`; `toplevel.c`: the module-end
hook; `staticdata.c`: the image hook): every other caller holds its values in a GC frame across the call.

`roots.sh` (`logs/roots-next.log`, `logs/roots-a5bd871cce.log`): every global annotated
`JL_GLOBALLY_ROOTED` in the changed files is in a root list, in an image's lists, or reachable from a
binding (`jl_implements_ft`, Core's `implements`; `jl_split_table_miss_func`, Base's `_split_table_miss!`);
the vanilla ones are vanilla's. Before: two file-scope pointers without the annotation
(`deep_ending_kind`, `deep_ending_cause`); after: none.
