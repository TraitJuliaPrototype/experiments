# W-19: the changes to Julia as small patches for upstream (first part: the patches useful without traits)

The work queue's W-19 (with W-143). The user: "Split all the changes to julia into a set of small, self contained and as orthogonal as possible parts. Each should be easily reviewable by a core developer in isolation."

- **This part:** the changes of the final tree that stand without traits and facts, each as one patch on Julia v1.13.2 (`45b6d15e34`), on a branch `up/<nn>-<slug>` of the julia repository; checked; with what a core developer needs.
- **The plan for the other two series** (facts with ownership; traits): `PLAN.md`. No patch of those series is made here.
- **The source** is the final tree's diff, not the history: `git -C julia-next diff 45b6d15e34 cf0f039f51` (`next` at the freeze `round-2026-11-c`). Each patch is its subject's part of that diff: after the patch, every hunk it touches reads as in `next`, but for the comments, rewritten in plain Julia's terms (no facts mode, no traits). `logs/stack-vs-next.txt` shows it: for the files the patches touch, the stack differs from `next` only by those comments and by the hunks of the other two series.

## How to run

```
source env.sh; export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w19:$TW_ROOT/.julia-depot: JULIA_PKG_OFFLINE=true
git -C wt/w19-julia checkout <branch>; WIDE=0 tools-local/build.sh wt/w19-julia          # one build, about 13 minutes
bash experiments/implementation/w19/motiv/run.sh <tree>                                    # the motivation programs: logs/motiv-<tree>.log
bash experiments/implementation/w19/build_app.sh <tree> motiv/uniq.jl <name>               # P08's trimmed program
<tree>/julia tools/session_check.jl <defs.jl> <test>...                                    # a base/ patch evaluated in vanilla's session
python3 tools/defs_of_patch.py julia-next 45b6d15e34 up/<nn>-<slug> > defs.jl              # its changed definitions
python3 tools/funcsizes.py julia-next 45b6d15e34 cf0f039f51 | python3 tools/parts.py      # PLAN.md's sizes
```

The trees: `wt/w19-julia` (the builds; the branches checked out in turn), `wt/w19-patch` (where the branches were made). The control: `julia-vanilla` (v1.13.2, built on this host).

## The patches

Each branch is one commit on `45b6d15e34`. Sizes: files, lines added and removed. *Checked*: **stack** (built with all 18, Base's tests below pass), **alone** (built alone, its test), **session** (its changed methods evaluated into vanilla's Base in a session, the test files run there). The motivation's numbers are the stack's against vanilla, the same hour, one fresh process per row (`logs/motiv-w19-julia.log`, `logs/motiv-julia-vanilla.log`): on the stack every patch is present, and each probe reaches the code of the patch named by its construction.

