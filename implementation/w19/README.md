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
