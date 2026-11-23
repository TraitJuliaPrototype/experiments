# Audit reports: patterns behind a failure

Tools that find every instance of a pattern a failure showed, so that the fix goes to the rule that
produces it (CLAUDE.md: "A failure names a pattern"). Each is a report: it asserts nothing. Current
numbers are in `writeup/design/evidence.md` and the open issues; the tables below are this
directory's own dated results.

## How to run

From the design repository's root, after `source env.sh`:

```sh
# the erasure report: dynamic calls in a module's methods typed by a set, or by a closed type with a contract
# as code compiled once at it below an erasing entry (default Base at IO), and the wrapper types whose
# parameter, bounded by the type, types a field
julia-unified/julia --startup-file=no experiments/implementation/audit/erased_calls.jl [Module] [Set] [n]

# the load report: what loading packages invalidates, grouped by cause, by the inserted method's shape,
# by the roots under the main causes, and the instances invalidated through a split's branch
cd TraitReport
../julia-unified/julia --startup-file=no --project=env_fu ../experiments/implementation/audit/load_invalidations.jl CSV,DataFrames,TraitMakie [n]
```

```sh
# the unmet-instance report: method instances compiled at a signature no type of the world is in
julia-unified/julia --startup-file=no experiments/implementation/audit/unmet_instances.jl [Pkg,…] [n]

# the declared-result report: the methods serving an operation of Core's sets (`IO`), whose members join
# by a nominal supertype and are not checked, with a result that infers outside the declaration
# (`all`: every operation; a proposed declaration: `write=Int,unsafe_write=Int`, `-` for none)
julia-unified/julia --startup-file=no experiments/implementation/audit/declared_results.jl [Pkg,…] [n] [f=T,…] [core|all]

# the result-by-inference probe (open issue 171): an operation's result at a value typed IO, the stream's type
# known, through IO and through Any; run as is and with --compile=min (logs/probe-result-by-inference-*.log)
julia-unified/julia --startup-file=no [--compile=min] experiments/implementation/audit/probe_result_by_inference.jl

# the unmet-Callable probe (open issue 172, compiler C-82): whether dispatch's lookup judges All{AbstractString, Callable}
# unmet while a string type with a call method is in it (logs/probe-unmet-callable-*.log)
julia-unified/julia --startup-file=no experiments/implementation/audit/probe_unmet_callable.jl

# the typemap report: methods a lookup tests one by one, in a level's linear list, by function; the
# longest single lists (a list at the root is walked by every lookup of every function)
julia-unified/julia --startup-file=no experiments/implementation/audit/typemap_linear.jl [Pkg,…] [n]

# the set-root report: how much of a load's invalidation starts at an instance compiled at a set
julia-unified/julia --startup-file=no --project=<env> experiments/implementation/audit/set_roots.jl Pkg,… [n]

# the chain report: for each invalidated instance matching a pattern, its chain from the root and the cause
julia-unified/julia --startup-file=no --project=<env> experiments/implementation/audit/invalidation_chains.jl '<regex>' Pkg,…

# the load profile: where loading packages spends its time, C frames included (flat and tree)
julia-unified/julia --startup-file=no --project=<env> experiments/implementation/audit/profile_load.jl Pkg,… <flat.log> <tree.log>
```

```sh
# the type-closure report: a module's closures compiled once per type they capture (E-322's pattern; E-344
# found it in the records' `_forget_records!`), from a compile trace taken with --trace-compile-timing
julia-unified/julia --startup-file=no experiments/implementation/audit/type_closures.jl <trace.log> [Module] [n]

# the uncompiled-instance report: the system image's instances with inferred code and no machine code that a
# session compiles because a package image's code calls them (E-351), from a compile trace taken with
# --trace-compile-timing; each traced signature that evaluates with no package loaded is looked up
julia-unified/julia --startup-file=no experiments/implementation/audit/image_uncompiled.jl <trace.log> [n]
```

```sh
# the index report: each (method, set) whose set the signature names in a shape the set-to-methods index does
# not hold; a membership's walk never replays such a method (compiler §5.5). From a demonstrator's directory:
../julia-unified/julia --startup-file=no --project=. ../experiments/implementation/audit/set_index.jl [Pkg,…] [n]
```

