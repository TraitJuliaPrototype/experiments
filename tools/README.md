# Tools for finding slowdowns (W-85)

Four tools, for the questions asked again and again while porting:

| Tool | Question | Where |
|---|---|---|
| A/B harness | Is this change faster or slower, and where (first call, compilation, steady state, allocation)? | `ab/ab.sh`, `ab/ABProbe.jl` |
| `TraitWorld.callpath(f, args...)` | Which path does this call into trait code take, and what does it cost? | TraitWorld branch `w85-tooling`, `src/diagnostics.jl` |
| `TraitWorld.factscode(f, types)` | Which calls in the code compiled by facts are chosen at run time? | same |
| `TraitWorld.loadreport()` | What do TraitWorld's checks and folds cost during `using` and at first uses? | same, and `src/report.jl` |

`callpath`, `factscode` and `loadreport` are public in TraitWorld but not exported.
Cthulhu's interactive descent over the facts owner's code is not built: Cthulhu is not in the depot and the sandbox blocks the package server.
`factscode` reads the same code non-interactively.

The machine's rules hold for every tool: one Julia job at a time through `flock /tmp/claude-1000/julia-review.lock nice -n 19 …`, with `JULIA_PKG_OFFLINE=true`.

## The A/B harness

```
experiments/tools/ab/ab.sh <repo dir> <before ref> <env dir | -> <probe.jl> [runs, default 3]
```

- "before" is a git worktree of the repository at `<before ref>`, beside it (`<repo>-ab-<sha>`), so packages' relative `[sources]` (`../TraitWorld`) resolve as in the repository.
  It is reused when it exists. Remove it with `git -C <repo> worktree remove <repo>-ab-<sha>`.
- "after" is the repository's working tree, uncommitted changes included. `AFTER=<ref>` makes it a second worktree.
- The environment: `-` makes one holding only the repository's own package.
  Otherwise each side gets a copy of `<env dir>` with every relative path made absolute; paths into the repository point at that side's tree.
  An environment inside the repository is taken from each side's tree.
- Each side precompiles into a depot of its own, stacked on `~/.julia`: the two builds' caches evict neither each other nor `~/.julia`'s.
- The runs alternate between the sides, one process per run.
- The work directory is `$AB_WORK` (default `$TMPDIR/ab`); each comparison keeps its environments, depots, run logs and `result.txt` there.
- `JULIA` overrides the patched julia-1.13; `AB_PROBE_ARGS` is passed to the probe.

A probe is a script that prints `AB <name> key=value …` lines.
`ABProbe.jl` gives two helpers (include it with `include(joinpath(ENV["AB_TOOLS"], "ABProbe.jl"))`):

