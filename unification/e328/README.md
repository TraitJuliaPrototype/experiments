# E-328: what erasing the stream costs code that writes to it a little at a time

Open issue 164, proposal (d): `IO` a trait in Base, compiled once by default. A method compiled once calls the
stream's operations through run-time sites, or through the split over the trait's first members (compiler §7).
This proxy measures that cost in plain Julia, with no change to Base. The question and its threshold are E-328's
row in `writeup/record/experiments.md`; the current numbers are in `writeup/design/evidence.md` §2.

## The ways

The same workloads write into an `IOBuffer`:

| Way | The stream | Models |
|---|---|---|
| `raw` | the `IOBuffer` itself | reference |
| `known` | `IOContext{IOBuffer}` | code compiled for the stream's type |
| `erased` | `IOContext{IO}` | a dynamic call per operation, its result untyped (option (a)'s eraser) |
| `dyn` | `DynIO`, erased, each operation's result asserted (`unsafe_write`, `write(io, ::UInt8)` `::Int`) | the design's run-time site |
| `split` | `SplitIO`: as `dyn`, the operations branching over `IOBuffer`, `IOStream`, `TTY`, `PipeEndpoint` with direct calls, a dynamic call past them | the design's split over four candidates |

Base keeps an `IOContext{IO}` erased when code wraps it again (`IOContext(io::IOContext, dict)` keeps `typeof(io)`).

## How to run

```sh
source env.sh            # from the design repository's root
experiments/unification/e328/run.sh
```

Vanilla v1.13.2 (`julia-vanilla`) with `forks-unified/env_upstream` (upstream CSV and DataFrames), then the
unified build with Base's workloads only. `RUNS` (default 7) sets the runs after the warm-up; the ways and
workloads run interleaved. A few minutes. Logs: `logs/e328-vanilla.log`, `logs/e328-unified.log`.

## Results (2026-11-09)

Vanilla 45b6d15e34 and `unified` 6767b03893; minimum of 7 runs after a warm-up, interleaved; load 17–18 of 128
during the run. Each way against `known`, by the minimum; the ranges span the two builds.

| Workload | `erased` | `dyn` | `split` | `known`, ms |
|---|---|---|---|---|
| `print` 10⁵ `Int`s | 1.94–1.96 | 1.76–1.77 | 1.14–1.19 | 5.1–5.3 |
| `print` 10⁵ `Float64`s | 1.30–1.47 | 1.02–1.10 | 0.85–0.89 | 13.0–14.2 |
| `print` 10⁵ times `"ab"` | 4.64–5.03 | 3.72–4.11 | 1.61–1.68 | 0.63–0.65 |
| `write` 10⁶ `Char`s | 4.40–5.00 | 3.11–3.14 | 1.01–1.14 | 7.3–7.5 |
| `write` 10⁶ bytes | 4.50–5.30 | 5.96–6.20 | 2.01–2.20 | 3.8 |
| `join` of 10⁴ strings | 4.17–4.24 | 3.32–3.70 | 1.58–1.59 | 0.15 |
| `@printf` 10⁴ lines | 1.11–1.13 | 1.08–1.09 | 1.03 | 2.3–2.6 |
| `show` of a 10⁴-element `Vector{Float64}` | 1.07–1.14 | 1.06–1.11 | 0.98–1.06 | 23.8–25.0 |
| 10⁵ strings built as `string(…)` | 1.45–1.57 | 1.21–1.28 | 0.96–0.99 | 33.3–33.7 |
| upstream CSV's `write`, 10⁴ rows (vanilla) | 0.96 | 0.93 | 0.92 | 0.35 |
| DataFrames' display, the session's table (vanilla) | 0.99 | 0.98 | 0.99 | 1.50 |
| DataFrames' display, a 10⁴-row frame (vanilla) | 1.01 | 0.98 | 0.98 | 0.18 |

- **Through the split**, formatted output and strings built cost 0.85–1.19× the stream's known type. A display
  and CSV's `write` are bound by their own work (0.92–0.99×).
- **One byte or one short string per call** costs about 4 ns more per call through the split (1.6–2.2× on a loop
  that does nothing else); erased without it, 4.2–5.3×.
- **The split's numbers need `IOBuffer` among the candidates**: a stream past them (the REPL's
  `IOContext{REPL.LimitIO{TTYTerminal}}`, a wrapper) takes the fallback, as `dyn` does here.
- `known` is slower than `raw` for `Float64`s and bytes: `IOContext`'s own forwarding.
