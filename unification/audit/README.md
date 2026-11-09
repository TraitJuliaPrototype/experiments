# Audit reports: patterns behind a failure

Tools that find every instance of a pattern a failure showed, so that the fix goes to the rule that
produces it (CLAUDE.md: "A failure names a pattern"). Each is a report: it asserts nothing. Current
numbers are in `writeup/design/evidence.md` and the open issues; the tables below are this
directory's own dated results.

## How to run

From the design repository's root, after `source env.sh`:

```sh
# the erasure report: dynamic calls in a module's methods typed by a set (default Base at IO), and the
# wrapper types whose parameter, bounded by the set, types a field
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
```

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

The load report's `split_edge` over-matches (the Fable plan, §2.2): its rows "at `IO`" and "at `All{…}`" are not branches of a split.
