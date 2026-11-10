# W-134: the guarantee's controls on the unified build

The controls behind goal G-1 (`writeup/goals.md`), measured again on the unified build. Current numbers: `writeup/design/evidence.md` §1. Registry: E-355 in `writeup/record/experiments.md`.

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
