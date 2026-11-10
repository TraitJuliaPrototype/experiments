# W-134: the guarantee's controls on the unified build

The controls behind goal G-1 (`writeup/goals.md`), measured again on the unified build. Current numbers: `writeup/design/evidence.md` §1. Registry: E-355, E-356 and E-357 in `writeup/record/experiments.md`.

## E-355: what nine unrelated loads cost upstream CSV and DataFrames, and the forks

**The question.** After the same work (`CSV.read` into a `DataFrame`, `describe`, `sort`, `groupby`-`combine`), how many valid CodeInstances of the packages' own modules do nine unrelated loads end, and what does the work cost after them? The loads: OffsetArrays, StatsBase, Unitful, IntervalArithmetic, Distributions, Interpolations, StaticArrays, CairoMakie, REPL.

**Three configurations.**
- `env_up`: upstream CSV 1.3.0 and DataFrames 1.8.2, compiled plainly.
- `env_facts`: the migration path's first step. Upstream's seven packages (CSV, DataFrames, Tables, Parsers, InlineStrings, PooledArrays, SentinelArrays), each with one line added after `module X`, nothing else changed:
  `Base.Experimental.@compiler_options facts=true bounded=false no_pirates=false dynamic=false first_seen=true`
  (what TraitWorld's `@trait_module bounded = false no_pirates = false` expands to). `prep.jl` makes the copies in `pkgs-facts/` (not committed).
- `env_forks`: the port (forks-unified's CSV and DataFrames on TraitWorld-unified).

**Two orders.** A: the work, the loads, the work again. B: the loads, then the work.

### How to run

```
source ../../../env.sh
julia-unified/julia --project=../../../forks-unified/env_upstream prep.jl pkgs-facts   # the copies with the one line
JULIA_IMAGE_THREADS=4 julia-unified/julia --project=env_facts -e 'using Pkg; Pkg.precompile()'   # each environment once
bash run.sh e355 2          # counts and times: logs/e355.log
julia-unified/julia --project=env_forks after.jl <csv> <loads…>    # the work alone, timed, and what is compiled after the loads
julia-unified/julia --project=env_forks cause.jl <loads…>          # which load's method ends which instance
```

- `lost.jl <A|B> <csv> <loads…>`: E-41's control (`factscompiler/control/lost.jl`) for the unified build. Counts valid CodeInstances (`max_world == typemax(UInt)`, no owner) per root module, facts code (flag 0x20) and G2 (0x10), those of the image and those the work made, and those lost after the loads. Its work includes the display of the results, for a digest.
- `after.jl`: the work with no display, first and after the loads, with compile and recompile time, and the instances made after the loads by root module.
- `cause.jl`: **the tool for this pattern.** It reads the invalidation log of the loads and groups the entries by the method insertion that closes each group, naming the own instances each ends and the Base callees on the way. Run it on any environment to see through which Base methods facts code is lost.
- `scan_args.jl <modules…>`: finds optimized call statements with an expression nested as an argument (the pattern behind the build failure below).

### Results (2026-11-10)

Build: `unified` 36b653bb3b (fcdfd0da36 with the `rtsite_target` guard), TraitWorld-unified 048c44e, forks-unified ddc20f6. Product setting, strict mode off, one thread. Load 2–5 of 128 cores. A warm-up and 2 runs per configuration and order; the counts are identical in all three. Measures plain code compiled by facts (`env_facts`) and a port (`env_forks`) against plain code.

**Counts** (own modules of the eight packages; order A):

| | image code lost / of | code the work made, lost / of | facts code |
|---|---|---|---|
| upstream, plain | 433 / 4,706 (9.2 %) | 131 / 217 | 0 |
| upstream, the one line | 14 / 3,487 (0.4 %) | 4 / 77 | all; 3,435 satisfy G2 |
| the forks | 48 / 4,796 (1.0 %) | 0 / 8 | 3,454; 47 of the 48 lost |

The digest of the results is the same in all three configurations, and before and after the loads.

**The work alone** (`after.jl`, 2 runs):

| | first work | after the loads | instances compiled after the loads |
|---|---|---|---|
| upstream, plain | 3.03–3.06 s | 4.18–4.20 s | 900 |
| upstream, the one line | 0.67–0.70 s | 0.48–0.66 s | 43 (Base 31, CSV 6, Downloads 3) |
| the forks | 0.063 s | 0.96–0.98 s | 69 (Base 44, CSV 19) |

**With the display** (`lost.jl`: first / after the loads / loads first): plain 4.30–4.31 / 5.45–5.53 / 6.11–6.15 s; the one line 1.97–1.99 / 1.82–1.84 / 2.53–2.55 s; the forks 0.21 / 2.36–2.38 / 2.51–2.52 s.

**What ends the instances** (`cause.jl`, `logs/e355-cause.log`). Every own instance lost is reached through a plain callee in Base that a load's method invalidates:
- SparseArrays' `Base._cat`: `vcat(::Int, ::Vector{Int})`, and with it `CSV._parse`;
- FilePathsBase's `open` and `write`: `Downloads.download`, and with it `CSV.resolvesource` and the reader's entry chain (`CSV.File(::String)`, `CSV.read`);
- IntervalArithmetic's `promote_rule`, Unitful's `Colon`, FillArrays' `any` and `reduce_first`, OffsetArrays' `isempty`, StaticArrays' `getindex`, GeometryBasics' `convert`.

**Reading.**
- The guarantee holds in counts on the unified build: 0.4 % and 1.0 % lost, against 9.2 % plain.
- The first step gains without a port: 4.5× on first work, 6–9× after the loads.
- The port's weak point: the 48 instances lost are few, but they are the reader's entry chain, so the work after the loads costs 0.96–0.98 s against 0.063 s. Facts code keeps an edge to each plain Base callee (GT-8, `writeup/open-issues.md` §1).

### Found on the way

Building `env_facts`'s images aborted: "argextype called on Expr with head :call which is not valid for IR in argument-position". `rtsite_target` (the image build's search for the targets of run-time sites in facts code) asked the type of an expression nested in a call (`cglobal`'s tuple, inlined from `Parsers._bigintgmp`). Fixed at the rule: such an argument names no target (julia-unified 36b653bb3b; gate `n17_rtsite_targets`). `logs/e355-precompile.log`, `e355-build.log`.

### Logs

`logs/e355.log` (counts and times), `e355-after.log`, `e355-cause.log`, `e355-precompile*.log`, `e355-build.log`, `e355-gates.log` (the gates on the rebuilt tree).

## E-356: what the unified build, and the library loaded, cost plain code

**The question.** A session of plain code only (upstream CSV 1.3.0 and DataFrames 1.8.2, E-355's work): what does it cost on the unified build against vanilla Julia, and what does loading the library add?

**Configurations.** V: `julia-vanilla`, `env_up`. U: `julia-unified`, `env_up`. L: `julia-unified`, `env_lib` (`env_up` with TraitWorld-unified), the library loaded first. U-late: `env_lib`, the library loaded after the work.

### How to run

```
source ../../../env.sh
bash plain.sh e356 3                                             # load, first work, repeated work, the late load: logs/e356.log
julia-unified/julia --project=env_lib steady.jl <csv> none|first   # the repeated work by step
CAUSE_WORK=<csv> CAUSE_ROOTS=Base,DataFrames,Statistics julia-unified/julia --project=env_lib cause.jl TraitWorld
julia-unified/julia --project=env_lib probe_insert.jl            # which plain callers a method at an open set ends
```

- `plain.jl <csv> none|first|late`: times `using CSV, DataFrames`, the first work with its compile time, and 200 repetitions. `late` loads TraitWorld after the work, counts the valid instances ended by root module, and times the work after.
- `steady.jl`: the least and the median of 2,000 repetitions of each step.
- `cause.jl` with `CAUSE_WORK` (run the work before the loads) and `CAUSE_ROOTS` (the root modules reported): **the tool for the pattern below,** for any library and session.
- `probe_insert.jl`: callers of `length` compiled at a concrete type, a struct family, a plain abstract type, `Any` and Base's types, before the library loads.

### Results (2026-11-10)

Build: vanilla 45b6d15e34, `unified` 36b653bb3b, TraitWorld-unified 048c44e. Product setting, strict mode off, one thread. A warm-up and 3 runs, interleaved. Load 1.7–2.2 of 128 cores. Measures plain code only.

| | V | U | L |
|---|---|---|---|
| first work | 3.24 s | 3.02–3.04 s | 3.14 s |
| read, least of 2,000 | 104–111 µs | 104–115 µs | 113–114 µs |
| `describe` | 17.5–17.8 µs | 19.2–19.3 µs | 19.3–19.6 µs |
| `sort` | 6.8–7.0 µs | 7.8–8.2 µs | 7.9–8.0 µs |
| `groupby`-`combine` | 40.0–40.7 µs | 45.0–45.3 µs | 45.6–45.9 µs |

The load of the two packages scatters between 0.64 and 1.11 s in every configuration. `using TraitWorld`: 69–106 ms first, 50–75 ms late.

**The library loaded late** ends 197 of 123,269 valid plain instances (Base 85, DataFrames 77, Statistics 30, Main 3, PooledArrays 2), identical in 4 runs. The work after it: 0.25–0.26 s, nearly all compilation, against 0.19 ms repeated.

**What ends them** (`logs/e356-cause.log`): three of BaseTraits' methods at open sets on Base's functions.
- `length(::HasLength)`: 191 log entries, as `ncol(::AbstractDataFrame)` through `size` and `length(::DataFrameColumns)`.
- `iterate(::Iterable{T})`: 71, as `Base._check_valid_region(::Function)`.
- `haskey(::Keyed{K,V}, ::Any)`: 10, as `haskey(::SubIndex, ::Symbol)` and `hasproperty(::AbstractDataFrame, …)`.

**The pattern** (`logs/e356-probe.log`). A method at an open set meets every plain abstract type, since any subtype may be a member. A plain caller compiled at such a type, whose call was resolved to the few methods there, is ended when the method is added. Kept: callers at concrete types, at a struct family, at `Any`, and at Base's abstract types (their call was never resolved).

**Reading.**
- The first work is not slower on the unified build. DataFrames' repeated steps are 8–18 % slower: the build's cost to plain code (GT-9). The library adds nothing to them.
- The library belongs before plain work: loaded first it ends nothing and costs 3 % on the first work. Loaded late it ends plain code (GT-11, `writeup/open-issues.md` §1).

### Logs

`logs/e356.log`, `e356-steady.log`, `e356-cause.log`, `e356-probe.log`.

## E-357: the control for the demonstrators' images

**The question.** E-355's control for idiomatic trait code: do the nine unrelated loads end code of the demonstrators' images, and what does the work cost after them?

**Sessions** (`demo_session.jl`, environment `env_demo`).
- D: TraitDifferentialEquations and TraitMakie; two solves (Tsit5, Rodas5) and their plot.
- T: TraitCSV, TraitTables, TraitMakie; a read, a summary, a histogram. Tp: its plain twin, PlainTables and PlainPlots.
- Dp, D's plain twin (PlainODE, PlainPlots), does not load on the unified build: PlainODE defines `compiled_for` (open issue 160).

### How to run

```
source ../../../env.sh
julia-unified/julia --project=env_demo -e 'using Pkg; Pkg.precompile()'
bash run_demo.sh e357 2                 # KINDS="D T Tp", ORDERS="A B": logs/e357.log
CAUSE_DEMO=D CAUSE_CSV=<csv> CAUSE_ROOTS=TraitDifferentialEquations,ODECore,… julia-unified/julia --project=env_demo cause.jl <loads…>
```

`lost_demo.jl <kind> A|B <csv> <outdir> <loads…>` counts the valid instances of every root module the session brings, and after the loads lists what the work compiles (`SHOW_AFTER=n` prints the first n).

### Results (2026-11-10)

Build: `unified` 36b653bb3b, TraitWorld-unified 048c44e, TraitMakie c9e294b, TraitCSV 92c46d0, TraitTables 160639e, TraitReport a4bcf33. Product setting, strict mode off, one thread. A warm-up and 2 runs per session and order; the counts are identical in all. Load 1.9–2.6 of 128 cores. Measures idiomatic trait code against a plain twin.

| session | own instances lost / of the image | facts instances lost | work: first / repeated / after the loads |
|---|---|---|---|
| T | 0 of the trait packages (6 of Colors, a plain dependency) / 3,728 | 0 / 616 | 148–150 / 29 / 30 ms, nothing compiled |
| Tp | 28 (PlainPlots 15, PlainTables 13; Colors 6, PrecompileTools 2) / 3,266 | — | 150–152 / 29 / 476–483 ms |
| D, TDE f903e40 (the top module plain) | 13 of TraitDifferentialEquations (10 of the image, 3 the work made; ForwardDiff 14, CommonSubexpressions 6) / 4,791 | 0 / 929 | 1.81 s / 17 / 97–98 ms |
| D, TDE 6658c65 (the top module a trait module) | 0 of the trait packages (ForwardDiff 7, CommonSubexpressions 6) / 4,735 | 0 / 972 | 1.82 s / 17 / 77 ms |

- The loads first (order B): T's first work 128 ms, Tp's 363–370 ms; D's 0.94–0.96 s.
- D after the loads, with the top module a trait module, compiles two instances: the script's own plain functions (`work_d`, `comp`), 58 ms.

**What ended D's 13** (`logs/e357-cause.log`): the top module of TraitDifferentialEquations was compiled plainly. Its front end `solve` was lost through `_cbs`'s comprehension over `Union{Tuple, AbstractVector}` (SparseArrays' `IteratorSize` method), and `gradient` through ForwardDiff's plain code (Unitful's `Colon`). The pattern is the one of E-141. The fix at the rule: the top module is a trait module as the libraries under it are (TraitDifferentialEquations-unified 6658c65; its 34 testsets pass).

**Reading.**
- No facts instance of a demonstrator is lost. Idiomatic trait code holds the guarantee where a port to upstream's types loses its entry chain (E-355, GT-8).
- A module of a trait package that is compiled plainly is lost as plain code is. The guideline: every module of a trait package is a trait module, the front end included.
- What remains after the loads is the user's own plain script, and plain dependencies (ForwardDiff, Colors).

### Logs

`logs/e357.log` (TDE f903e40), `e357-front.log` (D with TDE 6658c65), `e357-cause.log`, `e357-precompile.log`.
