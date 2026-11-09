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