- `abmeasure(name, f; runs = 5, per = 1)`: the first call of `f()` (its time, Julia's compile and recompile time, the CodeInstances inferred) and the steady state (the minimum of `runs` calls after two warm-ups; the bytes, allocations and GC time of one). With `per = n` (`f` makes `n` calls) also per call.
- `abreport(name; key = value, …)`: any other number (a load time, a count).

The table gives, per key, the range over the runs on each side and the ratio of the minima (after / before).

### Worked examples (2026-10-28, julia-1.13 a4e9ad5da9; logs in `ab/logs/`)

1. TraitWorld 38a3abf puts a bounded function's declared result on its entry. Before it, a plain caller calling with values of unknown type saw `Any`.

   ```
   ab.sh TraitWorld-w85 728b0f2 - ab/examples/entry_result.jl 2
   ```

   | key | before 728b0f2 | after 38a3abf |
   |---|---|---|
   | the plain caller's result inferred `Float64` | 0 | 1 |
   | untyped call, ns per call | 79.5–85.6 | 61.5–62.8 |
   | untyped call, bytes per call | 80 | 80 |

2. The forks' `groupby`-`sum` on an integer key (10⁶ rows), before and after the boxed counter in `_group_rows!` was fixed (E-214).

   ```
   AFTER=ff89a63 ab.sh forks 009565d forks/env_forks ab/examples/forks_groupby.jl 3
   ```

   | key | before 009565d | after ff89a63 |
   |---|---|---|
   | `using CSV, DataFrames, Random`, ms | 1626–1674 | 1633–1658 |
   | steady, ms | 39.3–40.8 | 4.40–4.52 |
   | steady, allocations | 489,600 | 309 |
   | first call, compile ms (all of it recompilation) | 8.7–8.9 | 8.8–8.9 |

3. A change found with `loadreport` (below): the override index's two functions not specialized on each family member's builder type (`ab/examples/index_nospecialize.patch`, applied to the working tree, not committed).
   The forks' environment with TraitWorld at `TraitWorld-w85` (a copy of `forks/env_forks`, its TraitWorld path changed).

   ```
   ab.sh TraitWorld-w85 322a42e <env> ab/examples/forks_load_index.jl 3
   ```

   | key | before 322a42e | after the patch |
   |---|---|---|
   | `using CSV, DataFrames, Statistics, Dates`, ms | 1737–1754 | 1399–1410 |
   | 27 members fixed at load, ms (compiling) | 723–729 (704–710) | 384 (366) |
   | of it the override index, ms | 397–401 | 55–57 |
   | of it the check, ms | 94–96 | 94–97 |
   | of it the builder, ms | 103–104 | 102–104 |

## `callpath`: the path of a call

```julia
TraitWorld.callpath(f, args...; time = true)      # displays a report; returns a CallPath
```

It reports, for a caller that knows the arguments' types (typed) and one that does not (untyped):

- per bounded argument: the value's form (plain, `Compiled`, `Dynamic`, `Kept`, `compiled_for`, `with_dynamic`);
- the traits the position needs, and how each is implemented for the object's type: declared; a family's member, fixed in this session or not; generic; none;
- what the entry decides: the trait object at its key, the erased key, or the table of declared implementations through a pointer (`_UWrap`);
- whether the trait object's type is known where the call is compiled, or made when the call runs (then the worker is chosen by a dispatch);
- the worker method the call reaches;
- the run-time sites left in the typed caller's code (the entry inlined), and in the worker's code; sites on rare paths (an error, a first call, a result like the input) are listed apart;
- the time and bytes per call from both callers.

The call is made to time it, so its first-call checks and table entries happen as they would. `time = false` skips the timing.

### Worked example: E-218's calls (`scripts/x6_callpath.jl`, log `logs/x6_callpath.log`)

```
julia --project=TraitWorld-w85 experiments/tools/scripts/x6_callpath.jl
```

```
callpath: cb(::Dynamic{IntegratorView})
  argument 1: Dynamic{IntegratorView} holding IntA
    the position needs HasDu, IntegratorView
      HasDu: none: no method of its own, so each call that needs it asks the slow path's cache (`_conformance_slow`, an IdDict by trait and type)
      IntegratorView: declared for IntA (Main.X6)
    typed caller:   Dynamic: the erased key (code compiled once) (the held value's attribute): IntegratorView at Dynamic
    the trait object's type is not known where the call is compiled: it is made when the call runs, and the worker is chosen by a dispatch on it (the object's traits)
  worker: cb(::IntegratorView) at x6.jl:29 (Main.X6)
  typed caller's code (the entry inlined):
    run-time sites: 2 (and 2 on rare paths)
      [dynamic dispatch] _enter_erased(::EntryPos{typeof(cb), 1, 1}, ::Any)
      [dynamic dispatch] checked_call(::typeof(cb), ::Any)
  per call: typed caller 289.0 ns, 176.0 bytes; untyped caller 328.0 ns, 176.0 bytes
```

The same call with an `IntB` (which implements `HasDu`) costs 52 ns and 80 bytes.
The difference is the lookup of `HasDu` for `IntA`: no method, so the slow path's cache answers on every call.
`scripts/x6_conformance.jl` measures it alone: `conformance(As{HasDu}(), x)` 200 ns for an `IntA`, 19 ns for an `IntB` (`logs/x6_conformance.log`).

## `factscode`: the code compiled by facts, its run-time sites

```julia
TraitWorld.factscode(f, types; depth = 2, plain = false, ir = false, facts = true)
TraitWorld.factscode(sig::Type{<:Tuple}; …)
TraitWorld.factscode(callpath(f, args...))        # the worker's code of that call
```

It infers the signature with the facts interpreter (`Base.Compiler.facts_interp(NativeInterpreter())`), optimized, and follows the code it invokes statically `depth` levels down (code of the facts owner; `plain = true`: any code).
It lists the run-time sites: dynamic dispatches, a split's last branch (a table by the value's type and a call through its pointer, with the split's candidates now), calls through a pointer, `invokelatest` and `_apply_iterate`.
Sites in the untyped fallback and in error paths are listed apart.
`ir = true` prints the code, each run-time site marked `▶`. `facts = false` reads plain inference instead.

### Worked example: E-218's loop in trait code

```julia
TraitWorld.factscode(X6.run_cb, (Vector{Dynamic{IntegratorView}}, Int))
```

```
  run-time sites: 3 (and 4 on rare paths)
    [dynamic dispatch] _enter_erased(::EntryPos{typeof(cb), 1, 1}, ::Any)
        in Tuple{typeof(run_cb), …} %57, run_cb x6.jl:35 → … → enter entry.jl:220 → _enter_held entry.jl:230
    [dynamic dispatch] checked_call(::typeof(cb), ::Any)
        in Tuple{typeof(run_cb), …} %68, run_cb x6.jl:35 → cb none:0 → macro expansion trait_module.jl:1181
    [dynamic dispatch] +(::Any, ::Any)
        in Tuple{typeof(run_cb), …} %78, run_cb x6.jl:35
```

The third site is `s += cb(i)`: `cb` declares no result, so the sum is `Any`.
Declaring `::Float64` on both methods (`scripts/x6_declared.jl`) takes E-218's loop from 366 to 338 ns per call (`logs/x6_declared.log`, one process each).

## `loadreport`: the machinery's costs at load and first use

```
JULIA_TW_LOADREPORT=1 julia --project=<env> script.jl
```

```julia
TraitWorld.loadreport(io = stdout; top = 5)     # print what was recorded
TraitWorld.loadreport_switch!(true)             # start again from here (reset); false: stop
```

The switch is read in TraitWorld's `__init__`, so the loads after TraitWorld are recorded.
Off, each recorded step costs the load of a flag and a branch.
Per step it gives the count, the time and the compile time inside it (Julia's counter), and the slowest items of each group:

- family members fixed at a package's load (a fold kept in an image, checked again by `fold_holds`), in a fold, and at first use; each by its check, its builder and the override index;
- the image hook (the override index, the override check, strict mode's refusals), per package image;
- the package-load callback (the generation and dynamic candidates, strict mode's validation log);
- the definition hook; the definition checks at a trait module's end;
- first-call checks of worker signatures; implementations found by the slow path; the untyped table's misses.

### Worked example: the forks' import (`scripts/forks_loadreport.jl`, log `logs/forks_loadreport.log`)

TraitWorld w85-tooling 7c16713; the forks at 78327b5; one process.

```
using CSV, DataFrames, Statistics, Dates: 1.707 s
TraitWorld load report: 2.067 s since the recording started, of it 1.179 s compiling (Julia's counter)
  step                       count        ms  compiling
  family members fixed at a package's load (a fold kept in its image, checked again: fold_holds)
    total                       27     669.2      648.8
    index                       27     339.3      338.0
    builder                     27     101.7       99.2
    check                       27      98.3       82.4
    already fixed               10
  the image hook (each package image's methods: overrides, strict mode)
    total                       46      55.2       32.1
```

The member fixes at load (E-213's 28 members) are almost all compilation.
Half of it is the override index, specialized on each member's builder type; A/B example 3 removes it.
The same import with the switch off took 1.735 s.

## Results table

| Date | Build | What | Result |
|---|---|---|---|
| 2026-10-28 | julia-1.13 a4e9ad5da9; TraitWorld 728b0f2 → 38a3abf | A/B 1: an untyped call of a bounded function with a declared result | inferred `Float64`; 80 → 62 ns per call; 80 bytes per call on both sides |
| 2026-10-28 | same; forks 009565d → ff89a63, TraitWorld main | A/B 2: `groupby`-`sum`, 10⁶ rows | 39.3 → 4.4 ms; 489,600 → 309 allocations |
| 2026-10-28 | same; TraitWorld w85-tooling 322a42e ± the patch; forks 78327b5 | A/B 3: the forks' import | 1.74 → 1.40 s; members at load 723 → 384 ms |
| 2026-10-28 | same; TraitWorld w85-tooling | `callpath` on E-218's calls | `Dynamic` holding `IntA` 289 ns, `IntB` 52 ns (typed caller); `HasDu`'s negative lookup 200 ns |

## Files

- `ab/ab.sh`, `ab/ABProbe.jl`: the harness. `ab/examples/`: the probes above and the patch of example 3. `ab/logs/`: each example's `result.txt`, the AB lines of both sides and `Pkg.status` of both environments.
- `scripts/x6_callpath.jl`, `scripts/x6_conformance.jl`, `scripts/x6_declared.jl`, `scripts/forks_loadreport.jl`; their logs in `logs/`.
