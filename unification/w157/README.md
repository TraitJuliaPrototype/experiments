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
