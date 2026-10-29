# Phase 2's starting point: the sessions against Python (E-233), and a cache across sessions estimated (E-234)

Phase 2 of [the plan](../../writeup/record/todo.md#the-plan): principled performance work to bring the sessions close to Python's. This directory holds its first measurement round (E-233) and W-90's estimate of a machine-code cache across sessions (E-234). Registry rows: [`experiments.md`](../../writeup/record/experiments.md) E-233, E-234. Current numbers: [the evidence](../../writeup/design/evidence.md) §3.

**Scope** (the user, 2026-10-29, through the coordinator): "if we are beating Python already we don't really need much performance work." SciML (1.19–1.20 s against Python's 1.43 s, E-231) and Makie's plotting session (0.68–0.69 s against matplotlib's 0.98–0.99 s, E-228) were not rerun. The round covers the sessions that were slower than Python: the DataFrames/CSV forks' REPL session against pandas, and TraitReport's CSV→PNG against pandas+matplotlib.

## How to run

All Julia runs take the shared lock (`/tmp/claude-1000/julia-review.lock`), niced, under a kill timeout. The clock of `session.sh` starts inside the lock.

- `bash session.sh <mode> <tag> [runs] [env]`: the forks' session (`../../forks/scripts/session.jl`) in a real REPL on a pseudo-terminal, as `forks/scripts/measure_session.sh` runs it; a warm-up, then `runs`. Modes: `time` (Julia's compile counter and the garbage collector's time at each mark), `detail` (plus `@time_imports`, TraitWorld's load report of the first uses, the CodeInstances created after the imports, `--trace-compile-timing`), `record` (E-234's recording), `cache` (E-234's cache loaded with the imports). `HINTS=0` turns the REPL's typing hints off; `TRACE=1` adds the compile trace; `NOE=1` runs without the `-e` that starts the compile counter.
- `parse.py <run.out> [--table]`: a run's steps, wall / compile (the counter sums over threads, so it can exceed the wall time while the REPL compiles in the background).
- `trace_sum.py <trace.jl>`: the compile roots of a trace by kind, before and after the load mark.
- `prof_load.jl <Pkg,Pkg,…>`: where a load goes, by sampling (E-185's `../ttfx/loader/prof_load.jl`, TraitWorld's hooks added). `PROF_DELAY` sets the sampling interval.
- `invalidations.jl <Pkg,Pkg,…>`: what the load invalidates, by the method inserted.
- `tr_breakdown.jl <csv> <png>`: TraitReport's form (t) (`../../TraitReport/scripts/report_tables.jl`) with each phase's wall, compile and GC time; `TR_DETAIL=1` (with `JULIA_TW_LOADREPORT=1`), `TR_RECORD=<file>`, `TR_CACHE=<package>`.
- `rec.jl`: E-175's walk of the method table (`../ttfx/cache/record_cis.jl`) as functions, included into a running session; it serializes each recorded type on its own.
- `make_cache.sh <name> <recording> <source env> <env out> "<packages>"`: E-175's emulated cache (`../ttfx/cache/make_cache.sh`) from such a recording: plain code replayed by `precompile`, the facts owner's by `fpc`, TraitWorld's first-call checks kept as checked ahead. `probe_cached.jl` asks which recorded signatures the cache's image holds after the load.

The forks' harness and TraitReport's: `cd ../../forks && JULIA_LOCK=/tmp/claude-1000/julia-review.lock bash scripts/measure_session.sh 3 "py fk-patched up-patched"`; `cd ../../TraitReport && JULIAS=../julia-1.13/julia JULIA_LOCK=… bash scripts/measure.sh 3 "t pt"` (neither script changed). Python: a fresh venv at `/tmp/claude-1000/pyenv` (the scripts' default; it is not committed), Python 3.12.14, pandas 3.0.6, matplotlib 3.11.2, numpy 2.5.4.

## E-233, 2026-10-29

julia-1.13 bfca89decc, TraitWorld ca92f22, forks 115c208, TraitReport 09d7f9b (TraitCSV 9c6477b, TraitTables 438ac2b, TraitMakie 2c70583). Product setting, strict mode off. Fresh processes; a warm-up, then 2 runs (the warm-ups are in the logs). Load average 0.1–0.6 before the runs (1.2–1.9 while the harness's own Julia jobs ran); another agent shared the lock (one wait of 353 s, outside the clock). Measures idiomatic trait code (the forks, form (t)) and plain code (upstream, form (pt)).

### The forks' REPL session against pandas

`forks/scripts/measure_session.sh 3 "py fk-patched up-patched"` (`logs/forks-session.log`). Seconds; "steps" are the session after the imports.

| | start | imports | steps | exit | **wall** |
|---|---|---|---|---|---|
| pandas | 0.010 | 0.202–0.203 | 0.295–0.298 | 0.033 | **0.541–0.542** |
| forks (`fk-patched`) | 0.58–0.59 | 1.86–2.00 | 2.11–2.15 | 0.13 | **4.71–4.83** |
| upstream (`up-patched`) | 0.34–0.59 | 1.22–1.23 | 10.87–10.89 | 0.09–0.12 | **12.55–12.79** |

The forks' session is 8.7–8.9 times pandas'; upstream's 23 times. pandas' steps: 0.14 s of them are its `apply` over rows (the user function), 0.04 s the join.

### Where the forks' session goes

`session.sh` (`logs/forks-time.log`, `forks-time-nohints.log`, `forks-time-noe.log`, `forks-detail.log`, the raw REPL output in `logs/<tag>/`). Two findings about the harness first:
- **The REPL's start is bimodal:** 0.36 s or 0.60 s, in every mode (with or without `-e`). Julia's process start alone is 0.10 s (TraitReport's scripts). Python's start is 0.01 s.
- **The REPL's typing hints compile in the background** while the pasted input arrives (`REPL.REPLCompletions.REPLInterpreter`'s inference: 0.8 s and 0.5 s compile roots in the trace). They add 0.45–0.55 s to the imports step. A person typing would not see this cost; the pasted session does. With the hints off (`HINTS=0`) the session is 3.89–4.14 s.

The session with the hints off (`logs/nohints/`, 2 runs after a warm-up):

| Part | forks: wall | of it compiling | of it GC | pandas |
|---|---|---|---|---|
| start (process and REPL) | 0.36 / 0.61 | 0.10 | | 0.01 |
| imports | 1.38 | 0.46 | 0.13 | 0.20 |
| steps | 2.03–2.04 | 1.55 | 0.17–0.18 | 0.30 |
| exit | 0.12 | | | 0.03 |
| **wall** | **3.89–4.14** | | | **0.54** |

**The steps:** 1.55 s of the 2.04 s is compilation; the run time (about 0.3 s without compilation and GC) is about pandas' 0.30 s. The compile roots after the load (`trace_sum.py`, `logs/forks-trace-summary.log`; a root's time includes its callees):

| Kind | roots | ms |
|---|---|---|
| plain code invalidated by the loads and compiled again (`DataFrames.manipulate` 229 ms, the compiler's own `typeinf_code` and `get_infer_result` 108 ms, `innerjoin`, `copy` of the column types) | 38 | 484 |
| DataFrames, CSV, Tables, plain (`_add_col_check_copy`, `batch_compacttype`'s closures, `CSV.write`, `normalize_selection`) | 32 | 351 |
| TraitWorld's `Callable` entries (`enter_callable` 131 ms), first-call checks (`checked_call`), `byrow`, inference at run time | 21 | 304 |
| display (`show` of a `DataFrame` at the REPL, `print_response`) | 16 | 238 |
| the user's closures (`ByRow{Main.var"#…"}`) | 9 | 89 |
| Base, other | 16 | 84 |

The session creates 2,595 CodeInstances after the imports (a count that includes the probes' own): 2,468 plain (1,944 of them Base methods), 100 of the facts owner, 27 of `return_type`'s owner; 147 name a type of `Main`. TraitWorld's machinery at first use (its load report, `logs/d/detail-1.out`): first-call checks of 4 worker signatures 49 ms (45 ms compiling, `tocolumn` at `Column{DataString}` 48 ms), the untyped table's first sight of 31 types 14 ms.

**The load** (`prof_load.jl` over `using CSV, DataFrames, Statistics, Dates` in a script, 1.22–1.27 s, 0.22–0.25 s compiling; shares of the main thread's samples at 5 ms and 2 ms, the listener thread being the other half; `logs/forks-load-profile-coarse.log`):
- restoring the images (`_include_from_serialized`): about 90%; of it validating their edges (`insert_backedges`, `verify_method_graph`) about 50%, about 0.6 s; activating methods 5–6%;
- TraitWorld's member records (`_member_fold_at_load`, `_member_from_record!`): about 13%, about 0.15 s (E-231's load report: 26 members from records 134 ms, one checked 22 ms); its image hook about 4.5%, about 0.05 s;
- finding and checking cache files (`stale_cachefile`): about 7%; garbage collection about 8%.
- `@time_imports` in the REPL (`logs/d/detail-w.out`): CSV 323 ms, DataFrames 310 ms, PrettyTables 89 ms, TraitWorld 87 ms, Parsers 48 ms, Tables 40 ms, CSV's three extensions 76 ms.
- In the REPL the imports take 0.1–0.15 s more than in a script: the REPL's own `ansi_write` (163–170 ms), invalidated by the loads, is compiled again for the next prompt.

**What the loads invalidate** (`invalidations.jl`, `logs/forks-invalidations.log`): 2,158 MethodInstances, by methods of plain upstream dependencies: LaTeXStrings' `codeunits` (177) and `show`, SentinelArrays' `eltype(::BufferedVector)` (138) and others, InlineStrings' `nextind` (127) and `thisind` (75), CSV's `eltype(::Type{File})` (19). None by a trait package's method.

### TraitReport's CSV→PNG against pandas+matplotlib

`TraitReport/scripts/measure.sh 3 "t pt"`, patched build only (`logs/traitreport.log`; the first Julia run of each form precompiled stale images: imports 8.6 s and 1.8 s, not counted).

| | startup | imports | read | summarize | plot+PNG | exit | **wall** |
|---|---|---|---|---|---|---|---|
| pandas + matplotlib | | 0.42–0.44 | 0.001 | 0.001 | 0.10 | | **0.61–0.62** |
| form (t): TraitCSV, TraitTables, TraitMakie | 0.10 | 0.36 | 0.006 | 0.012–0.013 | 0.063 | 0.09 | **0.63** |
| form (pt): the same without traits | 0.10 | 0.33 | 0.004 | 0.000 | 0.073 | 0.084–0.088 | **0.59–0.60** |

Form (t) is 0.01–0.02 s above Python's (E-163 on 2026-10-27: 0.83–0.86 s). Its load is below Python's imports. After the load it takes 0.073–0.075 s, 0.034 s of it compiling (`tr_breakdown.jl`, `logs/traitreport-breakdown.log`): 591 CodeInstances, 585 plain; TraitWorld's first-use machinery about 0.06 s (the untyped table's first sight 50 ms, of it 44 ms compiling; a member check 13 ms; `logs/traitreport-detail.log`).

## E-234, 2026-10-29: a machine-code cache across sessions, estimated

E-175's method: the session's CodeInstances created after its load, recorded from the session it is measured on, replayed by a precompiled package (`SessionCacheFk1`, `SessionCacheTR`) loaded with the imports. Same builds as E-233; a warm-up and 2 runs.

**The forks** (recorded from a session with the hints on, `logs/forks-record.log`): 1,372 new CodeInstances; 172 name a type of `Main`; 1,175 types kept (1,083 plain, 92 of the facts owner) and 4 first-call checks. Nothing was compiled after `using InlineStrings` (CSV loads it), so one cache. The cache's build: 965 replayed, 214 not compiled by `precompile` as written (`logs/cache-SessionCacheFk1-precompile.log`). Its load adds nothing measurable (imports 1.38–1.42 s).

| Forks' session | start | imports | steps (of it compiling) | exit | **wall** |
|---|---|---|---|---|---|
| hints off, no cache | 0.36 / 0.61 | 1.38 | 2.03–2.04 (1.55) | 0.12 | **3.89–4.14** |
| hints off, **with the cache** | 0.36 / 0.61 | 1.40–1.42 | 1.09–1.10 (0.58–0.59) | 0.12 | **2.99–3.22** |
| hints on (the D0 harness), no cache | 0.36 | 1.82–1.89 | 1.97–2.03 (1.55–1.64) | 0.12 | **4.33** |
| hints on, **with the cache** | 0.36 | 1.84 | 1.06–1.08 (0.65–0.67) | 0.12 | **3.37–3.40** |
| pandas | 0.01 | 0.20 | 0.30 | 0.03 | **0.54** |

The cache takes 0.9–1.0 s off the steps. **What remains** (hints off, 3.0–3.2 s, 5.5–6 times pandas'):
- the load, 1.4 s (pandas 0.2 s): validation about 0.6 s, TraitWorld's member records and image hook about 0.2 s, the rest restoring images, checking cache files, GC;
- the REPL's start, 0.36–0.61 s (Python 0.01 s; Julia's process 0.10 s);
- the steps' compilation, 0.58 s (`logs/cache-nohints/trace-1.jl`):
  - **signatures with a type value**, which a package image does not keep ([compiler §2.9](../../writeup/reference/compiler.md#29-what-package-images-keep): no external code at a signature type without a hash): TraitWorld's `enter_callable(::Type{Tuple{…}}, ::Type{Bool}, …)` 131 ms, DataFrames' `batch_compacttype` closures over `Type{Union{Missing, Int64}}` about 45 ms. Recorded and accepted by `precompile` in the cache's build, absent after the load (`probe_cached.jl`, `logs/forks-cache-probe.log`);
  - plain code invalidated by the loads: the compiler's own `typeinf_code` and `get_infer_result` (115 ms), compiled again after the cache's copies were invalidated;
  - the user's closures (`ByRow{Main.var"#…"}`, 44 ms) and the inference of their result at the `Callable`'s entry: keyed on the session, no cache keeps them;
  - `CSV.write` 30 ms (its cached copy has no machine code after the load; not diagnosed);
- the run time, about 0.3–0.4 s, and GC 0.11 s; the exit 0.12 s.

**TraitReport** (`logs/traitreport-record.log`, `traitreport-cache-startexit.log`): 520 new CodeInstances, 447 types kept (all plain), 420 replayed. After the load 0.073–0.076 → 0.053 s (compiling 0.034–0.036 → 0.014 s); the exit 0.069–0.070 → 0.051 s. The cache would bring form (t) from 0.63 s to about 0.59 s, below Python's 0.61–0.62 s. What remains: the load 0.36 s, the start 0.10 s, the exit 0.05 s.

### The estimate's limits

- **An emulation, not a cache.** It replays what one session compiled into one package image. A real cache must decide what to keep and validate it; it would keep what Julia's images keep and no more.
- **Plain code dominates these sessions:** of the forks' 1,175 recorded types 1,083 are plain, 92 the facts owner's; TraitReport's are all plain. Facts code is replayable this way (`fpc` compiles it for the facts owner, and images keep it with machine code, [compiler §2.9](../../writeup/reference/compiler.md#29-what-package-images-keep), valid across unrelated loads). But a store keyed on facts alone (W-66, [its note](../../writeup/plans/2026-10-28-facts-cache-store.md) §1: entries of owner `:facts` only, none with an edge to another owner's code) would keep about a tenth of what saved the 0.9 s here. The estimate is for a cache that keeps plain code too, as an environment-keyed cache would.
- **Plain code in the cache is invalidated like any plain code:** the compiler's own code was compiled again although the cache held it. A cache keyed on facts would not have this loss for facts code (G2).
- **Signatures with a type value are not kept by images** (compiler §2.9), so neither the emulation nor a cache built on images keeps TraitWorld's `Callable` entries. The emulation underestimates what a cache could keep by about 0.2 s here, if that rule were lifted.
- **The REPL's typing hints:** the forks' recording was made with them on; their code is in the cache, unused with them off.
- **Not counted:** the cache's build time and size (precompile 3.6 s and 1.6 s here), a cache recorded from another session's shapes (E-173: each new shape compiles once).
