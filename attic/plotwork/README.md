# A plotting session with upstream packages only: what `all` saves, what it costs (E-140)

The user (2026-10-20): "take a typical plotting workload, run with all upstream packages. No trait code anywhere. You start by reading in some data, then you generate a few plots then you manipulate the plots. Facts-all mode would save on recompilations, but lose on abstract containers. But how much work would you have to do until the price you pay when generating and editing plots outweighs what you win on avoided recompilations?"

## The workload (`plotwork.jl`)

- **Packages:** CSV, DataFrames, Statistics, CairoMakie, and seven analysis packages (OffsetArrays, StatsBase, Unitful, IntervalArithmetic, Distributions, Interpolations, StaticArrays). All upstream; no trait code.
- **Data:** a CSV of 10,000 or 200,000 rows (`gen.jl`, deterministic): time, a group of five, `x`, `y`, an integer, a flag.
- **A round of work:**
  - read: `CSV.read` into a `DataFrame`, two new columns (one by `ByRow`), `filter`, `groupby`/`combine` (mean, std, count), `sort!`;
  - plot: one figure with four axes: a scatter coloured by a column with a colour bar, five lines with a legend, a bar plot with error bars, a histogram;
  - render: save as PNG;
  - edit: change the colour map, the marker size, the scatter's data, a title, axis limits, a line width, a line's visibility, the bar colours, add a text, switch an axis scale;
  - render the edited figure; then ten more edits without rendering.
- **Two load orders:**
  - interleaved, as a user works: load CSV and DataFrames, read; load the analysis packages, read again; load CairoMakie; then the rounds;
  - together, plain Julia's best case: every package loaded before any work.
- Eight rounds per session; fresh processes; three runs per order, size and mode; `@timed` separates compile and recompile time.
- **Modes:** plain (patched build, plain system image, `~/.julia`'s images) against the test bed `all` (the facts system image, a depot of images built under it). julia-1.13 3b8085c222. Load average 0.9–1.3.

Run: `ORDERS="interleaved together" SIZES="10k 200k" REPS=8 RUNS=3 bash run.sh > logs/run.log`, then `python3 analyze.py logs/run.log`.

## Results (`logs/run.log`, 2026-10-20; medians of three runs)

| Order, size | Mode | Session wall | Fixed part F | Compile | Recompile | A round |
|---|---|---|---|---|---|---|
| interleaved, 10k | plain | 43.6 s | 40.4 s | 33.7 s | 11.8 s | 399 ms |
| | all | 35.0 s | 30.4 s | 22.6 s | 0.5 s | 568 ms |
| interleaved, 200k | plain | 78.9 s | 40.7 s | 34.4 s | 11.8 s | 4,782 ms |
| | all | 69.8 s | 30.4 s | 22.8 s | 0.4 s | 4,941 ms |
| together, 10k | plain | 38.8 s | 35.6 s | 27.9 s | 7.9 s | 399 ms |
| | all | 33.9 s | 29.5 s | 21.9 s | 0.4 s | 547 ms |
| together, 200k | plain | 73.9 s | 36.0 s | 28.5 s | 7.8 s | 4,772 ms |
| | all | 68.8 s | 29.9 s | 22.6 s | 0.4 s | 4,862 ms |

F is the session's wall time minus eight steady rounds: start-up, loads and every first call. A round is the median of rounds 3–8, which compile nothing.

**Break-even** (a session of N rounds costs F + N × round):

| Order, size | `all` saves once | `all` costs per round | Break-even | Session length at break-even |
|---|---|---|---|---|
| interleaved, 10k | 10.0 s | +169 ms (1.42×) | 59 rounds | about 64 s |
| interleaved, 200k | 10.2 s | +159 ms (1.03×) | 64 rounds | about 5.8 min |
| together, 10k | 6.1 s | +148 ms (1.37×) | 42 rounds | about 52 s |
| together, 200k | 6.1 s | +91 ms (1.02×) | 67 rounds | about 5.9 min |

Counted in edits without rendering instead of rounds: 1,800–5,900 edits (3.3–3.5 against 1.8 ms per edit at 10k rows; 8.3–10.9 against 5.1–5.3 ms at 200k).

## Where the time goes

**What `all` saves, once per session:**
- **Recompilation:** 7.8–11.8 s under plain, 0.4–0.5 s under `all`. Loading the plotting and analysis packages invalidates code from the images, and plain recompiles it at first use. Loading everything first (together) does not avoid it: 7.8–7.9 s.
- **The interleaved order shows it phase by phase.** Reading the data:
  - first: 3.76 s plain, 1.20 s `all`;
  - after the analysis loads: plain 3.37 s, all of it recompilation; `all` 0.33 s;
  - after CairoMakie: plain 0.73 s, `all` 31 ms.
- **The first figure:** 17.6–17.9 s plain, of which 5.8–6.0 s recompilation; 11.5–12.1 s under `all`.

**What `all` pays, once per session:**
- **Loading:** CairoMakie 4.9 s under `all` against 1.9 s plain; everything together 6.5 against 3.1 s. Not diagnosed.
- **The first render:** 0.4–0.6 s more compilation.

**What `all` pays on every round:** Makie's machinery, not the data.
- **Building a figure:** 158–172 ms against 63–74 ms, about 2.4× (+95–100 ms) at both sizes.
- **An edit** (median of rounds 3–8): 4.4–4.6 against 2.2–2.4 ms at 10k rows; 7.2–7.3 against 4.4 ms at 200k rows.
- **A render:** +30 ms at 10k rows (185–192 against 156–157 ms); within 1 % at 200k rows (2.31–2.32 against 2.30–2.31 s, mostly Cairo's own work).
- **Reading:** equal.
- **The loss per round is about the same at both sizes:** 90–170 ms. It scales with the number of plot objects and attributes, not with the rows. At 200k rows a round is 2–3 % slower; at 10k rows, 40 %.

## Reading

- Below about 40–65 rounds of read, build, render and edit, `all` is faster overall. At 10k rows that is about a minute of session time; at 200k rows about six minutes.
- Each further package loaded during a session moves the break-even out further: one load of the analysis packages cost plain 3.4 s of recompilation here.
- The cost per round is Makie's figure and attribute machinery: dictionaries of `Any`, observables, compute graphs. These are exactly the abstract containers of the heterogeneous-collections review (`../hetero/`). They are what trait code would recover. TraitMakie's recolour and render rows (8.5–8.8 ms render, `../../writeup/design/evidence.md` §3) are the trait form of the same work, but not the same workload.
- Under `all`, 22 s of compilation remains in a fresh session (the first figure: 11.5–12 s). Neither mode's images cover this workload's first figure; that is a matter of workloads in images, not of the facts mode.

## Not measured

- Where the +100 ms per figure goes: the dispatch profiler (`jl_facts_dispatch_profile`) would name the call sites.
- Why loading CairoMakie costs 3 s more under `all`.
- An interactive back end (GLMakie), where every edit renders.
- The product setting: there, upstream code is compiled plainly, so this trade-off applies only where trait code calls into it (the review of heterogeneous collections, F1).