```sh
# the set-folds report (W-171, E-542): a differential test of every fold about a set across worlds; the section
# "The set-folds report" below. Each case runs in a worker process; a case whose compiled code stops the process is
# kept as a crash and the next worker goes on.
julia-next/julia --startup-file=no --project=experiments/implementation experiments/implementation/audit/set_folds.jl \
    [--only=<regex on shape/sequence>] [--questions=sub,isa,…] [--sample=<n> --seed=<s>] [--show=<n>] [--probes=<dir>]
# its library mode (E-543): the library's declarations and deletions, its kept forms, Callable, an operation
julia-next/julia --startup-file=no --project=TraitWorld experiments/implementation/audit/set_folds.jl --mode=traitworld
# its image mode (E-543): memberships and code in package images, built in a temporary depot
julia-next/julia --startup-file=no --project=experiments/implementation experiments/implementation/audit/set_folds_images.jl [--keep]
```

The compile trace of the imports (`trace-imports-*.log`) is Julia's own: `--trace-compile=<log> --trace-compile-timing -e 'using …'`.

The unmet-instance report counts instances with code valid in the latest world: an invalidated instance
stays as an object with its old code.

`probes.jl` holds earlier probes. Logs are in `logs/`, named by the build.

## Results

**2026-11-09, `unified` d554855579 (E-330), `IO` compiled once.**

| Report | Finding |
|---|---|
| erasure, Base at `IO` (`logs/erased-calls-base-io-d554855579.log`) | 931 methods typed `IO`; 139 split fallbacks; 1,933 calls through `Core.attributed_call`; 2,018 other dynamic sites on a value of `IO` in 164 functions (`write` 949, `print` 145, `show` 110, keyword calls 94, `IOContext` 89, `read` 75); receivers `IO` 1,886, `IOContext` 118. Wrappers over `IO`: `EachLine`, `IOContext`, `ReadEachIterator`, JuliaSyntax's `Lexer`. |
| load, the goal's packages (`logs/load-inval-fu-d554855579.log`) | 18,781 instances invalidated by 68 methods; TraitWorld's `length(::HasLength)` 11,994 under one pruned arm (`length(::LinearAlgebra.Factorization)`), reaching printing through the split's `TTY` branch of `get` |

The causes (open issues 166, 167): the lookup flagged calls at `IO` ambiguous at `All{AbstractString, IO}`,
an intersection no type is in (E-331); and an edge from a split's branch to its candidate's instance
carries that instance's invalidation to every caller of an instance compiled once.

**2026-11-09, later builds.**