| # | Branch, commit | What | Size | Checked | Test | Motivation (vanilla → with the patch) | Risk |
|---|---|---|---|---|---|---|---|
| P01 | `up/01-reinterpret-padding-typed` 3b44382cc6 | `reinterpret`'s padding helpers (`padding`, `CyclePadding`, `array_subpadding`, `packedsize`) call type functions by `invoke` and builtins; a helper `padding!` | 1 file, +30 −15 | stack; session (`reinterpretarray` passes) | `test/reinterpretarray.jl` | `Base.sizeof(::Type{W19A})` invalidates 413 → 377 instances | none known: the results are the same; `padding!` is a new internal function |
| P02 | `up/02-introspection-getfield-invoke` d5c8212554 | the introspection helpers (`unwrap_unionall`, `isvatuple`, `unwrapva`, `isabstracttype`, `datatype_alignment`, `datatype_npointers`, `datatype_fieldcount`, `fieldcount`, `fieldcount_noerror`) read fields with `getfield` and call each other by `invoke` | 2 files, +29 −22 | stack; session (`reflection`, `tuple` pass) | `test/reflection.jl`, `test/core.jl` | with P03: `Base.getproperty(::Type{W19B}, ::Symbol)` invalidates 4,977 → 4,137; a package's `unwrap_unionall` method: 2,142 → 2,142 (its callers outside the helpers) | a package's method of these internal functions for its own type is no longer called from inside them (intended) |
| P03 | `up/03-typejoin-getfield-invoke` d46c05472e | the type joins (`typejoin`, `typesplit`, `tailjoin`, `full_va_len`, `promote_typejoin`, `_promote_typesubtract`, `rewrap_unionall`, `supertype(::DataType)`) read fields with `getfield` and call each other by `invoke` | 3 files, +47 −41 | stack; session (`tuple`, `missing` pass) | `test/core.jl`, `test/tuple.jl`, `test/missing.jl` | `Base.typejoin(::Type{W19D}, ::Type{W19D})` invalidates 1,938 → 850 | **behaviour:** a package that adds a `typejoin` method for its own types is no longer consulted for the joins of their parameters inside `typejoin` (a `Tuple{MyA}` with a `Tuple{MyB}`); whether a registered package does this is not checked |
| P04 | `up/04-error-paths-concrete` d54e658a82 | `throw_inexacterror` takes `::Type{T}`, `DomainError` and `string_index_err` specialize on the message and the string, the three-argument `TypeError` is an inner constructor | 2 files, +10 −5 | stack (`core`, `int`, `strings/basic` pass) | `test/core.jl`, `test/int.jl`, `test/strings/basic.jl` | `Core.InexactError(::Symbol, ::Type{W19I}, v)` invalidates 16,092 → 1 | one specialization of `throw_inexacterror` per reported type (each `@noinline`, a throw); an override of `throw_inexacterror(::Symbol, to, val)` (CUDA's comment) must take `::Type{T}`; CUDA's own override already does (not checked here) |
| P05 | `up/05-yieldto-setfield` 38161da7e9 | `yieldto` sets the result with `setfield!`, as `schedule` does | 1 file, +1 −1 | stack; session (`channels` passes) | `test/channels.jl` | none in plain Julia (no legal method intercepts `setproperty!(::Task, …)`); the facts mode's census: `yieldto`'s 1,029 cones (E-477) | none |
| P06 | `up/06-val-new` b2ef2c8653 | `Val(x)` and `Val{x}()` are inner constructors that build with `new{x}()` | 1 file, +4 −2 | stack (`core` passes) | `test/core.jl` | `(::Type{Val{W19G}})()` invalidates 2,004 → 0 | a method `(::Type{Val{MyT}})()` is no longer called by `Val(MyT)` (intended: such a method was already ambiguous in meaning) |
| P07 | `up/07-iocontext-property-invoke` 5cc68adcba | `IOContext(io, key => value)` stores the property through `ImmutableDict`'s constructor by `invoke` | 1 file, +4 −1 | stack (`show` passes); the session's `show` fails with or without the patch (the harness) | `test/show.jl` | `ImmutableDict{Symbol,Any}(::ImmutableDict, ::Symbol, ::W19H)` invalidates 398 → 76 | a package's `ImmutableDict` constructor for its own value type is bypassed there (intended) |
| P08 | `up/08-issorted-specialize` fca372bbd1 | `issorted`'s keyword body specialized on `lt` and `by` | 1 file, +3 −1 | stack (`sorting` passes); session (`sorting` passes) | `test/sorting.jl`; `motiv/uniq.jl` trimmed | the trimmed `unique!` of a `Vector{String}` (`motiv/uniq.jl`): 12 verifier errors (does not build) → 0, 1,817,144 bytes, runs | one compiled keyword body per (`lt`, `by`) type pair instead of one |
| P09 | `up/09-reflection-interp-world` 3bfc817943 | reflection with an explicit `NativeInterpreter` runs the compiler in its world | 1 file, +4 | stack; session (`reflection` passes) | `test/reflection.jl` | not measured: a case that invalidates the compiler's code and then reflects with an explicit interpreter was not built | none known |
| P10 | `up/10-bootstrap-return-type` 2a634bcd17 | `_return_type(::NativeInterpreter, ::DataType)` a bootstrap entry of the compiler | 1 file, +5 −1 | stack | `Compiler/test/inference.jl` | **none measured on v1.13.2:** the first run-time `return_type` query 0.36–0.37 ms both, `map` over an empty vector 30.2 ms both (the caller's own code holds the query); the 80–90 ms of its commit were measured on the facts build | a few kB of the system image |
| P11 | `up/11-invoke-exact-vararg` 0533d9f65a | an invoke keeps the exact specialization where only a varargs tail is widened | 1 file, +22 −2 | **alone** (build 3; `Compiler/inline`, `Compiler/inference` pass) | `Compiler/test/inline.jl` | alone: no change on `motiv/varargs_recursion.jl` (27.5 ms, 16.8 MB, three specializations of the wrapper); with P12 0.30 ms against P12 alone 0.51 ms | `sys.so` +270 kB (+0.14 %) alone |
| P12 | `up/12-cycle-inline` ce88d1ec49 | an inference cycle's members inline each other | 3 files, +26 −9 | **alone** (build 4; `Compiler/inline`, `Compiler/inference` pass) | `Compiler/test/inline.jl`, `Compiler/test/inference.jl` | the varargs wrapper in a recursion: 26.9 ms and 16.8 MB → 0.51 ms and 0 bytes alone (0.30 ms with P11); the wrapper's specializations 3 → 1 | **`sys.so` +1.73 MB (+0.89 %)** alone: more inlining inside cycles; the compiler's own stage 294.8 s against 289.2 s in the stack (one build each) |
| P13 | `up/13-applicable-union-bottom` a99c132e9a | `applicable` at argument types that meet in `Union{}`: no `UndefVarError` in inference | 1 file, +4 −2 | stack | `Compiler/test/inference.jl` (no new case) | no plain reproducer: inference prunes a call with a `Union{}` argument first | none |
| P14 | `up/14-callsite-cache-wildcard` d13ebb2504 | the per-call-site cache holds method-cache entries with `Any` positions, matched as wildcards | 1 file, +58 −1 | **alone** (build 5; `worlds`, `core` pass) | `test/worlds.jl`, `test/core.jl` | a dynamic `setindex!(::Vector{Any}, x, ::Int)` at one site: 101–115 ns → 18.5 ns a call (1 to 16 value types); `push!` 105–184 ns → 13–14 ns | a wrong wildcard match would run the wrong method; the entry's conditions (no guard signatures, a simple signature implied) are what make it sound |
| P15 | `up/15-dispatch-profiler` 517a21076d | `JULIA_DISPATCH_PROFILE=1`: dynamic calls counted by callee, lookup path and call site, printed at exit | 1 file, +150 −1 | **alone** (build 6) | `motiv/dispatch_site.jl` with the variable | a tool. Off: the same site 95–121 ns (vanilla 101–115); on: +10 ns a call; its table shows the site's `setindex!` and `push!` resolved by the method cache's search (`assoc`), the case P14 serves (`logs/alone-p15.log`) | one load and a branch per dynamic call when off |
| P16 | `up/16-cfunction-caller-world` 8abc41154f | the `cfunction` calling convention `:caller_world`: a world-checked thunk | 4 files, +188 −17 | **alone** (build 2; `motiv/caller_world.jl`, `ccall`, `worlds` pass) | `motiv/caller_world.jl` (to go into `test/ccall.jl`) | a new feature: the pointer runs the caller's world (the test fails on vanilla, which runs the latest world) | entries are never freed (one per target and thunk); `sys.so` +94 kB |
| P17 | `up/17-image-hashless-external` 13bb0c8ef0 | an image keeps no external code specialized at a signature type without a hash | 1 file, +8 | **alone** (build 7; `precompile` passes) | `test/precompile.jl` | not measured here (no package with thousands of such docstring signatures at hand) | such instances are compiled again where they run |
| P18 | `up/18-precompile-typeinf-type` 7ad89c34bf | `typeinf_type(::NativeInterpreter, ::MethodMatch)` precompiled into the system image | 1 file, +2 | **alone** (build 8) | `motiv/first_calls.jl irt` | the first `Base.infer_return_type(sin, (Float64,))` in a session: 36.2 ms → 28.4 ms in the stack (3 runs each; the second call 0.04 ms both); alone 28.4–28.9 ms against vanilla 35.9–36.4 ms the same hour (`logs/alone-p18.log`): the rest of the first call compiles other entries | none |

**The invalidation probes** (`motiv/invalidations.jl`): a package defines one method for a type of its own, and the runtime counts the distinct instances of the system image the definition invalidates.

| Probe (the method a package defines) | Reaches | vanilla | the stack |
|---|---|---|---|
| `Base.sizeof(::Type{W19A})` | P01 | 413 | 377 |
| `Base.getproperty(::Type{W19B}, ::Symbol)` | P02, P03 | 4,977 | 4,137 |
| `Base.unwrap_unionall(::W19C)` | P02 | 2,142 | 2,142 |
| `Base.typejoin(::Type{W19D}, ::Type{W19D})` | P03 | 1,938 | 850 |
| `Core.InexactError(::Symbol, ::Type{W19I}, v)` | P04 | 16,092 | 1 |
| `Base.convert(::Type{AbstractString}, ::W19E)` | P04 | 0 | 0 |
| `Base.Symbol(::W19F)` | P04 | 0 | 0 |
| `(::Type{Val{W19G}})()` | P06 | 2,004 | 0 |
| `Base.ImmutableDict{Symbol,Any}(::ImmutableDict, ::Symbol, ::W19H)` | P07 | 398 | 76 |

- `unwrap_unionall`'s probe changes nothing: the 2,142 instances call `unwrap_unionall` themselves (`eltype`, logging, the compiler), outside the helpers P02 changes.
- The `convert` and `Symbol` probes invalidate nothing on vanilla either: plain Julia infers those calls at concrete types where they are compiled. Their part of P04 matters to the facts mode's deep class (E-477), not to plain invalidation.

**Orthogonality.** Pairs that share a file, and `git apply --check` of each onto the other's result (both orders):

| Pair | Shared | Applies |
|---|---|---|
| P02, P03 | `base/essentials.jl` (P02: `unwrap_unionall`, `isvatuple`, `unwrapva`; P03: `rewrap_unionall`) | both orders |
| P02, P06; P03, P06 | `base/essentials.jl` (P06: `Val`) | both orders |
| P11, P12 | `Compiler/src/ssair/inlining.jl` (P11: `compileable_specialization`; P12: `get_cached_result`) | both orders |
| P14, P15, P16 | `src/gf.c` (P14 and P15 in `jl_lookup_generic_`; P16: `jl_get_specialization1_worlds`) | every pair, both orders |

- One dependency by meaning, not by text: P02's `fieldcount` calls `invoke(TypeError, Tuple{Any, Type, Any}, …)`, which matches the three-argument `TypeError` both before P04 (an outer constructor) and after (an inner one).
- All 18 stacked, in order 01 to 18, apply without conflict (`w19-stack`); the union of the 18 branches' trees is the stack's tree (`logs/stack-vs-next.txt`).

**Base's tests on the stack** (`w19-stack` bd0e219c41; `Base.runtests([...]; ncores=1)`; load 2 to 5 of 128): all pass.
- `reinterpretarray`, `reflection`, `sorting`, `worlds`, `int`, `strings/basic`, `channels`, `tuple`, `missing`, `ccall`: 4 min 46 s (`logs/tests-stack-a.log`);
- `core`, `show`, `misc`: 4 min 24 s (`logs/tests-stack-b.log`);
- `Compiler/inference`, `Compiler/inline`, `Compiler/verifytrim`, `Compiler/invalidation`: 2 min 55 s (`logs/tests-stack-c.log`);
- `precompile`, `Compiler/codegen`: 3 min 16 s (`logs/tests-stack-d.log`).

**What the stack costs** (build 1 against vanilla's build log, `julia-vanilla/tw-build.log`, both at `-j4`/`-j64` for the C part; the image stages are single-threaded): `Base.Compiler` 294.8 s against 289.2 s; `Base` 31.3 s against 32.5 s; the system image's output 100.8 s against 98.2 s. `sys.so` 196,265,928 bytes against 194,307,784 (+1.0 %). One build each: within the spread of a stage's time.

## Builds

Eight full builds of `wt/w19-julia` (`WIDE=0 tools-local/build.sh`, `-j4`, niced; every image stage rebuilt), one after another; before the first, the dependencies (`make julia-deps`, 20 s, from `deps/srccache` copied from `julia-next`). Logs: `logs/build<n>-*.tw-build.log`.

| Build | Branch | Commit | Load at start (of 128) | Wall | `sys.so` (bytes) | Result |
|---|---|---|---|---|---|---|
| 1 | `w19-stack` (all 18) | bd0e219c41 | 1.34 | 767 s | 196,265,928 | BUILD EXIT 0 |
| 2 | `up/16` | 8abc41154f | 2.76 | 675 s | 194,401,696 | BUILD EXIT 0 |
| 3 | `up/11` | 0533d9f65a | 3.62 | 747 s | 194,578,040 | BUILD EXIT 0 |
| 4 | `up/12` | ce88d1ec49 | 3.35 | 675 s | 196,039,168 | BUILD EXIT 0 |
| 5 | `up/14` | d13ebb2504 | 2.29 | 685 s | 194,662,040 | BUILD EXIT 0 |
| 6 | `up/15` | 517a21076d | 4.68 | 685 s | 194,436,928 | BUILD EXIT 0 |
| 7 | `up/17` | 13bb0c8ef0 | 5.26 | 685 s | 194,447,936 | BUILD EXIT 0 |
| 8 | `up/18` | 7ad89c34bf | 2.43 | 676 s | 194,527,896 | BUILD EXIT 0 |

Vanilla v1.13.2 (`julia-vanilla`, built 2026-11-06 at `-j64`): `sys.so` 194,307,784 bytes. Built alone: every patch that touches `src/` (P14, P15, P16, P17), the two of the inliner that could mask each other (P11, P12), and P18. Not built alone: P10 and P13 (`Compiler/`, 5 and 4 lines; built in the stack), and the `base/` patches (P01 to P09; built in the stack, and those that change method bodies only also evaluated alone in vanilla's session, `logs/session-vanilla.log`; P04 and P06 change structs' inner constructors, which a session cannot redefine).

## Inventory rows and compiler §11

The inventory ([`writeup/design/julia-changes.md`](../../../writeup/design/julia-changes.md)) by its rows of kind *general*, and the rows found general in the final diff:

| Inventory row | Commit | Its patch | Note |
|---|---|---|---|
| 1 | 74882bd25b | `up/01-reinterpret-padding-typed` | as in `next` |
| 2, 3 | 4a43550691, 60b7e90aa4 | `up/02-introspection-getfield-invoke` | `runtime_internals.jl`'s flags masks widened to 32 bits are not in it: they follow `DataType.flags` (traits) |
| 4 | 8319275b9e | `up/14-callsite-cache-wildcard` | |
| 5 | 250b6fa703 | `up/15-dispatch-profiler` | the call site's address taken in `jl_apply_generic` (in `next`, in `apply_generic_reach`) |
| 6 | 6f936edf18 | `up/16-cfunction-caller-world` | |
| 7 | 45f0a5e10e | `up/10-bootstrap-return-type` | without the entries of the definition-time check (traits T17) |
| 8 | 999634c858 | `up/17-image-hashless-external` | without `next`'s counters (`JULIA_DEBUG_EXTERNAL_CIS`) and the G2 clause (facts F8) |
| 9 | 333fbf71e2 | `up/09-reflection-interp-world` | |
| 10 | e02e296308 | `up/11-invoke-exact-vararg` | without the closed build's clause (traits T16) |
| 11 | 94ee04f5be | `up/12-cycle-inline` | |
| 49 (kind "—") | fb0c7ba75a | `up/13-applicable-union-bottom` | general: an upstream bug |
| 59, its precompile statement | 9ac2741187 (in row 59's set) | `up/18-precompile-typeinf-type` | general; the rest of row 59 is traits |
| 137 | 768850cff7 | none | not needed on v1.13.2: vanilla hashes `jl_return_address()`, an integer; the cast is needed only where `next` passes the address as `void *` (facts F4). The prototypes of `jl_set_module_facts`, `jl_set_module_trait_option` go with facts F2 |
| 152 | 61277571fa | `up/08-issorted-specialize` | |
| s3-9 | 297d19aca1 | `up/04-error-paths-concrete` | |
| s3-10 | ab96564f36 | `up/03-typejoin-getfield-invoke` | `unwrapva` is in `up/02` (the same hunk as `isvatuple`) |
| s3-11 | 396cd65a48 | `up/05-yieldto-setfield` | |
| s3-12 | 024755ee89 | `up/06-val-new` | |
| s3-13 | bc844be7c0 | `up/07-iocontext-property-invoke` | the `IOContext(io, key => value)` hunk; the same change in `IOContext{IO_t}(io, KV, KVs...)` goes with that method (traits T13) |

**Compiler §11's items without a patch:**
- *The run-time `return_type` entry with the facts policy* (the entry of `return_type`'s own interpreter): facts F5.
- *The world-checked caches of §8.1 and §8.2, and an image's rule for a signature type without a hash (§9)*: made (`up/16`, `up/14`, `up/17`); §8.2's exact-type entries are Optional and not built.

**Found general in the diff, not in §11, not made here** (candidates, `PLAN.md` §2.4):
- *The call's own signature in a dispatch edge and its backedge* (compiler §3.1; inventory rows 79, 83, s3-8, kind facts): a caller of a `@nospecialize` method at `Int` stays valid when the method gets a sibling at `String`. Useful without facts; it changes the backedge format, so it needs its own build and `test/precompile.jl`.
- *One compiled code per result* (compiler §3.3, `equivalent_cached_ci`; rows 121, 126): general if plain Julia also compiles an instance twice where the first cached entry by ABI has no code; E-389 counted it on a build with two policies only.

## The census (W-143)

The census (`../w157/census.jl`) reads the deep class, the G2 bit of a build with the facts mode. **It does not run on the stacked tree:** v1.13.2 with these patches has no facts mode and no G2 bit. What each patch removes was measured where the facts mode exists, on `next-s3`, commit by commit (E-476 to E-478, `../w157/README.md`; product setting, the forks and upstream CSV and DataFrames by facts, one process per row):

| Patch | Measured as | The culprits it removes (the forks: instances; own facts instances whose cone held one) | Own facts instances in the class |
|---|---|---|---|
| `up/04` (error paths) | 297d19aca1 in E-477's first batch | `throw_inexacterror` (10 instances; 2,352), `DomainError` (1,712), `string_index_err` (817), `TypeError` (3; 39) | on the baseline these four alone: +16.1 points for the forks, +28.0 for upstream |
| `up/03` (type joins) | ab96564f36 | `typesplit` (1,050), `tailjoin`, `full_va_len`, `supertype` (796 each), `promote_typejoin`, `_promote_typesubtract` (768); `rewrap_unionall` 14 to 7 | the first batch with `!==`, 195 (a) and `yieldto`: forks 41.8 % to 58.5 %, upstream 39.6 % to 70.7 % |
| `up/05` (`yieldto`) | 396cd65a48 | `yieldto` (1,029) | (in the first batch) |
| `up/06` (`Val`) | 024755ee89, E-478 | `Val{x}()` (1,198 cones at E-476) | `Val` and `IOContext` together: forks 58.5 % to 63.1 %, upstream 70.7 % to 79.0 % |
| `up/07` (`IOContext`) | bc844be7c0, E-478 | `IOContext` | (with `Val`) |
| `up/01`, `up/02` (padding, introspection) | inventory rows 1 to 3, in the stack before the census existed | not measured: no build without them has the census | — |

The other patches touch no culprit of the census: they change the runtime, the inliner, reflection and a trimmed build, not a call at a signature that is no fact.

**The next ten candidates**, by what each would buy, from the census on the head of that line (`next-s3` bc844be7c0, `../w157/logs/b2-census-forks.log`; the forks, own facts instances in the class 2,654 of 4,204, 63.1 %; "alone": the instances whose cone holds only that name's culprits; "greedy": on top of the names before). Not built.

| # | Culprit (Base) | Kind | Cones it is in | Buys | The patch it would take |
|---|---|---|---|---|---|
| 1 | `schedule(t, x; error)`, `notify`, `notify_error`, `close(::Channel, ::Exception)`, `sync_end` | the task code under a lock | 1,009 | +50 instances together (68.9 % at greedy step 23), 0 alone | the payload passed as `Any` through a keyword call: `invoke` at the method's own signature, or a positional `_schedule` |
| 2 | `push!(::Vector{Any}, ::Any)` (`__safe_setindex!`), `push!(::CompositeException, ::Any)` | a container of `Any` | 920 | 0 alone; the kind together +518 (84.6 %) | a rule, not a patch: open issue 218 (b) |
| 3 | `Iterators.iterate` | other | 509 | +38 alone (64.0 %) | to read: its 20 instances |
| 4 | `hasmethod` (a callee named by instance) | by instance | — | +32 (64.8 %) | the compiler's edge kind, open issue 219 (a) |
| 5 | `iterate` (35 instances) | other | 424 | +14 alone, +25 greedy | to read |
| 6 | `_iterate_dict` | container, other | — | +19 greedy | to read |
| 7 | `typejoin`'s stores into a `Vector{Any}` | type join | 796 | 0 alone | build the parameter list with `Core.svec` or `invoke(setindex!, …)`; with `up/03` |
| 8 | `promote_typejoin_union`, `typejoin_union_tuple` | type join | 483 | 0 alone | as `up/03` |
| 9 | `merge` | other | 299 | +10 alone | to read |
| 10 | `collect` (35 instances), `indexed_iterate` | introspection, other | 789, 542 | +4 alone (`collect`) | the generic paths at a computed element type: open issue 218's case |

By kind together (greedy): other 66.1 %, type joins 69.5 %, introspection 71.1 %, the task code 72.3 %, containers of `Any` 84.6 %, by instance 88.4 %, error paths 95.4 %, constructors at kinds 100 %. A census on `next` cf0f039f51 was not run (the environments of `../w157/` are built for `next-s3`'s library).

## Not done, not verified

- **P10 and P13 are not built alone** (built in the stack only). P10 shows no plain effect on v1.13.2; P13 has no plain reproducer. Both are candidates to drop from the series or to keep as hygiene; the main session decides.
- **P04 and P06 are not checked alone:** they change inner constructors of `Core` and `Base` structs, which a session cannot redefine, and no build was spent on them; they are checked in the stack (`core`, `int`, `strings/basic` pass) and by the invalidation probes.
- **P09 and P17 have no motivation's number.** P09: no case was built that invalidates the compiler's code and then reflects with an explicit interpreter. P17: the probe package (`motiv/W19Docs`, 2,000 documented methods at union signatures) makes no instance at a hashless signature type, so its load is the same on both (12.5–12.9 ms, `logs/p17-load.log`); a package whose docstrings push such types (the case of the commit) was not found offline.
- **The invalidation probes run on the stack,** so a probe's difference is that of all 18 patches; each probe is built to reach one patch's code, but no probe was run on a patch alone.
- **P03's behaviour change** (a package's own `typejoin` method no longer consulted for the joins of its types' parameters inside `typejoin`) is not checked against registered packages.
- **The risk "compile time"** is measured once: build 1's stages against vanilla's log (Base 31.3 s against 32.5 s; the compiler 294.8 s against 289.2 s; one build each). No package's precompile time was measured.
- **The comments:** each patch's comments are rewritten in plain terms; their wording is mine and was not reviewed.
- **The `up/*` branches carry the line `Co-Authored-By: Claude <noreply@anthropic.com>`** as the brief asks; the main session decides their final authorship line.
- **The census was not run** on the stacked tree (no facts mode there) nor on `next` cf0f039f51; the section above reports E-476 to E-478.
- **S1** (the call's own signature in a backedge, `PLAN.md` §2.4), the strongest candidate for a nineteenth general patch, is not made.
