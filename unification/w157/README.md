# W-157: stage 5, Base's surface by the census (D-8; open issues 179, 194, 195)

The plan's D-8 (`writeup/plans/2026-11-15-next-iteration.md` §3, stage 5): each place below a port's code compiled by facts that keeps that code out of the deep class is a patch to Base that stands without traits, a boundary, or a fix to how an edge is recorded. Built in `julia-s3` (branch `next-s3`, from 213c759370) with the library in `TraitWorld-s3`. Registry: E-476 to E-480 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md` §4c, "Base's surface on `next-s3`". The agent's session note: `session-notes/2026-11-15-agent-w157.md`.

## How to run

```
source env.sh        # the workspace's env.sh, a depot of this agent's own in front of the shared one, $JS, $CSVFILE, $LOADS
bash precompile.sh <label>                                   # the environments' images, after each rebuild of Base
CENSUS_TSV=logs/<label>-forks.tsv $JS --project=env_forks census.jl $CSVFILE [$LOADS]   # the census (E-476), the forks
CENSUS_TSV=logs/<label>-facts.tsv $JS --project=env_facts census.jl $CSVFILE [$LOADS]   # upstream compiled by facts
$JS --project=env_forks diag/culprit.jl $CSVFILE Base.Val Core.DomainError ...          # culprits up close: faults, callers
```

- **Environments.** Copies of W-155b's (`../w155b/`), so that no run loads a tree another agent changes: `env_forks` (the forks, the library at `TraitWorld-s3`), `env_facts` (upstream CSV and DataFrames compiled by facts, W-134's copies in `../w134/pkgs-facts/`), `env_session` (the forks' digests), `env_lib` (the library).
- **The depot.** `.julia-depot/agent-depots/w157` in front of the shared depot: each rebuild of Base makes the environments' images again there (`precompile.sh`, about ten minutes).

## The census (`census.jl`, `census_lib.jl`)

The deep class is the G2 bit ([compiler §3.2](../../../writeup/reference/compiler.md#32-g2-as-a-predicate)). The tool reads E-392's session (the CSV work twice) and every instance reached below the own code, by CodeInstance edges and by an edge that names an instance (to that instance's code now).

- **A culprit** is an instance without the bit that a fault of its own keeps out: the build's predicate replayed edge by edge. The faults: a dispatch edge at a signature that is no fact, a call that found no method at such a signature, a callee named by its MethodInstance alone. An instance whose only fault is a callee without the bit is no culprit: the walk goes on below it.
- **The cone** of an own facts instance outside the class: the culprits reached from it through instances outside the class. The instance enters the class when every culprit of its cone is fixed.
- **What a fix buys:** "alone", the own facts instances whose cone holds that culprit only (or only culprits of the group); the greedy order of method names and of kinds, each with what it buys on top of the ones before.
- **The kinds** (the first that applies): `by_instance` (a callee named by its MethodInstance alone), `error_path` (the instance only throws, or builds an exception, or calls an exception's constructor), `type_join` (`typejoin`, `typesplit`, `promote_typejoin` and kin), `task_lock` (the task code under a lock), `ctor_kind` (a constructor called with a value of a kind), `any_container` (an argument or a call at a container of `Any`), `introspection` (any other call with a value of a kind), `other`.
- **The rule's view:** the faults by the function called, for the rule behind a pattern (a call of `!==` at `(Any, Any)`, a property read at a kind, a constructor at a type value).
- **What-if:** the own facts instances that would be in the class if Base's and Core's functions without a package's method were owner-only by declaration ([facts §3](../../../writeup/reference/facts.md#3-fact-signatures)): (a) the internal ones, (b) all.
- **The copies P3's demand rule would make:** the instances below the own facts instances, outside the own modules, without the bit.
- With the nine loads after it: the own instances ended, and of them with the bit (the gate).

`diag/culprit.jl` shows chosen culprits: their faults, a path of callers up to an own facts instance, an instance's code for a callee named by instance. `diag/edges_of.jl` prints the edges of chosen instances.

## Results

### E-476 (2026-11-15): the census on stage 5's baseline

`next-s3` 213c759370 (the binary names `1dc4c7b3ae*`), TraitWorld-s3 9e0e3f4, forks 439bae7; product setting, strict mode off, one thread, one process per row; load 1.6 to 5 of 128. `logs/e476-forks-b.log`, `logs/e476-facts-b.log` (the census), `logs/e476-forks.log`, `logs/e476-facts.log` (with the nine loads), `logs/e476-culprits-*.log`, the tables `logs/e476-*.tsv`.

| | the forks | upstream by facts |
|---|---|---|
| own image instances with the bit | 2,213 of 5,566 (39.8 %) | 1,373 of 3,464 (39.6 %) |
| own facts instances (the image's and the work's) with the bit | 1,756 of 4,204 (41.8 %) | 1,402 of 3,541 (39.6 %) |
| culprits (a fault of their own); in how many method names | 1,730 | 978 |
| culprits in one own facts instance's cone: median, most | 16, 449 | 6, 210 |
| the nine loads end, of the own image instances; with the bit | 156; 0 | 14 (and 5 the work made); 0 |
| the nine loads end, below the own code; with the bit | 305 of 37,177; 0 | 109 of 27,390; 0 |

**By kind** (culprit instances; own facts instances whose cone holds one; whose cone lies in the kind):

| kind | the forks | upstream by facts |
|---|---|---|
| error path | 155; 2,365; 567 | 72; 2,068; 992 |
| type join | 78; 1,075; 18 | 41; 473; 17 |
| introspection (a call with a value of a kind) | 292; 920; 5 | 165; 510; 0 |
| the task code under a lock | 15; 1,029; 0 | 15; 481; 0 |
| a container of `Any` | 130; 1,115; 0 | 116; 482; 0 |
| a constructor at a kind | 16; 681; 0 | 8; 377; 0 |
| a callee by instance alone | 41; 483; 1 | 19; 258; 9 |
| other | 1,003; 1,392; 52 | 542; 930; 45 |

**The greedy order of method names** (own facts instances in the class, the forks): start 41.8 %; `Core.throw_inexacterror` 49.9 %; `DomainError` 53.4 %; `Base.typesplit` 56.0 %; `Base.string_index_err` 57.9 %; `Base.Val` 61.3 %; `Base.hasmethod` (by instance) 62.6 %; `Base.IOContext` 63.7 %; then many names at a few instances each, 67.4 % after 25. Upstream by facts: 39.6 %; `throw_inexacterror` 60.6 %; `DomainError` 64.0 %; `string_index_err` 67.6 %; `Val` 72.8 %; `IOContext` 74.8 %; `typesplit` 76.1 %; 80.9 % after 25.

**By the function called** (the rule behind a pattern; the forks, cones): the constructor `InexactError` at a type value (2,352); `convert(::Type{AbstractString}, ::Any)` in `DomainError` and `AssertionError` (1,712); `Val{x}()` (1,198); `!==` (1,116; the compiler's inference of `!==` records its edge at `(Any, Any)`, whatever the call's types); `getproperty` at a kind (1,089); `typesplit` (1,050); `Core.kwcall` at an abstract argument (1,049); `setproperty!` with an `Any` value (1,032); `__safe_setindex!` and `push!` at a `Vector{Any}` (946, 920); `UnionAll` and `TypeVar` (887, 852; the compiler's inference records their edges at `Any` too).

**What-if, Base's functions owner-only by declaration** (no package method of them in the session): 431 (internal) and 513 (all) of the forks' culprits resolved, 0.0 points alone; upstream 260 and 280, 0.1 point. Alone it buys nothing: the cones hold the kinds above as well.

**Reading.**
- The share is about two fifths in both configurations. A few error paths carry the largest reach: three of them give the forks 16 points and upstream 28.
- The cones are wide: a median of 16 culprits under one of the forks' instances. After the first few names, each further name buys a few instances only, and the task code, the containers of `Any` and the constructors at kinds count only together.
- Two of the patterns are in how the compiler records an edge, not in Base: `!==`'s edge at `(Any, Any)`, and `Val(::Int)` folded by concrete evaluation, whose edge names the generic instance (`Val{x}()` at an unknown `x`).
- The baseline's own image instances (5,566) are more than on `next` 9b6dacf5c5 with TraitWorld-w155 (4,773, E-417), and the nine loads end more of them (156 against 49). The library and the third wave's commits both differ between the two; this run does not separate them. None of the ended carries the bit.

### E-477, E-478 (2026-11-15): the first batch

`next-s3` 396cd65a48 (the binary names `396cd65a48*`): five commits on 213c759370, below; TraitWorld-s3 9e0e3f4, forks 439bae7; product setting, strict mode off, one thread, one process per row; load 5 to 8 of 128. `logs/b1-*`; `logs/build-b1.log`.

| commit | what | kind |
|---|---|---|
| 0a07a715ca | an edge names the callee's CodeInstance where one exists when the caller finishes (open issue 195 (a)) | compiler |
| 6b3175dc9c | the edge of a call of `!==` keeps the call's own signature | compiler |
| 297d19aca1 | error paths build their exception at a concrete signature (`throw_inexacterror`, `DomainError`, `string_index_err`, `TypeError`) | general |
| ab96564f36 | the type joins read type fields with `getfield` and call each other through `invoke` | general |
| 396cd65a48 | `yieldto` sets the task's result with `setfield!` | general |

| | the baseline 213c759370 | the first batch |
|---|---|---|
| the forks: own facts instances with the bit | 1,756 of 4,204 (41.8 %) | 2,460 of 4,204 (58.5 %) |
| the forks: own image instances with the bit | 2,213 of 5,566 (39.8 %) | 3,517 of 5,568 (63.2 %) |
| upstream by facts: own facts instances with the bit | 1,402 of 3,541 (39.6 %) | 2,503 of 3,542 (70.7 %) |
| upstream by facts: own image instances with the bit | 1,373 of 3,464 (39.6 %) | 2,460 of 3,465 (71.0 %) |
| below the own facts instances, outside the class (the copies P3's demand rule would make): the forks; upstream | (not counted) | 3,124 of 34,532; 2,345 of 27,390 |
| the nine loads end: the forks' own image instances; with the bit | 156; 0 | 156; 0 |
| the nine loads end: upstream's; with the bit | 14 (and 5); 0 | 14 (and 5); 0 |
| below the own code ended; with the bit: the forks; upstream | 305, 0; 109, 0 | 305, 0; 109, 0 |
| methods in the session (the forks, the library, the nine loads) the patches would not reach (`diag/intercept.jl`) | — | 0 |

**Per commit, the culprits it removes** (`diag/compare.py logs/e476-forks.tsv logs/b1-forks.tsv`; instances, and the own facts instances whose cone held one; the forks):
- 195 (a): callees by instance alone 41 to 33 culprit instances; `hasmethod` 19 to 11 (upstream: 19 to 16 by instance). The rest name a callee that had no code when the caller finished.
- `!==`: `istaskdone`, `trypoptask` (1,029 cones each) and the other culprits whose only fault was `!==`.
- The error paths: `throw_inexacterror` (10 instances, 2,352 cones), `DomainError` (1,712), `string_index_err` (817), `TypeError` (3, 39). On the baseline these four alone buy 16.1 points for the forks, 28.0 for upstream (E-476's greedy order).
- The type joins: `typesplit` (1,050), `tailjoin`, `full_va_len`, `supertype` (796 each), `promote_typejoin`, `_promote_typesubtract` (768); `rewrap_unionall` 14 to 7 (the rest are callers at a kind). `typejoin` itself stays: its stores into a `Vector{Any}` go through `setindex!` and `_setindex!` at `Any`, the container-of-`Any` pattern. `typejoin_union_tuple` and `promote_typejoin_union` are not changed.
- `yieldto` (1,029 cones).

**What is left** (the forks; the greedy order on this build): `Val` 62.0 %, `IOContext` 63.1 %, then names worth a few instances each (68.9 % after 25). By kind, together: other 64.7 %, type joins 68.1 %, introspection 69.7 %, constructors at kinds 71.2 %, the task code 72.4 %, containers of `Any` 85.2 %, error paths 89.3 %, by instance 100 %. Upstream: `Val` 76.7 %, `IOContext` 78.9 %, 80.7 % after 11 names.

### E-478 (2026-11-15): the second batch, and the head

`next-s3` bc844be7c0 (the binary names `bc844be7c0*`): two commits on the first batch; TraitWorld-s3 9e0e3f4, forks 439bae7; product setting, strict mode off, one thread, one process per row; load 4 to 9 of 128. `logs/b2-*`; `logs/build-b2.log`.

| commit | what | kind |
|---|---|---|
| 024755ee89 | `Val(x)` builds its singleton with `new{x}()` (an inner constructor) | general |
| bc844be7c0 | `IOContext(io, key => value)` stores the property through `ImmutableDict`'s own constructor by `invoke` | general |

| | the baseline | the first batch | the head |
|---|---|---|---|
| the forks: own facts instances with the bit | 41.8 % (1,756 of 4,204) | 58.5 % | 63.1 % (2,654 of 4,204) |
| the forks: own image instances with the bit | 39.8 % | 63.2 % | 68.9 % (3,852 of 5,593) |
| upstream by facts: own facts instances | 39.6 % (1,402 of 3,541) | 70.7 % | 79.0 % (2,818 of 3,567) |
| upstream by facts: own image instances | 39.6 % | 71.0 % | 79.5 % (2,774 of 3,490) |
| the copies P3's demand rule would make: the forks; upstream | 6,791; 5,439 (`logs/c-base-census-*.log`) | 3,124; 2,345 | 2,413; 1,782 |
| culprits in a cone, median (the forks; upstream) | 16; 6 | 11; 8 | 12; 19 |
| the nine loads end, own image instances with the bit | 0 | 0 | 0 |
| the nine loads end, below the own code, with the bit (the forks; upstream) | 0; 0 | 0; 0 | 30; 12 (below) |

- **The 30 and 12 instances with the bit that the loads end below the own code** (`diag/ended_deep.jl`, `logs/b2-ended-deep*.log`) are one case: `vcat(::Int64, ::Vector{Int64})`, its keyword call of `cat` and `cat`'s body (the constant-propagated edges of the forks' facts code, one per context). They are in the class since `Val(1)` is: before, they rested on the generic `Val(::Int64)`. SparseArrays, which two of the loads bring, defines Base's `_cat` and `vcat` at `Union{Number, AbstractVecOrMat{<:Number}}`, Base's own types. A standard library counts as Julia's own code, so its method is a stakeholder's change: one of G2's named exceptions (facts §2.2; open issue 19). G2 holds; the code this exception reaches is now in the class (E-392's case of SparseArrays' `vcat`).
- **The culprits it removes:** `Val` (5 instances, 1,198 cones), `IOContext` (4, 657; `ImmutableDict` constructor faults gone).
- **The suites** (`logs/b2-summary.log`): `w155/gate_deep.jl`; Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference`; `errorshow`, `int`, `numbers`, `strings/basic`, `channels`, `ambiguous`; the library's suite; the forks' digests equal upstream's at 26 steps. All pass, as on the first batch. `diag/intercept.jl`: 0 methods in the session the patches would not reach.
- **What is left** (the forks; the greedy order on the head): no name buys a point alone (`Iterators.iterate` +0.9, `hasmethod` by instance +0.8, then less; 68.9 % after 25 names). By kind together: other 66.1 %, type joins 69.5 %, introspection 71.1 %, … The kinds that count only together are the task code under a lock (a payload typed `Any` passed to `schedule`, `notify`, `push!` of a `CompositeException`), stores into containers of `Any` (`push!` and `setindex!` at `Any`, then `_setindex!`), keyword calls at an abstract argument, property reads and constructors at an abstract type or a computed type (`Vector{T}(undef, n)`, the generic paths of `collect` and `map`). Upstream: 81.2 % after 13 names; by kind together, other 80.6 %, type joins 84.0 %, the task code 84.7 %, containers of `Any` 87.7 %.
- **Ownership by declaration** (the what-if, on the head): Base's functions no package extends, owner-only, would resolve 423 (internal) or 500 (all) of the forks' culprits: 63.2 % and 64.1 % (0.1 and 1.0 point); upstream 79.1 % and 79.3 %.