| Build | Report | Finding |
|---|---|---|
| 43c222c751 (E-331) | erasure | 1,093 dynamic sites (2,018 before); 128 due to the stream |
| 43c222c751 | declared results, against `Int` for `write` and `unsafe_write` (`declared-results-stdlib-e331.log`) | Base: `Filesystem.File` and Core's streams return a `UInt`; REPL's `LimitIO` a forwarder |
| 0c836f3ef6 (E-332, E-333) | declared results (`declared-results-{stdlib,fu}-0c836f3ef6.log`) | none outside, Base, the standard libraries and the goal's packages; a stream in CSV's tests returns `n::UInt` (converted at the call) |
| 0c836f3ef6 | load (`load-inval-fu-0c836f3ef6.log`) | 17,035 instances invalidated; 22,791 under split edges, mostly `get` at `TTY`, an inlined branch |
| 7bd8b6e512 (only a leaf inlined) | load (`load-inval-fu-7bd8b6e512.log`) | 6,687 instances invalidated; 2,110 under split edges; `length(::HasLength)` 121 |
| 7bd8b6e512 | unmet instances (`unmet-instances-base-7bd8b6e512.log`) | 58 of the system image's 69,628 instances at `All{X, IO}`; the roots of the chains (35–42 deep) that recompile TraitWorld's load hooks at each load (open issue 169) |
| 1906196731 (E-334) | unmet instances (`unmet-instances-base-e334.log`) | 0 with valid code (28 objects, compiled while Base was built, their code invalidated once Base counts as loaded) |
| 1906196731 | load (`load-inval-fu-e334.log`) | 4,271 instances invalidated; 191 under a split's branch; TraitWorld's hooks still recompiled through plain chains (`trace-imports-fu-e334.log`: `_strict_at_load!` under `showerror`, `_atexit` under `length(::HasLength)` at `Factorization`) |
| 1906196731 | the profile of the goal's load (`profile-load-fu-e334-{flat,tree}.log`) | of 5.0 s, validation's `verify_call` 2.8 s, nearly all in the typemap visitor's linear list (`typemap.c:832`) |
| 45fa624462 (E-335) | typemap (`typemap-linear-base-e335.log`) | 1,663 in linear lists, 602 with an open set; no list at the root; the longest `show`'s, 222 |
| 45fa624462 | the profile of the goal's load (`profile-load-fu-e335-{flat,tree}.log`) | 2.4 s against 5.0 s; validation 0.70 s, image restore 0.76 s, activation 0.33 s |
| 45fa624462 | the read's profile and machine code (`profile-read-fu-e335-flat.log`, `codegen-read-fu-e335.log`, `trace-read-fu-e335.log`) | no inference; 1.4 s of LLVM: `show_unquoted(::IO, ::Expr, …)` 577 ms, `show_list` about 140 ms, CSV's internals; revalidated code, invalidated at load |
| 45fa624462 | set roots (`set-roots-fu-e335.log`) | 1,659 of 4,194 instances invalidated at insertions under a root at `IO`: `seekstart(::IO)` 584, `print(::IO, ::AbstractString)` 460, `setproperty!(::IO, …)` 304, `get(::IO, ::Symbol, ::Bool)` 88, `close(::IO)` 68, `ismarked(::IO)` 60 (E-336) |
| E-336 | set roots (`set-roots-fu-e336.log`) | 950 of 3,841 under a root at `IO`: `seekstart(::IO)` 584 → 0, `get(::IO, …)` 88 → 0, `ismarked(::IO)` 60 → 2; left `print(::IO, ::AbstractString)` 460 (new string types, as in plain Julia), `setproperty!(::IO, …)` 305 (TraitWorld's method for `Dynamic`), `close(::IO)` 75 |
| E-336 | the profile of the goal's load (`profile-load-fu-e336-{flat,tree}.log`) | 2.19 s; validation and backedges 0.85 s, of which storing backedges 0.20 s |
| 1906196731 | typemap (`typemap-linear-base-e334.log`) | of Base's 24,905 methods, 2,258 in linear lists, 1,199 with an open set; one list at the root holds those 1,199, so every lookup of every function walks them (E-335); per function `show` 239, `Core.kwcall` 165, `showerror` 47 |

The load report's `split_edge` over-matches (the Fable plan, §2.2): its rows "at `IO`" and "at `All{…}`" are not branches of a split.
| E-344 (`unified` e42047dba2, TraitWorld 6871ea9) | type closures (`type-closures-e344.log`, trace `trace-typeclosures-e344.log`: the goal's imports and one definition) | 1 instance of `_forget_records!`'s closure, 12.7 ms; a full sync of the goal's 122 activated memberships from the cursor at 0 compiled it per trait: 141 ms the first time, 2.6–3.2 ms after. Fixed by a loop in TraitWorld (E-344's addendum) |
| 352b916899 (E-351) | uncompiled instances, the goal's task (`trace-task-fu-e351.log`, `image-uncompiled-task-fu-e351.log`) | 28 instances compiled in the session, 310 ms; 8 are the system image's with inferred code and no machine code, 45.6 ms: `iterate(::Enumerate{Vector{Symbol}})` 13.6 + 5.1 ms and `length(::Vector{Pair{Symbol,Any}})` 3.4 ms under TraitWorld's records' walk, `issorted(::Vector{String}, ::ReverseOrdering)` 12.1 ms; the imports alone (`image-uncompiled-imports-fu-e345b.log`): 4 of 6, 34.4 of 73.5 ms |
| a2ea2aff32 (W-140, E-365) | the index (`set-index-tables-a2ea2aff32.log`, `set-index-tde-a2ea2aff32.log`) | TraitTables: 30 methods with a set in the signature, 32 (method, set) pairs, none missing. The ODE port: 214 methods, 247 pairs, none missing. The pattern: the index walked a signature's parameters, then a `Vararg`'s element, then a union's arms, each added after a stale call was found; a variable's bound (`f(c::C) where C <: X{T}`) was the fourth, found by gate `m2_parametric_replay` once no guard hid it |

## The set-folds report (W-171, E-542)

`set_folds.jl` is a differential test, not a report of a codebase: it builds its own cases. A case is a **shape** (two
types A and B with a set at one position, a value under A, and the expected answer of `A <: B` given whether the pair
holds) and a **sequence** of world changes. For each case it defines the question functions, compiles a copy of each
first in each world the sequence makes, and asks every copy in every world (in the latest world when it was made, and
afterwards by `Base.invoke_in_world`). Each answer is compared with the runtime's answer asked afresh in that world by
`ccall` (`jl_subtype`, `jl_isa`, `jl_type_intersection`, `jl_types_equal`, `jl_new_structv`; dispatch from the method
table's definitions valid in the task's world, which reads no dispatch cache), and the fresh answer with the shape's
expected one. Compiled code whose result is `Union{}` where the fresh answer returns is not run (it would run into
`unreachable`) and counts as `:would_trap`.

- **Questions (10):** `A <: B`, `typeintersect(A, B) === Union{}`, `A == B`, `hasmethod(h, Tuple{A})`; at the value:
  `x isa B`, `(x::B; true)`, `new` of a struct whose field is typed B (`Expr(:new)`, no conversion), `g(x)`'s selected
  method, `applicable(h, x)`, `which(g, Tuple{typeof(x)})` (in the latest world only: `which` asks it by definition).
- **Forms:** the function compiled for the types (`q`), through one more caller (`r`), and, where the shape has one, a
  method compiled once at a set (`@nospecializeinfer`, `o`) and its caller (`ro`).
- **Shapes (26 in the stub mode):** the type; a member defined after the methods at the set; a covariant parameter (a
  tuple, two); an invariant parameter; a union's component (one side, both); an intersection `All{X, Y}`; a variable's
  upper bound, lower bound (member in the lower bound against a set argument), both bounds; a lower bound compared for
  equality at the top and inside an invariant parameter; a lower bound whose answer rests on two entries (the gate
  `n38`'s shape); `Type{S}` against `Type{<:X}`; a type value (`Type{S}`'s entry); a `Vararg` tail; a family; a family
  bounded by a set; a set's input (the instance, a bound on it, another value); an abstract member; a set as member; a
  parameter through a declared supertype; an intersection no type is in (a member type defined later). Two more
  (`Dynamic{X}`, `Compiled{T}`) are for `--mode=traitworld`, which is not working yet (below).
- **Sequences (14 + 2):** declared; taken back; declared again; a path through a second set (the second link made, then
  each link taken back); a supertrait through one and two entries (and taken back); a method at B defined, defined
  where a more specific one exists, deleted; a method then the membership then its taking back; for the last shape a
  member type defined later and its membership taken back.
- The cross product is 348 cases and 96,880 checks, about 150 s on the head; a build without `jl_delete_membership`
  runs the 173 cases with no taking back. Deterministic: no sample unless `--sample`.

**The library mode** (`--mode=traitworld`, E-543): memberships declared by the library's `@implement` (also with a
block, a forwarding field and a family by `where`) and taken back by `TraitWorld.delete_membership`; the shapes but
`input*` and `unmet` (the library declares a set's inputs itself), and six more: the kept forms `Dynamic{Y0}` and
`Compiled{S}`, `block`, `forwarding`, `family_where`, `callable` (`@implement Callable S`, a callable struct, against
`Callable{Tuple{Int}, Int}`) and `operation` (a question `oval(x)`, an operation's declared result read at a value typed
by its set, with the `trusted` mark, also compiled once at the set). 386 cases.

**The image mode** (`set_folds_images.jl`, E-543): 13 of the shapes in four directions, each a child process on a
fresh depot: `loaded_after` (the functions compiled in the session, then a precompiled package's memberships
loaded), `image_code` (the functions compiled in a package's image by its workload, the memberships declared in the
session), `image_positive` (a package that declares the memberships and folds them in its image, the memberships
taken back in the session), `refused` (an image's membership refused at activation as a second instance of a set,
with code in that image that folded it). Two copies of each question, two worlds; 1,409 checks, 15 s.

**What it cannot ask:** a declared field read at a set; a method at the member's own type defined before the
membership, with a call compiled at the set (compiler C-166: no sequence puts a method at `A`); a store into storage
typed by a set (`setfield!`, `memoryrefset!`) and `typeassert` folded by
the optimizer's `⊑` queries (C-51); `Callable{A, S}`; an intersection of three components and two instances of one
set at different inputs; a set deeper than eight levels or under a `Vararg` in a method's signature (the walk's
conservative path, C-88); a redeclaration with another receiver; strict mode's refusals; another thread; a closed build.

