# W-19: the changes to Julia as small patches for upstream (first part: the patches useful without traits; second part: `up/19` and the facts series)

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
- *The call's own signature in a dispatch edge and its backedge* (compiler §3.1; inventory rows 79, 83, s3-8, kind facts): made in the second part as `up/19`, without its clause for `!==`.
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
- **S1** (the call's own signature in a backedge, `PLAN.md` §2.4), the strongest candidate for a nineteenth general patch, is made in the second part: `up/19`.

# Second part: the dispatch edge's patch (`up/19`), and the facts series made

The brief: `up/19` (the plan's S1) as a nineteenth patch useful without traits; the facts series' smallest form (F0, F2, F1, F3, F4, F5, S1, F7, F8 of [the plan](../../../writeup/plans/2026-11-22-upstream-series.md)), each part one commit, stacked on v1.13.2; its result on its head. The source is the final diff, as in the first part. Comments are rewritten without the references' section numbers; the facts series keeps the facts mode's own terms (it is that series), and no trait term.

## How to run (second part)

```
git -C wt/w19-julia checkout <branch>; WIDE=0 tools-local/build.sh wt/w19-julia
julia motiv/f-callsig-census.jl                     # up/19: the backedges by the call's signature in a session
julia motiv/f-callsig-probes.jl <probe>             # up/19: a package's method, the instances it invalidates
julia motiv/f-callsig-test.jl                       # up/19's test, standalone, for vanilla as the control
julia motiv/f-count-cis.jl                          # the system image's instances
experiments/implementation/gates/run_all.sh <tree> 'f[1-7]_*'; julia gates/f-*.jl   # the facts gates; facts-only copies
PREP=1 bash f-loads.sh <tree> <label>; bash f-loads.sh <tree> <label> 2             # E-392's nine loads (w134/lost.jl)
julia --project=envs/up motiv/f-plain.jl <csv>      # plain code's session with the facts mode off
```

`envs/` and `pkgs-facts-w19/` are made by hand (ignored by git): `pkgs-facts-w19` is `w134/pkgs-facts` with the one line `Base.Experimental.@compiler_options facts=true` (the series has no other option; the round's line carries `bounded=false no_pirates=false`, trait options the series does not have); `envs/facts` and `envs/up` are `w134/env_facts` and `w134/env_up` made by `w159/mkenv.py` with that copy. The depots: `agent-depots/w19` (tests, gates), `agent-depots/w19-loads` (the loads, the plain session).

## `up/19`: a dispatch backedge keeps the call's own signature

| Branch, commit | Size | Checked | Test |
|---|---|---|---|
| `up/19-callsig-backedge` 3f8281f25c | 4 files (`Compiler/src/typeinfer.jl`, `src/gf.c`, `src/method.c`, `test/worlds.jl`), +72 −12 | **alone** (build 5): `worlds` (172, with its new test), `Compiler/invalidation` (105, 4 broken as on vanilla), `core` pass; `precompile` 454 pass alone (`logs/f-tests-up19-v2.log`) | `test/worlds.jl`: a caller at `Int` of a `@nospecializeinfer` method stays valid when a method for `String` is defined; a caller at `Any`, and a method that meets the call's signature, invalidate. Vanilla fails it at its first discriminating line (`motiv/f-callsig-test.jl`, `logs/f-callsig-test.log`) |

- **What it is:** the plan's S1 without the clause for `!==` (below). The forward edge of a call with one covering match whose instance is wider than the call's signature already holds the call's signature (`1, atype, callee`); the backedge now holds it too (`svec(sig)`), and a later method invalidates the caller only where it replaces the matched method over the intersection with the call's signature.
- **Which calls reach a wider instance in plain Julia:** a method whose `@nospecialize` arguments inference does not specialize on either (`Base.@nospecializeinfer`). A plain `@nospecialize` method is inferred at the call's concrete types (`k(::Int)` from `k(@nospecialize(x))`), its instance is the call's, and its backedge was precise already. In the system image: 871 backedges by the call's signature (beside 267,706 ordinary and 3,889 `invoke` entries), most to `typejoin`, `promote_type`, the compiler's `⊑`, `preserve_handle` (`logs/f-up19-v2.log`).
- **Motivation** (`motiv/f-callsig-probes.jl`, one process per probe; vanilla `logs/f-callsig-probes.log`, `up/19` `logs/f-up19-v2.log`): a package's `Base.preserve_handle(::MyType)` invalidates 443 → 1 instances. `typejoin`, `promote_type`: 1,938 → 1,938, 253 → 253 (their callers call at abstract types). A method of `!==`: 4,610 → 4,610.
- **Cost:**
  - the system image 194,446,048 bytes against vanilla's 194,307,784 (+0.07 %); the same source built twice gave sizes 270 kB apart (builds 1 and 4), so the difference is within the spread;
  - the compiler's image stage 287.7 s against 289.2 s (one build each);
  - **a package's load is slower:** upstream CSV and DataFrames compiled plainly, `using` 718–740 ms against vanilla's 647–657 ms (+12 %; a warm-up and 3 fresh processes each, interleaved, load 3.0–3.3; `motiv/f-plain.jl`, `logs/f-up19-v2.log`). The session holds 116,743 valid CodeInstances after the load against 116,523: the packages' images keep 269 external instances vanilla's do not and lack 59 (`motiv/f-dump-cis.jl`), found as connected to the image's own code through the backedges by the call's signature. The first work 4.39–4.51 s against 4.39–4.42 s. Which of the two (more external code in the images, or the collection of backedges at insertion, `store_backedges` with an `Any[]` per caller) costs the load time is not isolated. A tension for the plan's claim that S1 is a free win: below.
- **The clause for `!==`, moved to F7.** The final tree's hunk matches a call of `!==` at the call's own types. In plain Julia that makes inference infer `!==` at each call's types: 423 instances of `!==` in the system image against 1 (build 4, 28c9bbfcf8, `logs/f-plain-up19.log`), and a method of `!==` invalidates 4,610 → 225. Its load cost was the same as without it (723–805 ms), so the load cost is the backedges' own. `!==` is not a function packages extend; the clause serves the facts mode (a call of `!==` at a fact signature) and goes with F7. A principled form: `!==` declared `@nospecializeinfer` in `boot.jl`, one instance, the call's signature on its backedge (this patch). Not built.

## The facts series, made

The stack `w19-facts` (0474538f42): F0, F2, F1, F3, F4, F5, S1, F7, F8, each one commit on the one before, on v1.13.2. Its head's tree is the tree built as 64a8dcab67 (build 2): moving the `!==` clause from S1 to F7 left the head's tree unchanged (`git diff 64a8dcab67 0474538f42` is empty), so the head's measurements below hold for it.

| Part | Branch, commit | Subject | Files | Size | Checked | Test |
|---|---|---|---|---|---|---|
| F0 | `facts/00-fields` 7b7d01ff5b | `Method.facts`, `Module.facts`, `JL_CI_FLAGS_FACTS`, the instance's policy bits | `julia.h`, `julia_internal.h`, `jltypes.c`, `method.c`, `module.c`, `staticdata.c` | 6 files, +21 −6 | compiled (`make -C src`, 78 objects, rc 0); built with F2 (build 7): `Method.facts::UInt8` after `purity`, `core` passes | `test/core.jl` |
| F2 | `facts/02-policy` 4603a198ae | the policy: `@compiler_options facts=true`, `:facts_boundary`, `:facts_always`, lowering carries them, `jl_method_policy` | `experimental.jl`, `Compiler.jl`, `ast.c`, `ast.scm`, `julia-syntax.scm`, `interpreter.c`, `julia.h`, `julia_internal.h`, `method.c`, `module.c` | 10 files, +95 −3 | **built (build 7)**: `f-f2_policy_flags` passes; `core`, `syntax`, `keywordargs` pass (`logs/f-gates-f02.log`) | `gates/f-f2_policy_flags.jl` |
| F1 | `facts/01-nortsite` 6ed068147f | the `nortsite` effect bit | `effects.jl` | 1 file, +28 −8 | parsed; built with F3 (build 6) | `Compiler/test/effects.jl` |
| F3 | `facts/03-inference` 64b34bc408 | the facts inference, `NativeInterpreter(; facts = true)`, a cache owner of its own until F4 | `facts.jl` (new), `abstractinterpretation.jl`, `typeinfer.jl`, `types.jl`, `Compiler.jl` | 5 files, +163 −21 | **built (build 6)**: `f1_facts_sites` and `f-f2_policy_flags` pass; `Compiler/effects`, `Compiler/inference`, `core` pass; reflection with `facts = true` gives `Any` at `Real`, plain `Union{Float64, Int64}` (`logs/f-gates-f03.log`) | gate `f1_facts_sites` |
| F4 | `facts/04-policy-code` 17c8325fb9 | one CodeInstance per MethodInstance and policy; calls between policies | `gf.c`, `builtins.c`, `builtin_proto.h`, `codegen.cpp`, `interpreter.c`, `engine.cpp`, `julia.h`, `julia_internal.h`, `jl_exported_funcs.inc`, `cicache.jl`, `facts.jl`, `typeinfer.jl`, `types.jl` | 13 files, +614 −82 | **built (build 3)**: gates `f1`, `f3`, `f5`, `f-f2`, `f-f6` pass; `worlds`, `Compiler/effects`, `Compiler/inference`, `core`, `ccall` pass; `threads` 163 pass, 5 fail in the CPU-affinity test (below) (`logs/f-gates-f04.log`, `logs/f-threads-f04.log`) | gates `f3_policy_code`, `f-f6_reach_policy` |
| F5 | `facts/05-return-type` 627bbc6e1d | `return_type` gives plain inference's answer | `facts.jl`, `tfuncs.jl`, `typeinfer.jl`, `types.jl` | 4 files, +22 −13 | compiled (`make -C src`, rc 0; no C change), parsed; built in the head | gate `f5_return_type` |
| S1 | `facts/s1-callsig-backedge` cbc70a73e4 | `up/19`, cherry-picked | as `up/19` | 4 files, +72 −12 | `up/19` built alone (build 5); its C in the stack compiled (`make -C src`, rc 0) | `test/worlds.jl` |
| F7 | `facts/07-g2` 93283cc1ea | the deep class: the G2 bit, a cycle as one, an edge names the callee's code; a call of `!==` matched at its own types | `facts.jl`, `typeinfer.jl`, `abstractinterpretation.jl`, `gf.c`, `method.c`, `julia.h`, `staticdata.c`, `test/worlds.jl` | 8 files, +121 −13 | compiled (`make -C src`, rc 0), parsed; built in the head | gate `f4_g2_bit` |
| F8 | `facts/08-images` 0474538f42 | images keep deep G2 code and a run-time site's target; `--trim` plain | `facts.jl`, `typeinfer.jl`, `gf.c`, `module.c`, `staticdata.c`, `staticdata_utils.c` | 6 files, +81 −2 | **the head, built (build 2)**: the gates and tests below; the nine loads | gates `n15_image_policy`, `n17_rtsite_targets` |

**In all:** 27 files, 1,191 lines added, 134 removed (with `up/19` and its test); the plan's estimate for this series was about 1,700. By directory: `src/` 17 files, `Compiler/src/` 8, `base/` 1, `test/` 1.

**Checked by:** full builds of F2 (with F0), F3 (with F1), F4, `up/19` (S1) and the head (F8, with F5 and F7); `make -C src` (the C runtime compiled and linked) at F0, F5, S1 and F7 in the stack (`logs/f-compile-checks.log`; S1 and F7 at their commits before the `!==` clause moved, whose C differs from the pushed commits' in two comments); every changed Julia file parsed at every part (`Meta.parseall`). F1, F5 and F7 were not built alone: F1's and F5's C is their parent's; F7's tree is the head's but for F8's hunks.

**The head's gates** (`logs/f-gates-head.log`): `f1_facts_sites`, `f3_policy_code`, `f4_g2_bit`, `f5_return_type`, `n15_image_policy`, `n17_rtsite_targets` pass. Not passing, each for a part not in the series:
- `f2_policy_flags`: its module sets `bounded=true no_pirates=true` and reads `jl_get_module_trait_options` (S3's trait options). The facts-only copy `gates/f-f2_policy_flags.jl` passes.
- `f6_reach_policy`: its last part runs a session under `JULIA_COMPILE_BY_FACTS=1` (F6, the test bed). The copy without it, `gates/f-f6_reach_policy.jl`, passes.
- `f7_membership_edges`: sets.
- `n34_closed_invoke_compiled`: the trimmed build's verifier resolves an invoke by the policy of the code it names (row 159, `verifytrim.jl`), which the plan lists under T16. Under `--trim` every method is plain (F8), so the case the gate builds by hand does not arise from a build of this series.
- The other gates of the facts mode need a set or the library (`n9_fully_typed`: F11; `n36_library_deep`: the library, F9).

**The head's tests** (`logs/f-tests-head.log`; `Base.runtests([...]; ncores=1)`, load 3.6–5.5): `worlds`, `Compiler/invalidation`, `Compiler/effects`, `Compiler/inference`, `core`, `reflection` pass (7,357,364 pass, 25 broken); `precompile` 454 pass alone. (Run after `core` in the same worker, `precompile` failed on `up/19` at `UseBaz`'s assertion that `Baz` is not loaded (`logs/f-tests-up19.log`); alone it passes on `up/19`, on vanilla and on the head (`logs/f-tests-precompile.log`). Not run in that order on vanilla.)

**`threads` on F4:** 5 failures, all in the test that a process with a CPU affinity of `n` cores starts `n ÷ 2` threads; it reads `"1"` where it expects 2 to 4. `env.sh` sets `JULIA_NUM_THREADS` and `JULIA_CPU_THREADS`, which that test's child process inherits. The other 163 pass. Not run on vanilla.

### The series' result: E-392's nine loads by facts against plainly

`f-loads.sh` (E-392's harness `w134/lost.jl`, unchanged) on the head (64a8dcab67, the tree of `w19-facts`); upstream CSV and DataFrames compiled plainly (`envs/up`) and by facts with the one line `@compiler_options facts=true` per module (`envs/facts`); orders A (the work, the nine loads, the work again) and B (the loads, then the work); a warm-up and 2 fresh processes per cell; product setting, one thread; load 2.6–4.2 (`logs/f-loads-head.log`). The library is not loaded. Counts are equal in every run; times are the range of the three.

| | own image instances (the eight packages) | lost to the nine loads | first work (A) | the work after the loads (A) | the work after the loads (B) |
|---|---|---|---|---|---|
| plainly | 4,670 | 424 (9.1 %) | 4.38–4.40 s | 5.14–5.16 s | 6.13–6.16 s |
| by facts | 3,461 (all facts; G2 1,372) | **14 (0.4 %)** | 1.72–1.74 s | **1.43–1.45 s** | 2.41–2.43 s |

- Digests equal in every cell. The code the work made: plainly 217, of which the loads end 131; by facts 77, of which 5.
- The round's facts cells on `next` (E-511): 14 of 3,490 lost, the work after the loads 1.45–1.46 s against plain's 5.19–5.32 s (426 of 4,688). **The facts series alone reproduces it:** neither the type system's sets, nor F6, F9 to F12, nor the 18 patches of series G are needed.

### What plain code pays with the facts mode off

Upstream CSV and DataFrames compiled plainly, no module with an option (`motiv/f-plain.jl`; a warm-up and 3 fresh processes per build, interleaved with vanilla, the same hour):

| Build | `using CSV, DataFrames` | valid CodeInstances after the load | after the work | facts code | first work (compile) | log |
|---|---|---|---|---|---|---|
| vanilla v1.13.2 | 647–676 ms | 116,523 | 117,115 | 0 | 4.39–4.56 s | each log |
| F4 (F0 to F4) | 638–645 ms | 116,589 | 117,181 | 0 | 4.36–4.48 s | `logs/f-plain-f04.log` |
| `up/19` alone | 718–740 ms | 116,743 | 117,335 | 0 | 4.39–4.51 s | `logs/f-up19-v2.log` |
| the head (F8) | 714–829 ms | 117,847 | 118,455 | 0 | 4.40–4.43 s | `logs/f-plain-head.log` |

- **The facts runtime costs plain code nothing measurable** (F4: the load, the counts and the work as vanilla's).
- **The load's cost is S1's** (+12 % with `up/19` alone; the head's +6–27 % includes it); the head's +1,324 instances after the load include the 422 instances of `!==` of F7's clause in the system image.
- The system image: F2 194,750,504 bytes (+0.23 % against vanilla), F3 195,338,912 (+0.53 %), F4 195,394,024 (+0.56 %), the head 195,653,592 (+0.69 %); the compiler's stage 289.6 s, 289.8 s, 297.1 s, 296.1 s against vanilla's 289.2 s (one build each; two builds of one source differed by 0.27 MB). Most of the growth appears at F3, whose C is F2's: not read further.

### Orthogonality with series G

- `git merge-tree w19-stack w19-facts` merges without a conflict. **Not clean by meaning:** in the merged tree `up/15`'s dispatch profiler takes the call site as `jl_return_address()` inside `apply_generic_reach`, which F4 made a function of its own (`NOINLINE`): the profiler would record the entry's return address, not the call site's. The final tree has `dp_ip = ip`. Whichever lands second changes that line (the plan's E7).
- `up/17` and F8 change the same loop of `queue_external_cis` in separate hunks.

## Builds (second part)

`WIDE=0 tools-local/build.sh wt/w19-julia` (`-j4`, niced, every image stage rebuilt), one after another. Logs: `logs/f-build<n>-*.tw-build.log`.

| Build | Branch | Commit | Load at start (of 128) | Wall | `sys.so` (bytes) | Compiler stage | Result |
|---|---|---|---|---|---|---|---|
| 1 | `up/19` (with `!==`, before its test fix) | c32b862601 | 2.24 | 686 s | 195,072,528 | 288.2 s | BUILD EXIT 0 |
| 2 | `w19-facts` (the head) | 64a8dcab67 | 4.21 | 768 s | 195,653,592 | 296.1 s | BUILD EXIT 0 |
| 3 | `facts/04-policy-code` | 17c8325fb9 | 5.34 | 758 s | 195,394,024 | 297.1 s | BUILD EXIT 0 |
| 4 | `up/19` (with `!==`, the test fixed) | 28c9bbfcf8 | 3.27 | 747 s | 194,801,784 | 287.0 s | BUILD EXIT 0 |
| 5 | `up/19` (pushed) | 3f8281f25c | 2.16 | 676 s | 194,446,048 | 287.7 s | BUILD EXIT 0 |
| 6 | `facts/03-inference` | 64b34bc408 | 2.79 | 747 s | 195,338,912 | 289.8 s | BUILD EXIT 0 |
| 7 | `facts/02-policy` | 4603a198ae | 2.62 | 675 s | 194,750,504 | 289.6 s | BUILD EXIT 0 |

Seven of the ten builds. Vanilla v1.13.2 (`julia-vanilla`, built 2026-11-06 at `-j64`): `sys.so` 194,307,784 bytes, its compiler stage 289.2 s. The tree `wt/w19-julia` is left at `facts/02-policy` (build 7); the head's build is build 2 (rebuild with `git -C wt/w19-julia checkout w19-facts` to measure it again).

## The seams: where the final tree's hunk carries a clause of another part

The facts series has the facts-only form; the final tree's form is what the later part adds. A row names the part that adds the clause.

| Where | The facts series | The final tree adds | Added by |
|---|---|---|---|
| `jl_method_t` (`julia.h`, `jltypes.c`'s field list) | `uint8_t facts` (bits 0-1, the policy) after `purity` | `declared_result`, `declared_covers` before it; bits 2-3 (4 warn, 8 enforce) of `facts` | T10; F11 |
| `jl_module_t` | `int8_t facts`, inherited at creation | `uint8_t trait_options` (bounded 1, no_pirates 2, fully typed 16/32, owner_only 64), `uint8_t loaded` | S3 split: F9 (owner_only), F11, T9; T7 (loaded) |
| `jl_method_policy` (`module.c`) | trim → plain; module flag 2 → plain; method flag 2 → facts, 1 → caller; module flag 1 → facts; else plain | `\|\| jl_method_fully_typed(m) != 0` in the facts clause; for a neutral method `if (!facts_all() \|\| method_is_builtin(m)) return PLAIN; return CALLER;` | F11; F6 |
| `mi_policy_uncached`, `mi_policy_facts_at` (`gf.c`) | a thunk of a module of flag 1 → facts, else plain; the runtime's entries reach plain code | `jl_compile_by_facts_all() ? FACTS : PLAIN`; `if (reach == JL_REACH_RUNTIME) return jl_compile_by_facts_all();` | F6 |
| `jl_type_infer` (`gf.c`) | the policy's sixth argument, the reservation per policy | the query world of memberships around the call (`jl_set_membership_query_world`), the member hook's compile queue (`jl_member_queue_drain`, inferred again) | T2; T9 |
| `jl_call_in_typeinf_world`, `jl_gdbcodetyped1` | unchanged | the query world of memberships | T2 |
| `apply_generic_reach` (`gf.c`) | the lookup keyed by `ip` | `dp_ip = ip` for the dispatch profiler | `up/15` (G); see "the plan", E7 |
| `eval_body` (`interpreter.c`), `@compiler_options` (`experimental.jl`) | `Expr(:meta, :facts, v)` | `Expr(:meta, :trait_option, bit << 1 \| v)`; options `bounded`, `no_pirates`, `owner_only`, `fully_typed` | S3 |
| `jl_method_set_source` (`method.c`), `policy-meta-sym?` (`ast.scm`) | `facts_boundary`, `facts_always` | `fully_typed_warn`, `fully_typed_enforce` | F11 |
| `is_fact_sig` (`facts.jl`) | dispatch tuple, unions within the splitting cost, a `Vararg` of a concrete member, a closure at kinds | `\|\| owner_only_call(T)`, with `is_owner_only` (the binding flags, bit 64 of `trait_options`, the open-operation flag) | F9 (E2, E3); T10 |
| `Effects` (`effects.jl`) | `nortsite`, bit 15 inverted | `trusted::UInt8`, bits 16-17; `merge_override_effects!` and `adjust_cycle_frame!` set `IR_FLAGS_EFFECTS \| IR_FLAGS_TRUSTED` | T15 (E9) |
| `adjust_effects` (`typeinfer.jl`) | no asserted effect over a frame with a run-time site | the fully typed fault makes the effects unknown | F11 |
| `NativeInterpreter` (`types.jl`) | `facts`, `crossings`, `plainrt`; `cache_owner` `:plain_rt` or nothing | `closed`, `overlay_table`, `ClosedCheck`; `cache_owner` the check's owner; `method_table` through the overlay; `DefinitionCheckInterpreter` beside | T16; T17 (E8) |
| `edges_satisfy_g2`, `name_callee_code` (`facts.jl`) | dispatch edges at fact signatures, callees with the bit | an absence edge (`is_absence_sig`) and a membership's method (`is_membership_mi`) count as facts; a membership's instance is not renamed | T6 (E4) |
| `queue_external_cis` (`staticdata_utils.c`) | the G2 branch | `up/17`'s signature without a hash, and the counters of `JULIA_DEBUG_EXTERNAL_CIS` | `up/17` (G); a debugging switch (plan §5) |
| `compile!` (`typeinfer.jl`) | `rtsite_targets` | `collectinvokes!(…; instances = true)` (an invoke that names its instance) and `equivalent_cached_ci` | T16; F12 |
| `abstract_call_gf_by_type` | the facts matching through `find_method_matches`; the returns with no edge | an operation's call (`declared_operation_result`), the closed build's splits, `record_match_memberships!`, `member_check_failed` | T10/T11; T16; T2/T9 (E12) |
| `optimize` (`optimize.jl`) | unchanged | `insert_fully_typed_check!` | F11 |

## What stays for later (listed, not made)

| Part | Size (the plan's estimate) | What it needs | Its seams in the series |
|---|---|---|---|
| F6 the test bed (`JULIA_COMPILE_BY_FACTS=1`) | about 20 | F4 | `jl_compile_by_facts_all` in `mi_policy_uncached`, `mi_policy_facts_at` and `jl_method_policy` (with `method_is_builtin`); the runtime's entries reach facts code; plan §5 asks for `--compile-by-facts=all` or its removal |
| F9 ownership (owner-only functions) | about 45 | F3; a field or a neutrally named module options word (S3 split), `BINDING_FLAG_OWNER_ONLY`, `jl_set_owner_only`, `jl_binding_owner_only_p` | `owner_only_call(T)` in `is_fact_sig`; without T10's open-operation flag; a gate without the library is still to write (`n36_library_deep` needs it) |
| F10 the deep endings | about 65 | F7 | `invalidate_code_instance` (the note), `reinfer.jl`'s `jl_note_deep_ending`, the collectors' roots; kinds `:definition`, `:deletion`, `:validation`; T5/T8 add `:membership`. Plan §5: a general invalidation log instead |
| F11 fully typed mode | about 60 | F3; the module options word (S3) | `jl_method_policy`'s clause; bits 4, 8 of `Method.facts`; `policy-meta-sym?`; `adjust_effects`; `insert_fully_typed_check!` in `optimize`; its check `closed_check` is T16's |
| F12 one compiled code per result (`equivalent_cached_ci`) | 25 | F4 (its policy clause); otherwise general (S2) | `compile!` and `add_codeinsts_to_jit!` call `jl_get_ci_equiv`, which F4 already makes policy-aware |
| T1 Core's types and slots | 220 | — | none of the facts series; `jltypes.c`'s `Method` field list gains T10's `declared_result` before `facts` (a field index changes) |
| T2 sets and memberships | 1,730 | T1 | the membership query world around `jl_type_infer_policy`, `jl_call_in_typeinf_world`, `jl_gdbcodetyped1` (F4's functions); nothing reads the facts fields |
| T3 intersections `All{X, Y}` | 390 | T2 | none |

The seams F4 and F7 leave for T6 (an absence edge and a membership's method as facts in `edges_satisfy_g2`) and T16 (the interpreter's `closed` field, `compile!`'s instances) are in the table above.

## Where the plan was wrong or incomplete

- **S1 is not free in plain Julia.** It costs a package's load about a tenth (above). The plan calls it a general win with only a build and two tests to show.
- **S1's case in plain Julia is `@nospecializeinfer`, not `@nospecialize`.** Plain inference specializes a `@nospecialize` argument at a concrete call; only a method inferred without specializing (`Base.@nospecializeinfer`, or a set's method compiled once) reaches a wider instance. Compiler §3.1's example (`k(@nospecialize(x))` at `Int` reaching `k(::Any)`) holds only with `@nospecializeinfer`.
- **S1's `!==` clause is facts', not general.** It makes inference infer `!==` at each call's types (1 → 423 instances in the system image), and its comment, the inventory row s3-8 and compiler §3.1 say it infers `!==` at `(Any, Any)`: the code does not. Moved to F7.
- **F4 is too large to review as one patch** (614 lines, 13 files). A split that builds: F4a the CodeInstance per policy (the flags' readers and writers in `gf.c`, `engine.cpp`, `cicache.jl`, `code_policy`; about 200 lines); F4b the calls between policies at run time (the entries, the builtins' variants, codegen's choice, the interpreter's policy; about 250); F4c inference across policies (`typeinf_other_policy`, the compile queues, reflection's top frame; about 150).
- **F3 needs an interim cache owner** to be sound alone: without F4's policy flag, code inferred by facts would be cached as Julia's own owner's and run as plain code. The series' F3 caches it under `:facts` (reflection only); F4 replaces it.
- **F5 touches F4's helpers** (`policy_interp`, `infers_other_policy`, `interp_for_policy`, `typeinf_edge`: the `plainrt` clauses). The plan's graph has F5 after F4 only.
- **F6 and F11 are inside F2's and F4's functions** (`jl_method_policy`, `mi_policy_uncached`, `mi_policy_facts_at`; `jl_method_set_source`, `policy-meta-sym?`, `adjust_effects`), not separate files. The plan lists them as parts but not as entanglements.
- **Entanglements not on the list:** the membership query world and the member hook's queue in `jl_type_infer` (T2, T9, inside F4's function); `IR_FLAGS_TRUSTED` in `merge_override_effects!` and `adjust_cycle_frame!` (T15, in F3's and F1's lines); `up/17`'s and `JULIA_DEBUG_EXTERNAL_CIS`'s hunks in F8's loop (`queue_external_cis`).
- **E7 is textually clean, not by meaning:** with `up/15` and F4 both applied, the profiler must read the call site from `apply_generic_reach`'s `ip`, not from `jl_return_address()` inside it.
- **The gate `n34_closed_invoke_compiled`** belongs with the verifier's change (row 159, `verifytrim.jl`), which the plan does not place; it is a closed build's (T16), not F8's.
- **`test/precompile.jl`'s rewrite** (`(be.def::Core.MethodInstance).def::Method`, plan §5's last bullet) follows neither S1 nor F7: `precompile` passes on `up/19` and on the facts head without it.
- **The sizes:** the series made is 1,191 lines added (with `up/19` and its test), not about 1,700.
- **The claim holds:** the facts series alone reproduces E-511's facts cells (14 own image instances lost, the work after the loads 1.43–1.45 s against plain's 5.14–5.16 s), with no set, no F9 to F12 and no patch of series G.

## Not done, not verified (second part)

- **S1's load cost is not isolated** between its two candidates (more external code kept by the images; the backedges' collection at insertion). One build of each variant would tell.
- **`!==` declared `@nospecializeinfer`** (the principled form of F7's clause) is not built.
- **F1, F5 and F7 are not built alone** (C compiled, Julia parsed; built in the head).
- **`threads`' CPU-affinity failures on F4** are not run on vanilla; read as the environment's (`JULIA_NUM_THREADS`, `JULIA_CPU_THREADS` from `env.sh`).
- **The G stack and the facts stack together** (`w19-stack` merged with `w19-facts`) are not built; the merge is textually clean and wrong by meaning in one line (E7).
- **The census** (`w157/census.jl`) was not run on the facts head.
- **The commit messages' wording** is mine and was not reviewed; the facts parts' subjects (`facts F<n>: …`) do not follow Julia's `component: summary` form.

# Third part: what `up/19` cost a plain load, `!==` once, and the rest of the facts series

The brief: the cause of `up/19`'s plain load cost and the fix at it (GT-34); `!==` as a `@nospecializeinfer` function (C-159); F4 split in three; F6, F9 to F12; the two series together; `threads` on vanilla; the commit subjects in Julia's form.

## How to run (third part)

```
bash g-plain.sh <label> julia-vanilla <tree>             # the plain load of upstream CSV and DataFrames, interleaved (RUNS=3)
PROF=1 bash g-plain.sh <label> julia-vanilla <tree>      # also the load under the profiler (motiv/g-profile.jl) and the counters
python3 tools/g-profcmp.py <a1.tsv,...> <b1.tsv,...> self 30   # two builds' profiles compared by function
julia --project=envs/up motiv/g-dupcheck.jl              # store_backedges' duplicate check in its three forms, over a session's edge lists
bash g-checks.sh <tree> <label>                          # !== instances, the up/19 probes, code compiled twice, the facts gates and the series' gates
```

## 1. What `up/19` cost a plain load: the cause, and the fix

**The cause is the backedges' collection, not the instances kept.** Profiles of `using CSV, DataFrames` (upstream, compiled plainly; one process per profile, 0.1 ms sampling, C frames; 3 per build; `logs/g-prof-up19-a-*.tsv`, read with `tools/g-profcmp.py`):

| | samples of the load | `store_backedges` (inclusive) | `insert_backedges` |
|---|---|---|---|
| vanilla v1.13.2 | 6,416–6,527 | 393–790 | 2,919–3,004 |
| `up/19` 3f8281f25c (rebuilt, build 1) | 7,034–7,104 | 1,406–1,478 | 3,634–3,671 |

- The difference between the two loads, about 620 samples, is `store_backedges`' (+786). Under it: `indexed_iterate` 0 → 299, `jl_get_nth_field_checked` 16 → 306, `jl_subtype_env` 954 → 1,285 (of which `obvious_subtype` 324 → 689).
- `store_backedges` runs for every CodeInstance an image's validation keeps (`verify_method`'s last stage). `up/19` collected each caller's backedges into a `Vector{Any}` of boxed pairs and read each back with `::Tuple{Any,Any}` and a destructuring, in the duplicate check's loop, quadratic in the edges: a subtype check and two dynamic field reads per step.
- **Not the cause:** the external instances. The counters (`motiv/g-load-counts.jl`, logs `g-plain-up19-*.log`): the packages' valid CodeInstances 11,619 vanilla, 11,623 `up/19`; one-match triples in their edges 413 and 413; the invalidation log at the load 1,402 and 1,417 instances (C side), 1,440 and 1,432 (validation). The session's backedges by the call's signature after the load: 1,961–1,969 (871 of them the system image's). The work per svec backedge at insertion (`_invalidate_dispatch_backedges`' intersection) is not visible in the profile.
- The second part's "269 instances more" was a count of one pair of image sets: the valid instances after the load move with each new set of images (below, "Not done") and do not move the load's time.

**Two attempts, and the fix:**
- The duplicate check walking the iterator twice, as v1.13.2 does (build 2, 8dd33781d9): **worse**, `using` 1,066–1,478 ms. The iterator's result type, `Union{Nothing, Tuple{Union{Tuple{Any,MethodInstance}, Tuple{Any,MethodTable}, Tuple{Nothing,Binding}}, Int}}` on v1.13.2, widens with `Tuple{CallSigBackedge, MethodInstance}` as one more member to `Union{Nothing, Tuple{Any, Int}}` (inference's union bound), and every step dispatches dynamically: `store_backedges` 4,598–4,801 samples (`logs/g-prof-up19-b-*`).
- **The fix** (build 3, `up/19` amended 2e9675d8aa): the walk as v1.13.2's, and the call-signature pair typed `Any` for inference (`compilerbarrier(:type, CallSigBackedge(sig))`), so the iterator's result type is v1.13.2's. What a backedge records and which method ends its caller are unchanged. The three forms over the 92,568 edge lists of a session after the load (`motiv/g-dupcheck.jl`, `logs/g-dupcheck.log`, three rounds): the new member 1,081 ms, collected into a vector 281 ms, typed `Any` 67 ms.
- **After it** (`logs/g-plain-up19-c.log`, `logs/g-plain-up19-c-time.log`): `store_backedges` 367–411 samples against vanilla's 365–405; `using CSV, DataFrames` 641–655 ms against vanilla's 654–663 ms (runs 3 to 6 of a warm-up and 6 fresh processes each, interleaved; load 5.1–7.3; runs w to 2 of both builds 721–1,205 ms, the machine's disturbance). `preserve_handle`'s probe: 1 (vanilla 443). The first work 4.38–4.48 s both.
- **The facts head** with the fix (build 4, `w19-facts` 7315c0b1bd): `using` 650–744 ms against vanilla's 665–691 ms (a warm-up and 4 each, load 4.7–10.8; `logs/g-plain-facts-head.log`). The second part's head took 714–829 ms.

**Delivered twice:**
- `up/19-callsig-backedge` amended: 2e9675d8aa (4 files, +66 −7). Pushed as **`up/19-callsig-backedge-v2`**: a force-push of `up/19-callsig-backedge` was refused by this session's permissions, so the old branch still points at 3f8281f25c. The facts series restacked on it (below), pushed the same way with `-v2`.
- For `next`: branch **`w19-callsig-load`** from cf0f039f51 (worktree `wt/w19-next`), commit 57eed205c5 "Compiler: store_backedges checks for duplicates on the iterator, with no vector per caller" (1 file, +10 −11). Parsed, not built: the same change was built and measured as `up/19` (build 3) and in the facts head (build 4).

## 2. `!==` once, at `(Any, Any)` (C-159)

- **The form:** `!==` declared `@nospecializeinfer` in `base/boot.jl` (the meta itself, through a local `@_nospecializeinfer_meta`: Base's macro does not exist yet there). Inference's clause for `!==` in `abstract_call_known` stays: it matches the call at the call's own types and takes `===`'s result. Matched so, the call reaches the one instance at `(Any, Any)` (`get_nospecializeinfer_sig`), its edge is `1, atype, callee` and its backedge keeps the call's signature (`up/19`). The inliner takes the same instance (`specialize_method` widens a `@nospecializeinfer` method), so `x !== y` still inlines.
- **The counts** (build 4, the facts head, `logs/g-checks-facts-head.log`): `!==`'s MethodInstances in the system image **1** (`Tuple{typeof(!==), Any, Any}`; with the clause alone 423 on F7, 430 on `next`). A package's method of `!==` for its own type invalidates **240** instances (vanilla 4,610; the clause alone 225). Gate `f4_g2_bit` passes; the nine loads' facts cells are unchanged (below).
- **Where:** amended into F7 (`facts/07-g2-v2` 34ead33143), and for `next` the second commit of `w19-callsig-load`, 683ea4fc16 "Core: `!==` is inferred once, at `(Any, Any)` (`@nospecializeinfer`)" (1 file, +4 −1; parsed).
- **It is general:** with `up/19` in plain Julia, the declaration and a clause that matches at the call's types give `!==` one instance and precise backedges. On series G alone (whose clause matches at `(Any, Any)`) the declaration changes nothing; the pair could be `up/20`.

## 3. The rest of the facts series

**The stacks** (julia repository; each part one commit on the one below, on v1.13.2):
- `w19-facts-v2` (7315c0b1bd): F0, F2, F1, F3, F4, F5, S1, F7, F8 (the second part's, S1 and F7 amended above), then F6, F9, F10, F11, F12. The branch `w19-facts` was to move there; its force-push was refused, so it still names the second part's head 0474538f42. The new parts' branches: `facts/06-testbed`, `facts/09-owner-only`, `facts/10-deep-endings`, `facts/11-fully-typed`, `facts/12-one-code`.
- `w19-facts-split` (c325ea04fa): the same tree (`git diff w19-facts-v2 w19-facts-split` is empty), with F4 cut in three (`facts/04a-ci-policy`, `facts/04b-reach-calls`, `facts/04c-cross-inference`) and every commit's subject in Julia's form (`component: summary`), the bodies without the series' labels.

| Part | Commit (`w19-facts-split`) | Subject | Size | Checked | Test |
|---|---|---|---|---|---|
| F0 | 0def925769 | julia.h, jltypes: fields for a per-method compile policy (`Method.facts`, `Module.facts`, a CodeInstance flag) | 6 files, +21 −6 | as in the second part | `test/core.jl` |
| F2 | 9ae1d2517d | lowering, module: `@compiler_options facts=true` and the method metas `:facts_boundary`, `:facts_always` | 10, +95 −3 | as in the second part | `gates/f-f2_policy_flags.jl` |
| F1 | 709100331e | Compiler: the `nortsite` effect bit | 1, +28 −8 | as in the second part | `Compiler/test/effects.jl` |
| F3 | e6b82d55b4 | Compiler: a facts inference that infers a call only at a fact signature | 5, +163 −21 | as in the second part | gate `f1_facts_sites` |
| F4a | 8987c0d019 | gf, engine, Compiler: one CodeInstance per MethodInstance and policy | 7, +231 −42 | C compiled and linked (`make -C src`, rc 0); Julia parsed | gate `f3_policy_code` (without a boundary) |
| F4b | a272e2fe06 | gf, codegen, builtins, interpreter: a call runs the callee's code of the caller's policy | 8, +310 −37 | C compiled and linked; its C is F4's | gates `f3_policy_code`, `f-f6_reach_policy` |
| F4c | 42bea6a355 | Compiler: inference across the two policies | 3, +75 −5 | its tree is F4's (built in the second part, build 3) | gates `f1`, `f3`, `f5` |
| F5 | 6040f2427d | Compiler: `return_type` gives plain inference's answer under either policy | 4, +22 −13 | built in the head | gate `f5_return_type` |
| S1 | 0a264420d4 | Compiler, gf: a dispatch backedge keeps the call's own signature where the call reached a wider instance | 4, +66 −7 | `up/19` built alone (build 3) | `test/worlds.jl` |
| F7 | 3cb4ff6254 | Compiler, gf: the G2 bit, set on a CodeInstance whose edges are facts at any depth | 9, +125 −14 | built in the head | gate `f4_g2_bit` |
| F8 | 27613f7a09 | staticdata, Compiler: package images and `--trim` under the facts policy | 6, +81 −2 | built in the head | gates `n15`, `n17` |
| F6 | d161259ac5 | gf, module: `JULIA_COMPILE_BY_FACTS=1` compiles a session's own code by facts (a test bed) | 3, +45 −8 | C compiled at its commit; **built in the head (build 4)** | gate `f6_reach_policy`, whole (its test-bed part), passes |
| F9 | e46e654bc3 | Compiler, module: owner-only functions, whose calls are facts at any signature | 7, +93 −6 | C compiled at its commit; built in the head | `gates/g-f9_owner_only.jl` (new, no trait) passes |
| F10 | 5bcf29370f | gf: keep what a definition ends of the deep class, for a tool to take | 5, +95 | C compiled at its commit; built in the head | `gates/g-f10_deep_endings.jl` (new) passes |
| F11 | 240520472a | Compiler, gf: fully typed mode, a check at the start of facts code that dispatches at run time | 13, +127 −6 | C compiled at its commit; built in the head | `gates/g-f11_fully_typed.jl` (new) passes |
| F12 | c325ea04fa | Compiler: a compile request takes the code of any equivalent cached entry, a compiled one first | 1, +25 −2 | built in the head | `motiv/g-twice.jl`: 0 instances compiled twice for one result in the head's system image (vanilla 0); gate `f3_policy_code` |

**In all:** 32 files, 1,555 lines added, 133 removed (the smallest series, F0 to F8 with S1: 28 files, +1,189 −130). Compile checks: `logs/g-compile-checks.log` (worktree `wt/w19-check`, made for them).

**The head's checks** (build 4, `logs/g-checks-facts-head.log`): gates `f1_facts_sites`, `f3_policy_code`, `f4_g2_bit`, `f5_return_type`, `f6_reach_policy` (whole, with F6), `n15_image_policy`, `n17_rtsite_targets` pass; `f7_membership_edges` fails (it needs sets); the facts-only copies `f-f2`, `f-f6` and the new gates `g-f9`, `g-f10`, `g-f11` pass.

**The nine loads on the head** (`f-loads.sh`, unchanged harness; `logs/g-loads-facts-head.log`; a warm-up and 2 runs per cell, load 7.8–8.7): by facts 14 of 3,461 own image instances lost (G2 1,372), plainly 424 of 4,662; the work after the loads (A) 1.36–1.46 s by facts against 5.18–5.29 s; order B 2.45–2.50 s against 6.11–6.20 s. The facts cells are the second part's (14 of 3,461; 1.43–1.45 s): neither S1's fix, nor `!==` once, nor F6, F9 to F12 change them. Plainly 4,662 against 4,670: the packages' plain images hold 8 instances fewer (not read; `!==` at the packages' call types is the likely cause).

**F4's cut.** Each third compiles on the one below (C compiled and linked; Julia parsed); only F4c's tree (= F4) is built. What holds between them:
- F4a alone: a method of a module compiled by facts runs facts code wherever it is called (the policy is the CodeInstance's, and every lookup takes the policy it wants); a boundary method runs plain code from every caller; a facts caller's callee of the other policy is inferred in the caller's inference. Reflection with the plain interpreter at a facts method may cache a plain CodeInstance of it, which nothing runs. Sound, not yet per caller.
- F4b adds the entries per policy (dispatch, builtins, codegen, interpreter): a boundary runs the caller's policy's code.
- F4c adds inference across policies (`typeinf_other_policy`, the compile queues, reflection's uncached top frame).
- The cut needs one hand-made hunk: F4a's `_jl_invoke` asks the policy the runtime reaches with (`mi_policy_facts_at(mfunc, JL_REACH_RUNTIME)`), which F4b replaces by the caller's `reach`.

**The seams of the new parts** (the facts-only form; what the final tree adds):

| Where | The series | The final tree adds | Added by |
|---|---|---|---|
| the module options word | `jl_module_t.options`, `jl_set_module_option`, `jl_get_module_options`, `Expr(:meta, :module_option, bit << 1 \| value)`, `enum jl_module_option` (owner_only 64; F11: fully typed 16, 32) | named `trait_options`, `jl_set_module_trait_option`, `jl_get_module_trait_options`, `:trait_option`, bits as literals; bounded 1, no_pirates 2 | S3 (rename), T9 |
| `is_owner_only` (`facts.jl`) | the binding flag; the module option and the public flag | `jl_binding_open_operation_p` (a trait's operation open to its members), `BINDING_FLAG_OPEN_OPERATION` 0x20 | T10 |
| the deep endings (`gf.c`) | kinds `:definition`, `:deletion`, `:validation`; `deep_ending_push`/`pop` static | kind `:membership`, the exported `jl_deep_ending_push`/`pop` and their calls in `datatype.c` | T5, T8 |
| `jl_method_fully_typed` (`module.c`) | reads `m->module->options` | reads `trait_options` | S3 (rename) |
| `jl_method_policy` | F6's test-bed clause, F11's fully typed clause, in that order | the same | — |

**Commit messages.** In `w19-facts-split` every subject is `component: summary`; the bodies say what, why and the test, and the labels F*n*, S1 and "the series" are gone from them but for the test lines of F9 to F12, which name the gates' directory (the tests are not in Julia's `test/` yet). The branches `facts/00` to `facts/08` keep the second part's subjects (`facts F<n>: …`).

## The two series together: `w19-g-facts`

`w19-stack` (series G, the 18 patches) with the facts series on top (`w19-facts-v2`, cherry-picked without a conflict), and one commit by meaning: 541d9fa6fd "gf: the dispatch profiler takes the call site from `apply_generic_reach`'s `ip`" (`dp_ip = ip`, the final tree's line). 32 files, 1,556 lines added, 134 removed over the stack. Built once (build 5).

- **The gates** (`logs/g-checks-g-facts.log`): as on the facts head: `f1`, `f3`, `f4`, `f5`, `f6` (whole), `n15`, `n17` pass, `f7` fails (sets); `f-f2`, `f-f6`, `g-f9`, `g-f10`, `g-f11` pass. `!==` 1 instance; a method of `!==` invalidates 244; `preserve_handle` 1; no instance compiled twice.
- **The dispatch profiler** with `dp_ip = ip` names the dynamic calls' sites one by one (`logs/g-dispatch-profile-g-facts.log`).
- **Base's tests** (`logs/g-tests-g-facts.log`; `Base.runtests([...]; ncores=1)`, load 4.1–4.9): `worlds`, `Compiler/invalidation`, `Compiler/effects`, `Compiler/inference`, `core`, `reflection` pass (7,357,364 pass, 25 broken, as on the facts head of the second part).
- **`precompile` alone fails** on `w19-g-facts` (430 pass, 1 error; `logs/g-tests-g-facts-precompile.log`): the "code caching" test's branch for an instance's internal callers reads `(be.def::Method).def`, which no backedge satisfies (a backedge's `def` is a MethodInstance); on v1.13.2, on `w19-stack` and on the second part's facts head no `Int16` instance of the test's `f` has a backedge, so the branch never runs. On `w19-g-facts` it has backedges and the branch runs. With that line as `next` has it (`(be.def::Core.MethodInstance).def::Method`, the plan's §5 last bullet) `precompile` passes, 457 tests (the tree's file restored afterwards). Which part makes the branch live is not found; `precompile` was not run on the new facts head (build 4).
- **The nine loads** (`logs/g-loads-g-facts.log`; a warm-up and 2 runs per cell, load 3.2–5.0): by facts 14 of **3,487** own image instances lost (G2 **2,773**), plainly 424 of 4,685 (G2 2,642); the work after the loads 1.38–1.41 s by facts against 5.27–5.29 s. **G changes the facts cells' make-up, not the result:** the packages' facts images hold 26 instances more and twice as many carry the G2 bit (1,372 on the facts head; G's patches take calls off abstract signatures), and the same 14 are lost.

## `threads` on vanilla

v1.13.2 under the same environment (`env.sh`: `JULIA_NUM_THREADS=4`, `JULIA_CPU_THREADS=4`): 163 pass, the same 5 fail at `threads.jl:472` (a child process with a CPU affinity of `n` cores reads `"1"` where `n ÷ 2` is expected; `logs/g-tests-vanilla-threads.log`). The failures are the environment's, not F4's.

## Builds (third part)

`WIDE=0 tools-local/build.sh wt/w19-julia` (`-j4`, niced, every image stage rebuilt), one after another. Logs: `logs/g-build<n>-*.tw-build.log`.

| Build | Branch | Commit | Load at start (of 128) | Wall | `sys.so` (bytes) | Compiler stage | Result |
|---|---|---|---|---|---|---|---|
| 1 | `up/19` (second part's, for the profile) | 3f8281f25c | 1.57 | 758 s | 194,791,456 | 286.6 s | BUILD EXIT 0 |
| 2 | `up/19`, the walk without the type fix | 8dd33781d9 | 4.04 | 665 s | not recorded | 287.1 s | BUILD EXIT 0 |
| 3 | `up/19-callsig-backedge-v2` | 2e9675d8aa | 2.00 | 676 s | 194,871,752 | 290.2 s | BUILD EXIT 0 |
| 4 | `w19-facts-v2` (F0 to F12) | 7315c0b1bd | 4.54 | 768 s | 195,636,792 | 298.5 s | BUILD EXIT 0 |
| 5 | `w19-g-facts` | 541d9fa6fd | 3.96 | 768 s | 197,700,544 | 299.3 s | BUILD EXIT 0 |

Five of the ten builds. The tree `wt/w19-julia` is left at `w19-g-facts` (build 5). Besides: `make -C src` at F4a, F4b, F6, F9, F10, F11 in `wt/w19-check` (`logs/g-compile-checks.log`).

## What stays for later: the traits series (listed, not made)

| Part | What it needs from the series as it stands | Seams in the series |
|---|---|---|
| T1 Core's types and slots | nothing of F; series G for `runtime_internals.jl` (the flags masks next to `up/02`'s helpers) | `jltypes.c`'s `Method` field list: T10's `declared_result` goes before `facts` (F0), so a field index moves |
| T2 sets and memberships | T1; F4a's functions for its query world | the membership query world around `jl_type_infer_policy` (F4a), `jl_call_in_typeinf_world`, `jl_gdbcodetyped1` |
| T3 intersections | T2 | none |
| T4 dispatch at sets | T2; G's `up/14`, `up/15` and F4b in `jl_lookup_generic_`/`apply_generic_reach` (E7) | T9's member hook at a miss joins the same function |
| T5 a membership's invalidation | T4; S1's backedge format (a one-element svec, read by `jl_membership_dispatch_walk`); F10 | the deep endings' `:membership` kind and the exported `jl_deep_ending_push`/`pop` |

The order of builds: T1 on `w19-g-facts` (one build; `test/core.jl`); T2 (one; gates `m1_*`, `m2_set_*`, `n10_inputs`, Base's four suites against vanilla); T4 then T3 (one, both; `m2_*`, `n2_all_*`); T5 (one; `n27`, `n28`, `n32`), then the nine loads once more to see that sets leave the facts cells as they are.

## Not done, not verified (third part)

- **The force-pushes were refused** by this session's permissions: `up/19-callsig-backedge`, `facts/s1-callsig-backedge`, `facts/07-g2`, `facts/08-images` and `w19-facts` still name the second part's commits; the new ones are pushed as `…-v2`. Moving the five names is for the main session.
- **`w19-callsig-load`** (two commits on `next`) is parsed, not built.
- **`precompile` was not run on the new facts head** (build 4); it fails on `w19-g-facts` for a test line, and the part that makes that line run is not found.
- **F4a and F4b are not built:** C compiled and linked, Julia parsed; their trees are not the head's. F4a's claim (a boundary runs plain code from every caller until F4b) is read from the code, not run.
- **F9 to F12's tests are gates of this directory,** not tests in Julia's `test/`; F12's test counts code compiled twice and finds 0 on the head as on vanilla, so it does not discriminate there (the case is a build with many entries per instance, E-389).
- **The static check of GC roots** (`w163/sagc.sh`) was not run on F10's and F11's C (two globals and a hook, rooted by both collectors).
- **The plain load's times** are noisy on this host this afternoon (both builds' first runs 900–1,200 ms); the comparison rests on the runs after the disturbance and on the profiles' sample counts.
- **The second part's "269 external instances more"** is not explained: the count moves with each new set of package images (116,630, 116,612 and 116,840 valid instances after the load for `up/19`'s three builds, 116,523 and 116,454 for vanilla's two sets) and does not move the load's time.

# Fourth part: the traits series T1 to T5, and two small items

The brief: `precompile` on the facts head and the part that makes `test/precompile.jl`'s line 977 run on `w19-g-facts`; the tests of F9 to F12 moved into Julia's `test/`; the first five parts of the traits series ([the plan](../../../writeup/plans/2026-11-22-upstream-series.md) §2.3), each a commit on a branch `traits/<nn>-<slug>`, stacked on `w19-g-facts` (the stack `w19-traits`), cut from `45b6d15e34..683ea4fc16` by subject. Comments are rewritten without the references' section numbers, work items or review names; the series keeps the trait language's terms (set, membership, entry), each defined in the commit that introduces it.

## How to run (fourth part)

```
bash h-run-t2.sh t2      # on wt/w19-julia at T2's last commit: subtype and core, gates m1_* m2_* n10 n2_*, micro-timings, plain load
bash h-run-t4.sh t4      # at T4: subtype and core, the same gates
bash h-run-t5.sh         # at T5: Base's six files, precompile alone, the gates m1_* m2_* n* f*, micro, plain load, the nine loads
julia motiv/h-micro.jl                     # jl_subtype, intersection, the type cache, method matching: ns per call, minimum of 7
julia motiv/h-precompile-root.jl           # test/precompile.jl's Root packages: the Int16 instance's backedges, g1's code
julia tools/h-parse.jl <files>             # a parse check that fails on a parse error
```

## 1. `precompile` on the facts head, and what makes line 977 run

- **`precompile` on the facts head** (`w19-facts` 7315c0b1bd, build 1): 454 pass, alone (`logs/h-tests-facts-precompile.log`).
- **The cause on `w19-g-facts`: F8 with series G's `up/04`.** The test's `g1()` is called from RootA's top level, so its code is reached only dynamically. F8's rule keeps such code in a package image where it carries the G2 bit, of either policy: plain code too. `g1` → `f(::Int16)` is in the deep class only where `oftype`'s conversion error path is typed (`throw_inexacterror` at `::Type{T}`, `up/04`); on the facts head alone it is not. Then RootA's image keeps `g1`'s code with its edge to `f(::Int16)`, the `Int16` instance has backedges after the loads, and the branch reads `(be.def::Method).def` of a backedge whose `def` is a MethodInstance. Shown by reading and by `motiv/h-precompile-root.jl` (`logs/h-precompile-root.log`, `logs/h-precompile-root-facts.log`): on v1.13.2 and on the facts head no `Int16` instance exists after the loads and `g1` has no code; on a tree with G and F (`w19-g-facts`, and the T5 head built on it) the `Int16` instance has 2 backedges and `g1`'s code is loaded (flags `0x1f`: G2, from the image); with a call at an abstract signature put into `f` (`BARRIER=1`) `g1` is outside the class and none of it happens. No build was spent on the bisection.
- **The fix goes with F8:** `(be.def::Core.MethodInstance).def::Method`, as `next` has it, amended into F8 with the reason (below). **A plain package's image keeps more external code under F8**: plain code reached only dynamically and deep G2. That is a behaviour change for plain packages the plan does not list (§5).

## 2. The tests of F9 to F12 in Julia's `test/`

Branch **`w19-facts-tests-v2`** (49e49a19c2), restacked from `w19-facts-split`'s F7 (3cb4ff6254): F8 (325c69d9c0, with the `precompile.jl` line), F6 (14b9e30259), F9 (47e8ec4f4e), F10 (609f1af65f), F11 (b689e3cb31), F12 (49e49a19c2). The tree is `w19-facts-split`'s plus `test/facts.jl` (new, 228 lines, added to the test list in `test/choosetests.jl` by F9) and the `precompile.jl` line. Each commit adds its testset and names it in its message:

| Part | Testset in `test/facts.jl` | From |
|---|---|---|
| F9 | "owner-only functions" (23 tests) | `gates/g-f9_owner_only.jl` |
| F10 | "what a definition ends of the deep class" (19) | `gates/g-f10_deep_endings.jl` |
| F11 | "fully typed mode" (24) | `gates/g-f11_fully_typed.jl` |
| F12 | "a compile request takes the code of a compiled equivalent entry" (6) | new: it discriminates, where `motiv/g-twice.jl` counted 0 on vanilla and head alike: an uncompiled equivalent entry at the head of an instance's cache and the compiled one after it, `jl_get_ci_equiv` finds the first and `equivalent_cached_ci` the compiled one |

All 72 pass on the facts head (build 1; `logs/h-facts-tests-facts.log`). **`w19-facts-tests`** (df29ab9cde, pushed first) has an F12 test that fails (it inserted the uncompiled entry with `jl_mi_cache_insert`, which orders compiled entries first); `-v2` amends it; the first name is left as it is. Julia's own guidance for agents (`CLAUDE.md` of the julia tree) asks for tests in existing files unless told otherwise; a new file for a new compile mode is my choice, to be confirmed.

## 3. The traits series T1 to T5

The stack `w19-traits` (8a0754ebe8) on `w19-g-facts` (541d9fa6fd). Sizes: files, lines added and removed against the part below.

| Part | Branch, commit | Subject | Size | Checked | Test |
|---|---|---|---|---|---|
| T1 | `traits/01-core-slots` 8d0ade4061 | julia.h, jltypes: the layout for sets and memberships (`TypeName.memberships`, `Core.MembershipEntry`, `DataType.has_open_set`) | 8, +142 −27 | C compiled and linked; built in T2's build (3) | `test/core.jl` |
| T2a | `traits/02a-declaration` d47fd35e91 | datatype, subtype: declaring a set and a membership, with its checks and its worlds | 11, +595 | C compiled and linked | with T2d |
| T2b | `traits/02b-subtyping` 0fcd07f6a9 | subtype: a membership is a supertype in the worlds it is in force | 3, +376 −21 | C compiled and linked | with T2d |
| T2c | `traits/02c-caches` e3c4ddb9f8 | subtype: a non-member's answers at a set without the walk, and reachability memoized per world range | 1, +162 −7 | C compiled and linked | with T2d |
| T2d | `traits/02d-compiler` 33642b6684 | Compiler, codegen, gf: inference asks memberships in the world it infers for, and folds no answer a membership could change | 13, +354 −14 | **built (build 3)**: `subtype`, `core` pass; gates below | `test/subtype.jl` "Sets and memberships" (6 testsets) |
| T3 | `traits/03-all` a91da281f5 | jltypes, subtype: intersections `All{X, Y}` in their normal form | 9, +524 −6 | built with T4 (build 4) before one line was added (the `All` wrapper's bit, found by `n2_all_form`), then compiled; built in T5 | `test/subtype.jl` "intersections All{X, Y}" |
| T4 | `traits/04-dispatch` 1d3582cc6c | gf, typemap, subtype: dispatch at sets, a match's worlds through memberships, and the ambiguity report at a membership | 8, +733 −3 | **built (build 4)**, T3's line aside | "dispatch at sets", "the ambiguity report at a membership" |
| T5 | `traits/05-invalidation` 8a0754ebe8 | gf, datatype: a membership invalidates as a method does, and a membership taken back | 6, +1,345 −148 | **built (build 5)**: the tests and gates below; the nine loads | "a membership invalidates as a method does", "a membership taken back" |

**In all:** 29 files, 4,184 lines added, 183 removed (the plan's estimate for T1 to T5 with their share of TX: about 4,060 and 260). By file: `gf.c` +1,749, `subtype.c` +1,164, `datatype.c` +527, `jltypes.c` +251, `test/subtype.jl` +298, the rest under 90 each. The commit messages say what, why, the rule in plain words and the test; subjects in Julia's `component: summary` form.

**What each part adds, and what it leaves.**
- **T1** adds only what T1 to T5 read: the bits `open_set`, `never_member`, the byte `input_params`, the field `memberships`, `Core.MembershipEntry` without its `method` field, `DataType.has_open_set` and the 32-bit flags word. The plan's T1 also has `contract`, `declared_fields`, `operations`, `erases`, `closed_after_load`, `Core.All`, `Core.Callable`: each now comes with the part that reads it (T10, T14, T7, T3, T12), so no slot is without a reader (plan §5's rule).
- **T2** in four, each compiling on the one below and read alone: (a) the declaration, its checks, the entries with worlds and the query world; (b) subtyping and intersection through entries, type values, invariant parameters; (c) the memo and the non-member's fast path; (d) inference's query world and the compiler's gates. Built and tested at (d).
- **T3** brings `Core.All` whole (the type, the normal form, subtyping, intersection, specificity, printing). Before it two sets that no entry relates do not meet (the match's worlds carry the change).
- **T4** is dispatch without the walk: a membership declared after a call at the member was compiled or cached does not change that call until T5. T4 and T5 go together; the commit says so.
- **T5** is the walk and the removal walk, with `jl_delete_membership`.

**Hand-made hunks** (forms the final tree does not have):
- `jl_declare_membership` in each part's form: T2a without the membership's method (T6), strict mode (T9), the candidates (T11), the session's list for images (T8) and the deep ending; T4 adds the report; T5 the walk and the deep ending (named by the entry, not the method).
- `jl_delete_membership` without the method's end (T6), the candidates (T11) and the member states (T9).
- `jl_typename_reaches` without the memo in T2a (T2c replaces it); `jl_entry_intersection` as a plain intersection in T2a (T3 pairs instances by input).
- The compiler's gates in their frame-free form (T2d): no negative folded where a later membership could make it true, no positive through an entry; `isa`'s condition narrows no branch at a set; `new`'s field test through an entry is not proved. The final tree records entries and absence edges (T6) and folds final negatives (T7).
- `obviously_disjoint` and `obvious_subtype` without the fast path in T2b (T2c adds it).
- The ambiguity report calls `ml_matches` and has no unmet-intersection clause (T7's `jl_has_unmet_argument`; `ml_matches_i` comes with strict mode, T9).
- The query world around the image's compile queues without the closed build's rounds (T16).
- Removed against the final tree: `jl_set_membership_prune` (a measurement switch), `jl_set_membership_walk_invalidates` (plan §5), `jl_membership_replay_sigs` (the library's strict check, T9), `jl_member_states_forget` (T9), `jl_membership_method_end` (T6), the index of each function's methods at sets (T6/T10), `jl_open_set_methods_of` (T8/T16), `jl_supertrait_instances` (T10), `jl_membership_entries_for` (T6).
- Kept: the walk's counters (`jl_membership_stat`, gates read them) and `JULIA_MEMBERSHIP_LOG` (a debugging switch, for plan §5's list).

## 4. What plain code pays, at T2 and at T5

No set declared; vanilla v1.13.2 the same hour; one thread. The stacks are on `w19-g-facts` (series G and the facts series), whose own cost was measured in the third part; `subtype.c`, `typemap.c` and the intersection are touched by neither, so their difference is the traits parts'.

**Micro-timings** (`motiv/h-micro.jl`; ns per call, minimum of 7 rounds, two rounds of processes each; `logs/h-micro-t2.log`, `logs/h-micro-t5.log`):

| | vanilla | T2 (33642b6684) | T5 (8a0754ebe8) |
|---|---|---|---|
| `jl_subtype` (18 plain pairs) | 238.4–239.4 | 250.0 (+4.7 %) | 268.1–268.4 (+12.4 %) |
| `jl_type_intersection` | 277.7–280.5 | 301.1–304.4 (+8.3 %) | 308.8–308.9 (+11 %) |
| the type cache (`apply_type` of `Tuple{T, S}`, `Vector{T}`) | 77.3–78.2 | 77.0–77.9 (±0) | 79.0–79.2 (+2 %) |
| method matching (`_methods_by_ftype`, 6 signatures) | 177.8–180.1 | 184.3–185.1 (+2.8 %) | 186.5–186.8 (+4.3 %) |

- T2's subtyping cost is the walk's new state and the checks at the points where the walk has found no answer (`noentry`, `subtype_fresh`, the `open_set` tests, `forall_exists_equal`'s wrapper); T3 and T4 add the `All` tests in `subtype()`, `obvious_subtype` and `intersect` and the specificity tests: T5's +12 % is T2's +5 % and theirs. **A tension for the plan's claim that a session without sets pays one bit per question:** each test reads a bit, but at every step of the walk. Proposal: decide once at the entry of `jl_subtype_env` and of the intersection whether either side has the `has_open_set` bit, keep it in the environment, and skip every membership and intersection branch when neither has (the bit is final when a type is built, and a type without it cannot meet a set).
- **The session** (`motiv/f-plain.jl`, upstream CSV and DataFrames plainly; a warm-up and 3 fresh processes, interleaved; `logs/h-plain-t2.log`, `logs/h-plain-t5.log`):

| | `using CSV, DataFrames` | valid CodeInstances after the load | after the work | first work |
|---|---|---|---|---|
| vanilla | 654–699 ms | 116,523 | 117,115 | 4.39–4.41 s |
| T2 | 655–689 ms | 118,094 | 118,686 | 4.44–4.46 s (+1.2 %) |
| T5 | 676–686 ms | 117,911 | 118,503 | 4.53–4.54 s (+3 %) |

  The CodeInstances' difference is the stack below (`w19-g-facts`: G2 bits, `!==` once, kept external code). Digests equal. Load 3.0–5.0.

## 5. On T5's head

- **Base's tests** (`Base.runtests([...]; ncores=1)`, load 4–6; `logs/h-tests-t5.log`): `subtype`, `core`, `worlds`, `reflection`, `Compiler/inference`, `Compiler/invalidation` pass: 7,674,456 pass, 64 broken. `precompile` alone: 430 pass, 1 error, line 977 (the item above: the fix is in F8 of `w19-facts-tests-v2`, not in `w19-g-facts`, which T1 to T5 stack on).
- **The gates** (`run_all.sh` with the stub library; `logs/h-gates-t5.log`): **passing** `m1_*` but one (10), `m2_*` but three (16), `n10_inputs`, `n2_*` (6), `n7_guards`, `n15`, `n17`, `n21`, `n25_image_before_set_method`, `n27_invariant_parameter`, `n28_wide_caller`, `n32_nested_set`, `n9_fully_typed`, `f1`, `f3`, `f4`, `f5`, `f6`. **Not runnable before a later part:**

| Gate | Needs | Gate | Needs |
|---|---|---|---|
| `m1_no_wrappers` | `Core.Dynamic` (T14), the contract slot (T10) | `n22_declared_assert`, `n23_contract_image` | T10 (and T8) |
| `m2_ambiguity_called_before`, `_declared_super`, `_predates` | strict mode (T9) | `n24_hook_compile_queue` | the member hook (T9) |
| `n11_late_shadow`, `n16_declared_result` | declared results (T10) | `n29_membership_method` | `Core.implements` (T6), `Dynamic` (T14) |
| `n12_image_instances`, `n3_image_memberships` | memberships in images (T8; n12 also `Callable`, T12) | `n30_where_variable`, `n33_compiled_as_julia` | the kept forms (T14) |
| `n13_attribute_free_vars`, `n14_callable_args`, `n8_callable` | `Callable` (T12; n13 also T14) | `n31_isa_narrows` | `isa` narrowing (T6) |
| `n18_closed_after_load`, `n20_unmet_lookup` | final negatives (T7) | `n34_closed_invoke_compiled` | the closed build's verifier (T16) |
| `n19_io_trait` | `IO`'s contract (T10, T11, T13) | `f2_policy_flags` | the trait options `bounded`, `no_pirates` (S3, T9) |
| `f7_membership_edges` | the membership's method and the record (T6) | `n8_callable_box`, `n26`, `n35`, `n36` | the library |

  At T2 (build 3; `logs/h-gates-t2.log`) `m1_*` pass but `m1_no_wrappers` and `m1_typevalue_isa` (a caller compiled before the membership dispatching at the set: T4, T5); at T4 (build 4; `logs/h-gates-t4.log`) the dispatch gates that need no walk pass, `m2_dispatch_worlds`, `_future_min_worlds`, `_parametric_replay`, `_stale_caller`, `_vararg_union_worlds`, `_volume` wait for T5 and pass there.
- **The nine loads** (`f-loads.sh`, unchanged; `logs/h-loads-t5.log`; a warm-up and 2 runs per cell, load 3.0–3.9): by facts 14 of 3,487 own image instances lost (G2 2,773), plainly 424 of 4,685; the work after the loads (A) 1.40 s by facts against 5.33–5.35 s; order B 2.44–2.48 s against 6.26–6.28 s. **The facts cells are `w19-g-facts`' exactly** (14 of 3,487; G2 2,773): the sets' types, the walk and the gates change nothing with no set declared. The plain work after the loads takes 5.33–5.35 s against 5.27–5.29 s on `w19-g-facts` (the subtyping cost above).

## 6. The seams

| Where | T1 to T5 | The final tree adds | Added by |
|---|---|---|---|
| `jl_membership_t`, `MembershipEntry` | 8 fields | `method` (the membership's method of `Core.implements`) | T6 |
| `jl_typename_t` | `open_set`, `never_member`, `input_params`, `memberships` | `erases`, `closed_after_load`; `contract`, `declared_fields`, `operations` | T14; T7; T10 |
| `jl_set_open_set` | the bit and the cached types' bits | `closed_after_load` set for every set | T7 |
| `jl_declare_membership` | checks, entry, index, report, walk, deep ending by entry | the membership's method and its activation, strict mode's refusal, the candidates, `jl_declared_memberships`, the deep ending named by the method | T6, T9, T11, T8 |
| `jl_delete_membership` | the entry ends, the removal walk | the method ends, the candidates and the member states forgotten | T6, T11, T9 |
| the compiler's gates (`typeutils.jl`, `tfuncs.jl`, `abstractinterpretation.jl`, `optimize.jl`, `cgutils.cpp`, `codegen.cpp`) | frame-free: no negative where a membership could join, no positive through an entry | the frame records entries (an `invoke` edge to the membership's method) and absence edges; `isa` narrows the true branch; `IR_FLAG_TYPES_PROVEN`; final negatives fold with their cell; `All` in `isa_tfunc` | T6; T7 |
| `jl_type_infer_policy`, `jl_call_in_typeinf_world`, `jl_gdbcodetyped1` (F4a's) | the query world | the member hook's queue drained after inference | T9 (E15) |
| `typeinf_ext_toplevel` | the query world around `compile!` | the closed build's rounds | T16 |
| `ml_matches` | the match's worlds through entries | `ml_matches_i` (a world past the counter for strict mode), the dropped matches' final cells | T9; T7 |
| the ambiguity report | `ml_matches`, no unmet clause, warnings only | `jl_has_unmet_argument`, findings for strict mode (`jl_membership_ambiguities`) | T7; T9 |
| `jl_index_open_set_methods`, `jl_method_table_activate` | the index by set | `Core.implements`' methods skipped; each function's methods at sets; `jl_open_set_methods_of` | T6; T6/T10; T8/T16 |
| `jl_method_table_disable` | unchanged | a membership's method refused, the deletion hook | T6; T9 |
| the deep endings (F10) | `deep_ending_push` exported as `jl_deep_ending_push`/`pop`, kind `:membership` from the declaration and the taking back | the cause named by the membership's method; the activation's | T6; T8 |
| backedges (S1's format) | the walk and the removal walk judge a backedge kept as `svec(callsig)` at the call's signature (`_invalidate_dispatch_backedges`' `skip`) | — | — |
| `staticdata.c` | nothing: memberships are not kept by images | `ext_memberships`, an entry's worlds reset, the activation, the indices kept by the system image | T8 |
| `subtype.c` | — | `jl_supertrait_instances`, `jl_membership_entries_for`, `jl_set_meets_kinds` exported | T10; T6; T7 |

## 7. Builds (fourth part)

`WIDE=0 tools-local/build.sh wt/w19-julia` (`-j4`, niced, every image stage rebuilt), one after another. Logs: `logs/h-build<n>-*.tw-build.log`.

| Build | Branch | Commit | Load at start (of 128) | Wall | `sys.so` (bytes) | Compiler stage | Result |
|---|---|---|---|---|---|---|---|
| 1 | `w19-facts` (facts head) | 7315c0b1bd | 2.83 | 757 s | 195,736,456 | — | BUILD EXIT 0 |
| 2 | `traits/02d-compiler` (first form) | c5ed3d890b | 3.49 | 768 s | 198,101,640 | 302.3 s | BUILD EXIT 0; `probe` compiled before a membership kept `false`: the branch condition of `isa` folded |
| 3 | `traits/02d-compiler` | 33642b6684 | 3.16 | 707 s | 198,143,248 | 303.3 s | BUILD EXIT 0 |
| 4 | `traits/04-dispatch` (T3 before its fix) | 280efb6cc3 | 3.40 | 789 s | 198,312,328 | 305.4 s | BUILD EXIT 0 |
| 5 | `traits/05-invalidation` | 8a0754ebe8 | 4.97 | 778 s | 198,343,368 | 304.4 s | BUILD EXIT 0 |

Five of twelve. `wt/w19-julia` is left at T5 (8a0754ebe8). Compile checks (`make -C src`) at every commit in `wt/w19-check`. The T5 system image is 198.3 MB against `w19-g-facts`' 197.7 MB (+0.3 %) and vanilla's 194.3 MB.

## 8. What stays for later: T6 to T17

| Part | What it needs from the stack as it is | Order of builds |
|---|---|---|
| T6 the membership's method; folds and their edges | T5; `MembershipEntry.method`; the frame forms of the gates; F7's class (`edges_satisfy_g2`: an absence edge and a membership's instance as facts, E4); `Core.implements` in `boot.jl`; the deep ending named by the method | 1 (T6): `n29`, `f7_membership_edges`, `n31`, `m1_worlds_minworld` |
| T7 final negatives, closed after load | T6; `closed_after_load`, `jl_module_t.loaded`; `drop_unmet_matches` in `ml_matches`, `MethodLookupResult.cells`, `isambiguous`'s unmet filter; Base's loader marks | 2 (T7): `n18`, `n20`; `reflection` |
| T8 memberships in images | T5 (the walk at activation), T7 for final cells; `staticdata.c`'s list and tags, the session's list from `jl_declare_membership`, activation's conflicts | 3 (T8): `n3`, `n12` (with T12 for its `Callable` part) |
| T9 the library's hooks; strict mode | T2 (the declaration), T4 (the report's findings, `ml_matches_i`), T5; the module options word renamed (S3) | 4 (T9 with T14): the library's suite (`m2_ambiguity_called_before`, `_declared_super`, `_predates`, `n24`) |
| T14 the kept forms, the despecialization at a set | T9 (the expansion hook); `TypeName.erases` | with T9 |
| T10 declared results, fields, contracts, operations | T2; `contract`, `declared_fields`, `operations` slots; `Method.declared_result` (E1: a field index of `Method` moves past F0's `facts`); `BINDING_FLAG_OPEN_OPERATION` in F9's `is_owner_only` (E3) | 5 (T10, T11, T15): `n16`, `n22`, `n23`, `n11` |
| T11 the split and the table | T10, `up/16` | with T10 |
| T15 the `trusted` effect | T10, F1's `Effects` (E9) | with T10 |
| T12 `Callable` | T2, T15; `post_boot_hooks` opening it with inputs; `Function`'s entry in `base/Base.jl` | 6 (T12, T13): `n8`, `n13`, `n14` |
| T13 `IO`'s contract, `IOContext{IO}` | T10, T11 | with T12: `n19`, `show`, REPL |
| T16 a closed build | T11, T12, F4, F8, F11; the rounds in `typeinf_ext_toplevel` | 7: `n34`, `w166/build_c.sh` |
| T17 the definition-time check's interpreter | none | with T16 or alone (Compiler only: one build) |

Then the gates in full, Base's suites against vanilla and the nine loads at the head: about seven builds.

## 9. Where the plan was wrong or incomplete (fourth part)

- **T1 is smaller than planned:** the slots and bits nothing reads before T6 go with their readers; `Core.All` with T3, `Core.Callable` with T12.
- **T2 needs the compiler's gates** (plan §4.8, which the plan puts in T6 and T7): without them code compiled before a membership keeps a folded answer; build 2 showed it (`isa`'s branch condition folded to `false`). T2 has them in their frame-free form; T6 replaces them.
- **Type values (§4.10) are in T2,** inside the subtyping walk; the plan assigns them to no part.
- **T4 is not sound alone** for a call compiled or cached before a membership: T4 and T5 go together.
- **T5 includes `jl_delete_membership`** (the plan lists only the removal walk) and exports F10's deep-ending push (E5).
- **The traits series needs `w19-facts-tests-v2`'s F8** for Base's `precompile` to pass (line 977), or the line in its own first part.
- **F8 changes plain packages' images** (they keep plain code reached only dynamically where it is deep G2): not in plan §5.
- **Subtyping costs plain code** +5 % at T2 and +12 % at T5 (micro), the first work +1 % and +3 %: the plan's "one bit" is per step of the walk, not per question.
- **Sizes:** T1 to T5 are 4,184 lines added (the plan's estimate with their share of TX about 4,300).

## Not done, not verified (fourth part)

- **T1, T2a to T2c and T3 (in its final form) are compiled, not built alone.** T1 is built in T2's build (3), T3's final form in T5's (5).
- **No test runs a membership in a package image** (T8); a package that declares memberships and is precompiled on this stack keeps its entries on its own types' TypeNames with the building session's worlds, unactivated.
- **The static check of GC roots** (`w163/sagc.sh`) was not run over T1 to T5's C (new globals `jl_set_entries`, `open_set_methods`, both rooted by both collectors).
- **The subtyping tension** (above) is recorded here only; its proposal is not built.
- **Comments and commit messages** are my wording and not reviewed. The traits commits carry `Co-Authored-By: Claude <noreply@anthropic.com>`.
- **`w19-facts-tests`** (df29ab9cde) is superseded by `-v2` and left as pushed.

# Fifth part: the traits series T6 to T10, on the facts series with its tests

The brief: the stack moved onto the facts series with its tests (`w19-facts-tests-v2`); then T6 to T10 of [the plan](../../../writeup/plans/2026-11-22-upstream-series.md) §2.3, each a commit on the one below (a part too large for one review cut in parts), cut from `45b6d15e34..683ea4fc16` by subject, comments without the references' section numbers, work items or review names.

## How to run (fifth part)

```
bash i-run.sh <tag> "<tests>" "<gate patterns>" [micro] [plain]   # on wt/w19-julia: Base's tests (precompile alone), the gates, micro-timings, the plain session
bash i-run-t10.sh t10                                                # T10's head: all of the above, the gates' copies gates/i-*.jl, TraitWorld's load, the nine loads
julia --project=experiments/implementation w19/gates/i-n18_closed_after_load.jl   # a copy of a gate (below)
```

## 1. The stack moved

`w19-traits-v2-base` (11e089de85): `w19-stack` (series G, 18 commits), the facts series with its tests (`w19-facts-tests-v2`'s 16 commits: F0 to F12 with F4 in three, F8 with the line of `test/precompile.jl`, F9 to F12 with `test/facts.jl`), then the `dp_ip = ip` commit; every commit cherry-picked without a conflict. T1 to T5 on it, as `traits-v2/<nn>-<slug>` (the fourth part's commits, unchanged but for their parent): 

| Part | Branch | Commit (was) |
|---|---|---|
| T1 | `traits-v2/01-core-slots` | 5a42081741 (8d0ade4061) |
| T2a | `traits-v2/02a-declaration` | 9dc720469a (d47fd35e91) |
| T2b | `traits-v2/02b-subtyping` | 4ed6c9007c (0fcd07f6a9) |
| T2c | `traits-v2/02c-caches` | 4b04eb44ba (e3c4ddb9f8) |
| T2d | `traits-v2/02d-compiler` | b42afd1f60 (33642b6684) |
| T3 | `traits-v2/03-all` | 2b2a9030a0 (a91da281f5) |
| T4 | `traits-v2/04-dispatch` | c0daec60fd (1d3582cc6c) |
| T5 | `traits-v2/05-invalidation` | 2758486a56 (8a0754ebe8) |

The tree at T5 is `w19-traits`' plus `test/facts.jl`, its line in `test/choosetests.jl` and the line of `test/precompile.jl` (`git diff w19-traits traits-v2/05-invalidation`: 3 files). Built (build 1): `precompile` alone 457 pass (`logs/i-tests-stack-precompile.log`); `facts`, `subtype`, `core` 7,671,790 pass, 50 broken (`logs/i-tests-stack-facts_subtype_core.log`). The fourth part's line-977 failure is gone: F8 carries the fix.

## 2. The parts T6 to T10

The stack `w19-traits-v2` (head below) on `traits-v2/05-invalidation`. Sizes: files, lines added and removed against the part below.

| Part | Branch, commit | Subject | Size | Checked | Test |
|---|---|---|---|---|---|
| T6 | `traits-v2/06-membership-method` a86b764265 | Compiler, gf, datatype: a membership is a method of `Core.implements`; answers folded through it hold an edge to it | 17 files, +485 −37 | built (build 2, as fa1fec3410: the commit's test then looked at optimized code; the final form passes at builds 5, 6, 4) | `test/subtype.jl` "a membership's method, and the edges of answers folded through it"; `test/core.jl` the entry's fields |
| T7 | `traits-v2/07-final-negatives` d127a2fc13 | Compiler, gf, datatype: final negatives, and a match met only at an intersection no type is in | 12 files, +577 −13 | built in T8's build (build 5) | `test/subtype.jl` "final negatives" |
| T8 | `traits-v2/08-images` 3d38bca9af | staticdata, datatype: memberships in package images | 7 files, +305 −9 | built (build 5) | `test/precompile.jl` "memberships in package images" |
| T9a | `traits-v2/09a-library-hooks` acce77e827 | gf, method, staticdata: hooks for a trait library at a definition, a deletion, a module's end and an image | 12 files, +304 −5 | compiled (`make -C src`, wt/w19-check) | `test/subtype.jl` "a library's hooks at a definition, a deletion and a module's end" |
| T9b | `traits-v2/09b-member-hook` 250dbcaa14 | gf, staticdata, Compiler: the member hook, at dispatch and in the compile queue | 10 files, +611 −0 | compiled (`make -C src`, wt/w19-check) | `test/subtype.jl` "the member hook" |
| T9c | `traits-v2/09c-strict-mode` a10552facc | datatype, gf: a strict mode for a trait library, which refuses a membership that makes methods ambiguous | 6 files, +193 −8 | built (build 6; T9a and T9b in it) | `test/subtype.jl` "a strict mode" |
| T10 | `traits-v2/10-contracts` 591b21d8c9 | Compiler, datatype, lowering: declared results, fields, contracts and operations | 14 files, +569 −12 | built (build 4, as 153fce6251: one line of `test/precompile.jl` more) | `test/subtype.jl` "declared results, fields and operations"; `test/core.jl` the new fields |

**In all:** 31 files, 3,039 lines added, 79 removed, of which the tests 302 (`test/subtype.jl` +223, `test/precompile.jl` +77). The plan's estimate for T6 to T10 with their share of TX: about 2,000 lines and 260. By file: `gf.c` +931, `datatype.c` +776, `abstractinterpretation.jl` +239, `method.c` +194, `subtype.c` +133, the rest under 90 each.

**What each part holds, and where it departs from the plan.**
- **T6** the membership's method and the positive folds. `Core.implements` (`base/boot.jl`), the method made at the declaration and ended at the taking back, the entry's `method` field; the recording form of every positive gate (`isa`, `<:`, a dispatch match, `new`'s field tests, a store's and a `typeassert`'s test with `IR_FLAG_TYPES_PROVEN`), `isa`'s narrowing, the deep class's clause for a membership's instance. **The absence edge is not in T6:** nothing makes one before T7 (a negative folds only where it is final), so it goes with T7, where it is first read. `typesubtract`'s two gates, missing from T2d, come with T6.
- **T7** final negatives: a negative is final where it holds (a concrete non-member; an abstract type whose intersection with the set has no type); the absence signature and its edge; the drop of an unmet match at a final pair, with its signatures handed to inference; `isambiguous` and the report pass over an unmet intersection. **Not made, no reader:** the bit `closed_after_load` (every set has it; `jl_membership_final` asks `open_set`) and a module's `loaded` mark (`type_declarers_loaded` has no caller in the final tree, and `jl_membership_final` does not read the mark). Base's walk at the end of its build (`base/sysimg.jl`, `jl_invalidate_code_instances_new_world`) serves `Callable`, the only set of Base's build: it goes with T12. The match's query world (`ml_matches_c`), T4's by subject, comes with T7's split of `ml_matches`.
- **T8** memberships in package images; the system image keeps three indices (the methods at sets, the entries at each set, the absence signatures). **The member checks an image keeps** go with T9b: they are the member hook's state.
- **T9** in three, as T2 was: **T9a** the hooks at a definition, an expansion, an image, a module's end and a deletion, with the scope options `bounded` and `no_pirates` (bits 1 and 2 of the facts series' options word `jl_module_t.options`, enum `jl_module_option`, meta `:module_option`); **T9b** the member hook, at dispatch and in the compile queue, its states, the checks an image keeps; **T9c** strict mode. Each compiles on the one below; the stack is built at T10.
- **T10** declared results, fields, contracts and operations, and `BINDING_FLAG_OPEN_OPERATION` in `is_owner_only` (E3). **Not made, no reader:** `Method.declared_covers` (plan §5 already lists it for removal) and each function's list of methods at sets (`index_func_set_method`, `jl_func_methods_at_sets`: no caller in the final tree, nor in the library). `jl_method_set_declared_result(m, rt)` takes no `covers` argument (`base/iotrait.jl`, T13, calls it with three).

**The commit messages** say what, why, the rule in plain words and the test; subjects in Julia's `component: summary` form. T6 to T10 carry `Co-Authored-By: Claude <noreply@anthropic.com>`.

### Two defects of the final tree found while cutting

- **A final negative does not bound the code's worlds** (`next`'s `negative_fold_blocked(a, b, sv)` and the lookup's drop): the frame records the absence edge but not the worlds in which the pair's absence holds. Code inferred for a world before a membership (`Base.invoke_in_world`, a task in an older world) is then valid in the later worlds too and answers the old negative there; code inferred after a membership is taken back is valid in the older worlds where it held. Found by the second part's tests of T2 (`late5_xb`) and T5 (`is_ix`), which failed at T10's first build (`logs/i-tests-t10-build3.log`). **Fixed in T7** at the rule: the code's worlds are bounded by the worlds in which no method meets the absence signature (`absence_worlds`, the lookup Julia's validation of the edge makes); the lookup's result is bounded the same way where it dropped a match (`_findall`). Both tests pass at T10's second build. `next` needs the same two lines.
- **`Base.isambiguous`'s docstring attaches to `has_unmet_intersection`** in `next` (`base/reflection.jl`: the helper sits between the docstring and the function). In T7 the helper stands before the docstring.

### Hand-made hunks (forms the final tree does not have)

- `negative_fold_blocked(a, b, sv)` in T6 forwards to the frame-free gate; T7 gives it the final form (and `absence_worlds`, above).
- `is_implements_sig` (`facts.jl`) for the final tree's `is_absence_sig` (a membership's method and an absence edge are both signatures of `Core.implements`).
- `jl_declare_membership` in each part's form: T6 the method and the deep ending by it; T8 the session's list for images; T9c strict mode's refusal; without the candidates (T11).
- `jl_delete_membership`: T6 the method's end; T9b the member states forgotten; without the candidates (T11).
- `jl_activate_memberships`: T8 without the inactive method's refusal (T9a) and the candidates (T11); `jl_memberships_activated`: T8 without strict mode's collection (T9c).
- `ml_matches`: T7 makes `ml_matches_i` (cells out) with the wrappers `ml_matches_c` and `ml_matches`, the counter's check in the wrappers; the report keeps `ml_matches` until T9c takes `ml_matches_i`.
- `jl_membership_final` without `closed_after_load`; the staticdata tags 3 of the final tree's 6 (T11 adds the candidates and the split tables' miss); the gc roots and header lines in each part's share.
- `abstract_call_gf_by_type`: T10's declared result returns at once, with no split (T11), no `trusted` effect (T15), no closed build (T16), no `operation` keyword (T11).
- The options word keeps the facts series' names (`options`, `jl_get_module_options`); the final tree's `trait_options`, `jl_get_module_trait_options`, `:trait_option` are S3's rename, not made.

## 3. The seams to the parts above

| Where | T6 to T10 | The final tree adds | Added by |
|---|---|---|---|
| `abstract_call_gf_by_type` | the declared result, a `DeclaredResultInfo` | the split over the candidates, `operation` keyword; `trusted` effects; the closed build's splits | T11; T15; T16 |
| `jl_declare_membership`, `jl_delete_membership`, `jl_activate_memberships` | entry, method, list, strict mode, member states | `register_candidate`, `unregister_candidates` | T11 |
| staticdata's tags | `open_set_methods`, `jl_set_entries`, `jl_absence_sigs` | `jl_set_candidates`, `jl_split_table_miss_func` (`jl_func_set_methods` not made) | T11 |
| `jl_typename_t` | `contract`, `declared_fields`, `operations` | the bit `erases` and `jl_set_erases` | T14 |
| `jl_compilation_sig`, `jl_isa_compileable_sig` | unchanged | `is_trait_arg_type` (a set written with the method's variables) | T14 |
| `rtsite_target` (`facts.jl`) | unchanged | the trait-argument clause (E6) | T14 |
| `base/sysimg.jl`, `jl_invalidate_code_instances_new_world` | not made | Base's walk at the end of its build, guarded by "a set exists" | T12 |
| `post_boot_hooks` | unchanged | `Callable` opened, its inputs | T12 |
| `jl_method_set_declared_result` | `(m, rt)` | `base/iotrait.jl`'s calls with a third argument | T13 |
| the options word | `options`, `jl_get_module_options`, bits 1, 2, 16, 32, 64 | named `trait_options` (the library calls `jl_get_module_trait_options`) | S3's rename |
| `handle_declared_result!` (`inlining.jl`) | an operation's call | the split's fallback calls it | T11 |
| `effects.jl`, `optimize.jl` | `IR_FLAG_TYPES_PROVEN` (bit 20) | `IR_FLAG_TRUSTED_*` (bits 21, 22), `merge_override_effects!` | T15 |

## 4. What plain code pays, at T6 and at T10

No set declared; vanilla v1.13.2 the same hour; one thread.

**Micro-timings** (`motiv/h-micro.jl`; ns per call, minimum of 7 rounds, two rounds of processes each; `logs/i-micro-t6.log`, `logs/i-micro-t10.log`; T5 from the fourth part):

| | vanilla | T5 | T6 | T10 |
|---|---|---|---|---|
| `jl_subtype` | 238.9–240.0 | 268.1–268.4 | 264.7–265.2 (+11 %) | 269.9–270.4 (+13 %) |
| `jl_type_intersection` | 278.3–279.7 | 308.8–308.9 | 311.5–314.8 (+12 %) | 317.5–317.7 (+14 %) |
| the type cache | 76.9–78.1 | 79.0–79.2 | 80.2–80.6 (+4 %) | 80.0–81.2 (+3 %) |
| method matching | 177.6–179.9 | 186.5–186.8 | 184.0–185.7 (+3 %) | 193.3–200.2 (+8 to +11 %) |

- T6 adds nothing measurable to the walk (its gates sit in the compiler).
- **Method matching costs more at T10:** T7's drop (`drop_unmet_matches`: a call of `jl_unmet_final_cells` per match, which returns at the match's open-set bit) and the match's query world (`ml_matches_c` sets and restores it per match). A tension of the same kind as GT-9's: a session with no set pays a test per match. Proposal: one session bit, set by the first `jl_set_open_set`, read before the drop and the query world; with no set in the session neither runs. Not built.

**The session** (`motiv/f-plain.jl`; upstream CSV and DataFrames plainly; a warm-up and 3 fresh processes, interleaved; `logs/i-plain-t6.log` load 8.6–9.7, `logs/i-plain-t10.log` load 7.1–8.1):

| | `using CSV, DataFrames` | valid CodeInstances after the load | after the work | first work |
|---|---|---|---|---|
| vanilla (T6's hour) | 740–967 ms | 116,454 | 117,046 | 4.42–4.44 s |
| T6 | 699–1,184 ms | 117,981 | 118,573 | 4.38–4.49 s |
| vanilla (T10's hour) | 662–744 ms | 116,730 | 117,322 | 4.40–4.42 s |
| T10 | 659–683 ms | 118,337 | 118,929 | 4.40–4.41 s |

Digests equal. The first work is vanilla's at both; the CodeInstances' difference is the stack below (`w19-g-facts`); the load's times at T6's hour are noisy (both builds).

## 5. On T10's head

Build 4 (153fce6251; the branch's head differs from it in one line of `test/precompile.jl`, a stray line removed, run on the built binary).

- **Base's tests** (`Base.runtests([...]; ncores=1)`; `logs/i-tests-t10.log`): `subtype`, `core`, `worlds`, `reflection`, `Compiler/inference`, `Compiler/invalidation`, `Compiler/effects`, `facts` pass: 7,675,173 pass, 68 broken. `precompile` alone: 467 pass (`logs/i-tests-t10-precompile.log`), its new testset "memberships in package images" included.
- **The gates** (`run_all.sh` with the stub library; `logs/i-gates-t10.log`): `m1_*` 10 of 11, `m2_*` 19 of 19, `n*` 22 of 38, `f*` 6 of 7. Of the fourth part's waiting table, now passing: `m2_ambiguity_called_before`, `_declared_super`, `_predates` (T9c), `n11_late_shadow` (T10), `n12_image_instances`, `n3_image_memberships` (T8), `n24_hook_compile_queue` (T9b), `n29_membership_method` (T6, T7), `n31_isa_narrows` (T6), `f7_membership_edges` (T6). Still failing, each with its reason:

| Gate | Why | Needs |
|---|---|---|
| `m1_no_wrappers`, `n30_where_variable`, `n33_compiled_as_julia` | `Core.Dynamic` | T14 |
| `n8_callable`, `n13_attribute_free_vars`, `n14_callable_args` | `Core.Callable` | T12 (n13 also T14) |
| `n16_declared_result` | reads `Method.declared_covers`, not made (no reader); its copy `gates/i-n16_declared_result.jl` without that assertion passes | — |
| `n18_closed_after_load` | calls `jl_set_closed_after_load`, `jl_module_is_loaded`, not made (no reader); its copy `gates/i-n18_closed_after_load.jl` without them passes | — |
| `n20_unmet_lookup` | calls `jl_set_closed_after_load`; its part (5) needs `Callable`. The copy `gates/i-n20_unmet_lookup.jl` without both passes | T12 for (5) |
| `n19_io_trait` | `IO`'s contract | T13 (with T11) |
| `n22_declared_assert`, `n23_contract_image` | `jl_candidates_of` | T11 |
| `n26_callable_late_method`, `n35_trusted_result`, `n36_library_deep`, `n8_callable_box` | the library does not load (below) | T11 to T17 |
| `n34_closed_invoke_compiled` | the trimmed build's verifier | T16 |
| `f2_policy_flags` | `jl_get_module_trait_options` (S3's name) | S3's rename |

- **The nine loads** (`f-loads.sh`, unchanged; `logs/i-loads-t10.log`; a warm-up and 2 runs per cell, load 7.3–16.7): by facts 14 of 3,487 own image instances lost (G2 2,773), plainly 434 of 4,715; the work after the loads (A) 1.38–1.39 s by facts against 5.20–5.21 s; order B 2.43–2.45 s against 6.11–6.15 s. **The facts cells are T5's exactly** (14 of 3,487; G2 2,773). Plainly the packages' images hold 30 instances more than at T5 (4,715 against 4,685) and lose 10 more (434 against 424): not read; plain packages' images are rebuilt with each build, and the instances move with each set of images (third part, "Not done").
- **The library** (TraitWorld `unified` e2cb5d0, read only; `logs/i-traitworld-t10.log`): does not load. Its first stop: `const Dynamic = Core.Dynamic` (`src/dynamic.jl:5`). What it needs, by part, read from its source: `Core.Dynamic`, `Core.Compiled`, `jl_set_erases` and `jl_is_trait_arg_type` (T14); `Core.Callable` (T12); `jl_register_candidate`, `jl_candidates_of`, `jl_set_member_patterns`, `jl_open_set_methods_of` (T11, T16; `jl_open_set_methods_of` is the index's reader for compiling ahead); `jl_get_module_trait_options` (S3's rename); `Compiler.DefinitionCheckInterpreter` (T17); `Compiler.declared_field_type`, `Compiler.is_owner_only` are in the stack. The entry points of T6 to T10 it calls are all present: the hooks, `jl_set_strict_memberships`, `jl_take_activation_ambiguities`, `jl_membership_replay_sigs`, `jl_membership_method_sig`, `jl_activated_memberships(_count)`, `jl_activated_member_checks`, `jl_set_contract(_operations)`, `jl_set_declared_fields`, `jl_supertrait_instances`, `jl_set_open_operation`.

### The parts below T10, built

| Build | At | Base's tests | Gates (`m1`, `m2`, `n`, `f`) |
|---|---|---|---|
| 2 | T6 (fa1fec3410) | `subtype`, `core`, `worlds`: 7,671,909 pass, 1 failure, 50 broken (`logs/i-tests-t6.log`): the commit's `IR_FLAG_TYPES_PROVEN` test looked at optimized code, where the store it names is gone; the commit's test reads unoptimized code and passes at every later build | 10 of 11, 16 of 19, 17 of 38, 6 of 7 (`logs/i-gates-t6.log`, `logs/i-gates-t6-nf.log`, run as add1bb1db7 on the build) |
| 5 | T8 (3d38bca9af), T7 in it | `subtype`, `core`, `worlds`: 7,671,921 pass, 50 broken; `precompile` alone 467 pass (`logs/i-tests-t8.log`, `logs/i-tests-t8-precompile.log`) | 10 of 11, 16 of 19, 20 of 38, 6 of 7 (`logs/i-gates-t8.log`); the copies `i-n18`, `i-n20` pass (`logs/i-gates-copies-t8.log`) |
| 6 | T9c (a10552facc), T9a and T9b in it | `subtype`, `core`, `worlds`: 7,671,937 pass, 50 broken (`logs/i-tests-t9c.log`) | `m2` 19 of 19, `n` 21 of 38 (`logs/i-gates-t9c.log`) |

`wt/w19-julia` is left at T9c's build (build 6).

## 6. What stays for later: T11 to T17

| Part | What it needs from the stack as it is | Order of builds |
|---|---|---|
| T11 the split and the table | T10 (operations, `DeclaredResultInfo`, `handle_declared_result!`), `up/16`; the candidates in `jl_declare_membership`, `jl_delete_membership`, `jl_activate_memberships`; the tags `jl_set_candidates`, `jl_split_table_miss_func`; `base/splittable.jl`, `splittarget.jl`, `Compiler/src/splittable.jl` | 1 (T11 with T15): `n22`, `n23` |
| T15 the `trusted` effect | T10; F1's `Effects`; bits 21, 22 beside T6's bit 20 | with T11: `n35` (with the library) |
| T12 `Callable` | T2; T15; `post_boot_hooks`; `Function`'s entry in `base/Base.jl`; Base's walk at the end of its build (`base/sysimg.jl`, `jl_invalidate_code_instances_new_world`), guarded by "a set exists" since the bit `closed_after_load` is not made | 2 (T12, T13): `n8`, `n14`, `i-n20` with its part (5) |
| T13 `IO`'s contract | T10 (`jl_declare_contract`; `jl_method_set_declared_result` with two arguments), T11 | with T12: `n19`, `show`, REPL |
| T14 the kept forms | T9a (the expansion hook), `TypeName.erases`, `is_trait_arg_type` in `jl_compilation_sig`, E6 in `rtsite_target` | 3 (T14 with T17 and S3's rename): `m1_no_wrappers`, `n30`, `n33`; then TraitWorld's suite |
| T17 the definition-time check | none | with T14 |
| T16 a closed build | T11, T12, F4, F8, F11 | 4: `n34`, `w166/build_c.sh` |
| S3's rename | the options word | with T14, or the library calls `jl_get_module_options` |

Then the gates in full, Base's suites against vanilla, the library's suite and the nine loads at the head: about four builds.

## 7. Builds (fifth part)

`WIDE=0 tools-local/build.sh wt/w19-julia` (`-j4`, niced), one after another. Logs: `logs/i-build<n>-*.tw-build.log`.

| Build | Commit | Part | Start load (128 cores) | Wall | Peak RSS | Exit |
|---|---|---|---|---|---|---|
| 1 | 2758486a56 | T5 on the moved stack | 3.7 | 358 s | 5.0 GB | 0 |
| 2 | fa1fec3410 | T6 | 4.9 | 779 s | 5.5 GB | 0 |
| 3 | ae22648b7c | T10, first cut (without the world bound of final negatives) | 5.3 | 779 s | 4.9 GB | 0 |
| 4 | 153fce6251 | T10 | 28.5 | 739 s | 4.8 GB | 0 |
| 5 | 3d38bca9af | T8 | 8.0 | 789 s | 5.0 GB | 0 |
| 6 | a10552facc | T9c | 6.1 | 779 s | 5.0 GB | 0 |

Six of the twelve builds the brief allows.

## 8. Where the plan was wrong or incomplete (fifth part)

- **T6's absence edge belongs to T7:** before final negatives nothing folds a negative, so nothing makes the edge.
- **T7's "every set closed after load, a module's loaded mark"** reads as two mechanisms; in the final tree neither is read where it matters: every set has the bit, and no rule reads the mark. T7 is final negatives alone.
- **T7 needs a world bound the final tree lacks** (above): a final negative's code must not outlive, or predate, the pair's absence.
- **T8's "member checks kept"** is the member hook's state: it comes with T9 (T9b).
- **T9 is three patches** (hooks at definitions, the member hook, strict mode): 1,108 lines in all, too large for one review.
- **T10 drops two readerless pieces** (`declared_covers`, each function's list of methods at sets).
- **Plain method matching pays** at T7 (+8 to +11 % in the micro-timing): the plan's "one bit per question" does not hold for the drop and the query world either.
- **Sizes:** T6 to T10 are 3,039 lines added, 2,737 without their tests (the plan's estimate with TX: about 2,260).

## Not done, not verified (fifth part)

- **T9a, T9b and T9c are compiled, not built alone;** T6, T8 and T10 are built (T7 built in T8's build). Every commit of T6 to T10 compiles (`make -C src` in `wt/w19-check`, exit 0 at each).
- **The static check of GC roots** (`w163/sagc.sh`) was not run over T6 to T10's C: new globals (`jl_absence_sigs`, `jl_declared_memberships`, `jl_activated_entries`, `jl_activation_ambiguities`, the hooks, the member states) are rooted by both collectors.
- **The method-matching tension's proposal** (one session bit) is not built.
- **Comments and commit messages** are my wording and not reviewed. The test names in `test/subtype.jl` follow the fourth part's style.
- **The final tree's world-bound defect** is fixed in the series only; `next` is unchanged (not in this part's scope).