### E-478's control, E-479, E-480 (2026-11-15): the controls on the head

`controls.sh c`: the head (`next-s3` bc844be7c0) against stage 5's baseline image (213c759370's system image, kept before the first rebuild, run with `-J` on the same runtime; the runtime did not change in stage 5). With that image the census reproduces E-476's counts exactly (`logs/c-base-census-*.log`). One after another, alternating; load 3 to 28 of 128 (another agent's jobs), stated per run in the logs. `logs/c-*`.

**The work after the nine loads** (W-134's `lost.jl`, order A; a warm-up and 1 run, twice each; `logs/c-{base,head}-{1,2}-runs.log`):

| | first work | after the loads |
|---|---|---|
| upstream by facts, the baseline | 1.772–1.789 s | 1.458–1.476 s |
| upstream by facts, the head | 1.748–1.769 s | 1.451–1.464 s |
| the forks, the baseline | 150–154 ms | 2.331–2.343 s |
| the forks, the head | 147–156 ms | 2.307–2.342 s |

The same, within the runs' spread. The forks still lose 156 own image instances (CSV 143) to the loads and take 2.3 s after them: their entry chain's cones still hold open issue 218's culprits. The share moved; this time did not.

**What plain Julia pays** (E-479):
- Plain code's first work (W-134's `plain.jl`, upstream CSV and DataFrames compiled plainly; `logs/c-plain.log`, `c-plain-b.log`): the head 3.42–3.54 s at load 6 to 8 and 3.355–3.359 s at load 4; the baseline 3.37–3.42 s and 3.351–3.370 s. The same; `using CSV, DataFrames` 0.75–0.77 s both.
- The system image: 211,712,744 bytes on the baseline, 212,052,920 on the head (+0.16 %; after the first batch 211,666,176). The build's stages (`logs/build-*.log`): Base 32.6 s, 32.9 s, 32.3 s; the standard libraries 12.7, 12.8, 12.6 s; the compiler 346 and 349 s on the two batches (the baseline's build did not rebuild it).
- Base's `precompile` test: 223 s on the head (load 2.5 to 4.4). Under `-J` the baseline image took 311 s, not comparable: the standard libraries' caches in the tree are the head image's, so that run compiles them again. E-419 measured 224 s on `next` with the code slot removed.

**P6's count** (E-480; `w152/p6/split.jl`, the forks' CSV and DataFrames after the nine loads; `logs/c-split-forks.log`): 7,484 instances from images; deep G2 5,110 (68.3 %), with 49.9 % of the edges and 129 of 701 calls by signature (18.4 %); no instance has the bit without being deep. E-399 on `unified`: 50.3 %, 21.6 %, 12.8 %. Deep code holds most of the instances, not a quarter of the lookups: by E-399's criterion P6 stays ended. The lookups sit in the instances without the bit (572 of 701).