| Date | Build | Cases | Mismatches (groups) | By question | Fresh against expected | Notes |
|---|---|---|---|---|---|---|
| 2026-11-23 | `w159-bisect` 3037289af6 (before rows 181, 182, 184, D-13) | 173 | 2,392 (419) | int 564, new 410, tassert 410, sub 264, hasm 220, isa 164, disp 144, app 122, which 64, eq 30 | 252 | row 181's hole: `lower_bound_eq`, `lower_bound_inv` `sub` in the form `q` kept after the membership |
| 2026-11-23 | `absence-worlds` 8884715703 (row 184, not 182) | 348 | 9,455 (1,134) | int 2,658, tassert 1,290, new 1,228, sub 1,154, hasm 830, isa 791, app 648, disp 522, which 190, eq 144 | 652 | row 182's hole: `lower_bound_rev` `sub`, `isa` in the form `q` run in an earlier world |
| 2026-11-23 | `w143e` d1e64d8b56 (rows 181, 182, not 184) | 348 | 9,725 (1,227) | int 2,658, sub 1,340, new 1,134, tassert 1,134, isa 1,121, hasm 830, app 650, disp 524, which 190, eq 144 | 652 | row 184's hole: 93 groups more than `next`, `sub` and `isa` run in a world before a taking back |
| 2026-11-23 | `next` dd42dc8c3f | 348 | 8,975 (1,134) | int 2,658, new 1,134, tassert 1,134, sub 1,018, hasm 830, isa 697, app 648, disp 522, which 190, eq 144 | 652 | none of the three; the patterns of E-542 |
| 2026-11-23 | `w171` 2ddbe12394 | 348 | 2,032 (246) | hasm 758, app 562, disp 522, which 190 | 652 | no type question left; dispatch: C-162, C-164, C-165; fresh against expected: C-163 |
| 2026-11-23 | `w171b` 86cc20d662 (C-165) | 348 | 1,998 (232) | hasm 758, app 546, disp 504, which 190 | 652 | `type_value` gone |
| 2026-11-23 | `w171b` aa362a2ddd (C-162) | 348 | 920 (130) | hasm 446, app 202, disp 202, which 70 | 652 | `lower_bound`, `lower_bound_rev`, `both_bounds` gone |
| 2026-11-23 | `w171b` 3c7394979a (C-164, C-163) | 348 | 0 (0) | — | 0 | nothing reported; 0 dynamic |
| 2026-11-23 | `w171b` 3e9c193025 (the head) | 348 | 0 (0) | — | 0 | as above |
| 2026-11-23 | `w171b` 054016ea75, library mode | 386 | 452 (47) | hasm, disp, app, sub, which at `callable`, `compiled`, `dynamic`; `forwarding` refused by the library (its field's type no member: the shape fixed after) | 0 | the Callable entry at every instance not replayed; the kept forms' non-membership folded as final; `hasmethod` at `Compiled{S}` |
| 2026-11-23 | `w171b` 3e9c193025, library mode | 386 | 112 (9) | hasm 112 | 0 | `hasmethod(h, Tuple{Compiled{S}})` only: compiler C-167 |
| 2026-11-23 | `w171b` 3c7394979a, image mode | 13 shapes, 4 directions | 1 of 1,409 | isa | — | `loaded_after`, `set_member`: an image's membership's method activated in the loading code's world |
| 2026-11-23 | `w171b` 054016ea75 and 3e9c193025, image mode | 13 shapes, 4 directions | 0 of 1,409 | — | — | the refused image's own code answers by the refusal |

Logs: `../w171/logs/set-folds-<build>.log`; the patterns, their probes and fixes: `../w171/README.md`.
