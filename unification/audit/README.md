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
julia-unified/julia --startup-file=no experiments/unification/audit/erased_calls.jl [Module] [Set] [n]

# the load report: what loading packages invalidates, grouped by cause, by the inserted method's shape,
# by the roots under the main causes, and the instances invalidated through a split's branch
cd TraitReport-unified
../julia-unified/julia --startup-file=no --project=env_fu ../experiments/unification/audit/load_invalidations.jl CSV,DataFrames,TraitMakie [n]
```

```sh
# the unmet-instance report: method instances compiled at a signature no type of the world is in
julia-unified/julia --startup-file=no experiments/unification/audit/unmet_instances.jl [Pkg,…] [n]

# the declared-result report: the methods serving an operation of Core's sets (`IO`), whose members join
# by a nominal supertype and are not checked, with a result that infers outside the declaration
# (`all`: every operation; a proposed declaration: `write=Int,unsafe_write=Int`, `-` for none)
julia-unified/julia --startup-file=no experiments/unification/audit/declared_results.jl [Pkg,…] [n] [f=T,…] [core|all]

# the result-by-inference probe (open issue 171): an operation's result at a value typed IO, the stream's type
# known, through IO and through Any; run as is and with --compile=min (logs/probe-result-by-inference-*.log)
julia-unified/julia --startup-file=no [--compile=min] experiments/unification/audit/probe_result_by_inference.jl

# the unmet-Callable probe (open issue 172, compiler C-82): whether dispatch's lookup judges All{AbstractString, Callable}
# unmet while a string type with a call method is in it (logs/probe-unmet-callable-*.log)
julia-unified/julia --startup-file=no experiments/unification/audit/probe_unmet_callable.jl

# the typemap report: methods a lookup tests one by one, in a level's linear list, by function; the
# longest single lists (a list at the root is walked by every lookup of every function)
julia-unified/julia --startup-file=no experiments/unification/audit/typemap_linear.jl [Pkg,…] [n]

# the set-root report: how much of a load's invalidation starts at an instance compiled at a set
julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/set_roots.jl Pkg,… [n]

# the chain report: for each invalidated instance matching a pattern, its chain from the root and the cause
julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/invalidation_chains.jl '<regex>' Pkg,…

# the load profile: where loading packages spends its time, C frames included (flat and tree)
julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/profile_load.jl Pkg,… <flat.log> <tree.log>
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
