# W-169: where a session's time goes (E-536)

The question (the registry, E-536): in each workload, where does a session's wall time go (Julia's start, the load in its parts, inference, code generation, what is compiled again and why, dispatch at run time, the collector, the work), by package and by function, beside its plain run; which parts does a rule of the design let the compiler not do, what would each save, and how much code is the fix?

The stiff ODE's steady state (E-537) is another agent's, in `stiff/` (not this README).

## How to run

```sh
cd experiments/implementation/w169
bash prepare.sh H                      # the head's images into agent-depots/w169/H (about 12 minutes after a rebuild)
bash run_all.sh <label> [frames table ode plot nd]          # every session, beside its plain run (about 25 minutes)
bash profile.sh <session> <setting> <time|prof|trace|inval|dispatch> [<run>]   # one run (LABEL=<label>)
python3 tools/split.py logs/<label> ode-H ode-plain-H       # the split of the wall time, the phases
python3 tools/top.py logs/<label>/ode-H-trace-2 20          # the largest compiles, the census (gunzip a .gz first)
python3 tools/llvm_phases.py logs/<label>/ode-H-trace-2.llvm   # code generation by phase
```

- **Settings** (`lib.sh`, on W-159's `lib.sh`): **H** the head, julia `next` 683ea4fc16 (`julia-next`, two commits after the freeze `round-2026-11-c`), TraitWorld `unified` 38200d3, the demonstrators and ports at the freeze (TraitDifferentialEquations 06c28c3, TraitMakie 1888698, TraitTables e1ec1f4, TraitCSV 094dcb2, TraitReport ec34d12, forks a3a37d6, NetworkDynamics c2bbf0d, ndport 4fecc02). **V** vanilla v1.13.2 (45b6d15e34). The round's depots were stale for H (the head moved): H writes its own images into `agent-depots/w169/H`; V reads the round's V depot behind `agent-depots/w169/V`. Environments: W-134's `env_up`, `env_facts`, `env_forks`, `env_demo`, ndport's `env_unified_r5`, made per setting into `envs/` (ignored by git).
- **The sessions** (`sessions/`): `frames.jl` is E-511's work (`w134/lost.jl`, order A: CSV read, `describe`, `sort`, `groupby`-`combine`, the digest by `repr`), the nine unrelated loads, the work again: `frames-up` (upstream CSV, DataFrames compiled plainly; V and H), `frames-facts` (the same by facts, one line per module), `frames-forks`. `app.jl` runs a demonstrator's program as E-521's `session_marks.jl` does (the file, which loads the packages, with `VERIFY=0`; `main` twice): `table`, `ode`, `odecb` (`w158/port/apps/ode_cb.jl`), `plot`, `report`, each beside its plain twin on the same build (`table-plain`: PlainTables; `ode-plain`: PlainODE; `odecb-plain`: `sessions/ode_cb_plain.jl`, the same Lorenz problem and callbacks on PlainODE; `plot-plain`: PlainPlots; `report-plain`: PlainTables with PlainPlots). `nd.jl`: NetworkDynamics' workload (`NDW_API=ports NDW_STACK=ports`, passes first, again, params, changed, graphtype) as one phase.
- **The harness** (`tools/prof.jl`, one for every session): the session's file cut into phases at `#@` lines, each evaluated at top level in one process. Kinds (`profile.sh`):
  - `time`: each phase timed with Julia's counters (`Base.cumulative_compile_time_ns`: compiling and of it compiled again; `Base.gc_num`: the collector, allocations); `START`/`END` lines and the process's wall time give Julia's start and exit.
  - `prof`: each phase under the sampling profiler at 1 ms with C frames, driven through the runtime's entry points (`jl_profile_*`, frames by `Base.StackTraces.lookup`; the Profile standard library is not loaded, see "Trust" below). Every sample of the main thread that is not sleeping goes to one class, the first in `tools/classes.jl`'s order with a frame on the stack: the collector; the load's parts (the membership walk, the memberships' activation, the methods' insertion and invalidation, the library's image hook, package callbacks, `__init__`, the edges' validation, the images' restore, with ": compiling" where code is generated below them); the definition-time check; the member check; compiling while inferring; inference; code generation; a split's pointer; the box's checks; lookup's slow path; lowering; definitions; the load's rest (finding and reading files); the runtime's dispatch fast path (C frames at the leaf); the work. A class's time is its share times the phase's unprofiled median (shares, not profiled times).
  - `trace`: `--trace-compile-timing` (each compile dispatched, inference and code generation below it), Julia's dump of every code generation (`jl_dump_compiles`, with the phases marked) and, at the end, the census of every code instance the process inferred (outside every image, `jl_object_in_image`) or generated machine code for (`time_compile > 0`; an image's instances start at 0), with its own `time_infer_self` and `time_compile` (`tools/census.jl`).
  - `inval`: Julia's invalidation log over the session (`jl_debug_method_invalidation`), by kind, cause and root module (`tools/invalidations.jl`; the edges' validation at load is its `verify_methods` entries).
  - `dispatch`: the head's dispatch profiler (`JULIA_DISPATCH_PROFILE=1`, `src/gf.c`): dynamic calls by callee and call site, over the whole process.
- Every run: one thread, niced, product setting, strict mode off, a fresh process; the log's header names every tree's commit and the depots; a run fails if a package image's `.so` is written during it (a load precompiled). `run_all.sh`: a warm-up and 3 unprofiled runs per cell, interleaved with the plain run within each group, then one run of each other kind; nd one run of each kind and 2 unprofiled.
- **Probes** (`probes/`): `profiled_load.jl` (does the profiler change a load), `macro_compile.jl` (what a fresh process compiles for `@static`, `(@main)` and two Base instances, H and V).

## Results, 2026-11-22

Builds as above. Interop or idiomatic: every session is trait code as its port writes it (idiomatic for the demonstrators and the ODE port; the forks and NetworkDynamics are ports of upstream packages), beside plain code. The machine: 128 cores, 1-minute load 1.9 to 5.9 (others' jobs, and one other agent's); one Julia job of this agent at a time. Logs: `logs/r1/` (per run `<session>-<S>-<kind>-<run>.out`; the tables below are `logs/r1/split-*.md`, `top-*.md`, `llvm-*.md`); the order of the runs and every rc: `logs/run-r1.log`.

### The split of the wall time (ms; median of 3 unprofiled runs after a warm-up, nd of 2; the classes are the profile's shares scaled to the unprofiled phases)

**Upstream CSV and DataFrames, E-511's work, the nine loads, the work again** (`split-frames.md`; profile samples 16,242 / 16,357 / 9,260 / 9,342):

| part | plain, vanilla | plain, head | by facts, head | the forks, head |
|---|---|---|---|---|
| wall | **16,596** (16,426-17,280) | **16,781** (16,684-17,324) | **10,218** (9,950-11,072) | **10,017** (9,647-10,035) |
| Julia's start | 189 | 363 | 356 | 354 |
| code generation | 7,309 | 7,217 | 2,469 | 1,716 |
| inference | 1,661 | 1,534 | 366 | 393 |
| compiling while inferring | 366 | 364 | 135 | 92 |
| load: the rest (finding, opening, reading files) | 2,154 | 2,130 | 2,161 | 2,148 |
| load: the edges' validation | 1,366 | 1,401 | 1,307 | 1,564 |
| load: the images' restore | 1,280 | 1,343 | 1,329 | 1,337 |
| load: methods' insertion and invalidation | 866 | 892 | 887 | 894 |
| load: `__init__`, package callbacks | 291 | 289 | 324 | 329 |
| load: the library's image hook, the walk, the memberships | — | — | — | 148 |
| garbage collection | 731 | 871 | 522 | 645 |
| dispatch (lookup's slow path, fast path) | 9 | 7 | 4 | 10 |
| the work itself | 15 | 17 | 17 | 17 |
| the harness; exit | 214; 144 | 208; 142 | 203; 137 | 226; 141 |

By phase (unprofiled medians, ms; compiling, of it again):

| phase | plain, vanilla | plain, head | by facts | the forks |
|---|---|---|---|---|
| `using CSV, DataFrames` | 1,069 (0) | 1,201 (0) | 1,058 (0) | 1,278 (26) |
| first work | 4,416 (4,408, again 996) | 4,471 (4,463, again 995) | 1,769 (1,758, again 9) | 197 (186) |
| the nine loads | 5,161 | 5,152 | 5,233 | 5,546 |
| the work after the loads | 5,400 (all again) | 5,240 (all again) | 1,459 (all again) | 2,270 (all again) |
| the work, repeated | 1.7-1.9 | 1.8 | 2.0 | 2.2-2.4 |

- Plain code on the head is plain code on vanilla within the spread, part by part (open issue 225's 0.07 s is inside this spread).
- By facts and the forks save code generation and inference (7.2 s to 2.5 and 1.7 s). The loads' parts cost the same in every setting: 5.2-5.5 s of the nine loads, of which 1.6-1.7 s is finding and reading files.
- **What the work after the loads compiles again** (`top-frames-*.md`, the census): by facts 1.46 s, the forks 2.27 s, of which PrettyTables' printing of the digest's `repr` (`_text__print_table_core` and its keyword method, 0.92 s; PrettyTables is upstream's, compiled plainly in both environments) and `CSV._parse` (0.39 s by facts, 0.64 s the forks: GT-8's culprit, SparseArrays' `vcat`, E-511). Plain: 5.2-5.4 s, the whole work.
- What the nine loads end (`*-inval-1.out`): plain 9,279 entries on the head (Base 4,614, the Compiler 2,719, DataFrames 790, CSV 558), vanilla 7,922 (the Compiler 1,361); by facts 6,215 (CSV and DataFrames none among the top roots), the forks 6,638 (CSV 201). The largest causes: Unitful's `Colon(::Any, ::Quantity)` (1,135-1,335), `write(::IO, ::String)` (943-987), `==(::Any, ::Function)`, SentinelArrays' constructor, ChainRulesCore's `*`, REPLCompletions' interpreter. The Compiler's ended instances are not compiled again (inference runs in its own world; the census holds 0 or 1 of them).

**The demonstrators' programs and their plain twins** (`split-demo.md`, `split-plot.md`; samples 293/176, 990/663, 826/378, 702/612, 770/644):

| part | table | table, plain | ODE | ODE, plain | ODE with callbacks | its plain twin | plot | plot, plain | report | report, plain |
|---|---|---|---|---|---|---|---|---|---|---|
| wall | **696** (680-839) | **587** (585-717) | **1,369** (1,318-1,489) | **1,235** (1,087-1,236) | **1,298** (1,287-1,373) | **930** (841-968) | **1,268** (1,264-1,450) | **1,108** (1,088-1,257) | **1,418** (1,296-1,448) | **1,258** (1,238-1,309) |
| Julia's start | 197 | 195 | 224 | 346 | 230 | 327 | 324 | 232 | 344 | 325 |
| the load (phase) | 215 | 111 | 534 | 268 | 522 | 250 | 510 | 432 | 625 | 504 |
| the first run (phase) | 65.5 | 65.2 | 375 | 378 | 306 | 125 | 172 | 174 | 135 | 127 |
| the second run | 0.5 | 0.5 | 2.0 | 0.7 | 2.7 | 0.5 | 9.6 | 10.5 | 29.8 | 29.6 |
| code generation | 91 | 91 | 152 | 140 | 264 | 75 | 81 | 73 | 92 | 82 |
| inference; compiling while inferring | 15 | 15 | 238 | 242 | 57 | 48 | 64 | 58 | 20 | 19 |
| load: the rest (files) | 38 | 36 | 155 | 101 | 128 | 105 | 232 | 229 | 254 | 259 |
| load: the images' restore | 49 | 11 | 61 | 45 | 65 | 47 | 66 | 49 | 96 | 55 |
| load: the edges' validation | 42 | 8 | 52 | 28 | 59 | 37 | 53 | 42 | 84 | 46 |
| load: methods' insertion | 14 | 11 | 43 | 41 | 42 | 36 | 33 | 32 | 35 | 31 |
| load: the membership walk | 1 | — | 57 | — | 62 | — | 2 | — | 3 | — |
| load: the memberships' activation | — | — | 25 | — | 28 | — | 2 | — | 3 | — |
| load: the library's image hook (of it compiling) | 17 (14) | — | 52 (45) | — | 60 (47) | — | 15 (12) | — | 21 (14) | — |
| the definition-time check (compiling) | 10 (9) | — | 10 (9) | — | 11 (10) | — | 15 (12) | — | 14 (11) | — |
| load: `__init__` | — | — | 3 | 3 | 3 | 2 | 49 | 58 | 47 | 59 |
| garbage collection | — | — | 48 | 38 | 33 | 18 | 20 | 21 | 17 | 21 |
| dispatch, member check | 1 | — | 3 | — | 8 | — | — | — | 2 | — |
| the work itself | 1 | 1 | 5 | 2 | 4 | 2 | 56 | 52 | 97 | 85 |
| the harness; exit | 197; 20 | 198; 19 | 212; 22 | 216; 21 | 210; 24 | 207; 23 | 199; 58 | 205; 59 | 220; 62 | 212; 60 |

- **Where the port is slower, the load pays; the first run does not.** The first run equals the twin's in the table (65.5 against 65.2 ms), the ODE (375 against 378), the plot (172 against 174) and the report (135 against 127). The load is slower by 104 ms (table), 266 ms (ODE), 78 ms (plot), 121 ms (report).
- **The ODE port's load, 534 against 268 ms, by part:** the membership walk 57, the library's image hook 52 (45 of it compiling), the memberships' activation 25, more images (restore +16, validation +24), the files of six more packages +54 (ODECore, TraitRodas, TraitNonlinearSolve, TraitIndexing, TraitArrayTools, the library), the definition-time check 10, the collector +10. With the library loaded first E-531 measured 313 ms on TraitWorld 57879c3; here the library loads inside the program's `using`.
- **What a load compiles** (`llvm-*.md`, code generation by phase): every program, port and twin alike, generates machine code for `@static` (27 ms) and `(@main)` (12 ms): the system image holds their inferred code and no machine code (PE-32's pattern; the same on vanilla, `logs/probe-macro-compile.txt`: 32.8 and 12.6 ms on the head, 32.1 and 12.3 on vanilla). The trait programs' loads add `getindex(::SimpleVector, ::UnitRange{Int})` (8.5 ms) and `iterate(::Enumerate{Vector{Symbol}})` (9 ms), PE-32's instances, reached by the library's hooks; the ODE port's load adds `indexed_iterate` at `Tuple{typeof(DataType), UnionAll, TraitWorld.How}` and `Tuple{UnionAll, UnionAll, TraitWorld.How}` (4 instances, 13 ms) and `setindex!(::IdDict{Any,Vector{Any}}, ::Any, ::Any)` compiled again (6.5 ms).
- **The ODE program with callbacks: the first run 306 against 125 ms.** What the port's session compiles that the twin's does not (`top-odecb-H.md`): ODECore's callback machinery at the session's types, all of it ODECore's types with Julia's: `step_event_initialize!(::ParamEvent{Vector{Float64},Float64,Vector{Float64}}, …, ::Dynamic{StepView…})` 24.7 ms, `push!(::Vector{StepCallback{…}}, ::ParamCallback{…})` 19.5, `push!(::Vector{StepEvent{…}}, ::ParamEvent{…})` 19.0, `event_affect_dir!` 11.4, `event_time` 6.8, the records' constructors at the session's functions 11.5 and 11.6. The census: 55 instances of the "own image" class inferred in the session (20 ms inference, 109 ms code generation), 2 more whose inferred code the image held without machine code (22 ms). 20 of them name a box or `Callable`, 32 are Base's methods at ODECore's types (external code).
- **The ODE program's first run** (`top-ode-H.md`): `main` 195 ms (the session's), the Jacobian's right-hand side at duals (`PartialFn{typeof(robertson!)}` at `Dual{ODETag,Float64,8}`, 80.6 ms), ForwardDiff's generator (`tupexpr`, its body `##49#50`, and `+(::Partials{8,Float64}, ::Partials{8,Float64})` inferred in the session: about 95 ms; PE-27's pattern, absent in PlainODE's session, which uses chunk 3). The port's first run still equals the twin's: PlainODE compiles its own `main` larger (378 ms in `main` alone).

**NetworkDynamics' workload on the head** (`split-nd.md`; one phase; 2 unprofiled sessions, 42.3 and 42.5 s; one profiled, 42,681 samples; no plain run: upstream's packages are not in the depot offline, W-159's E-514):

| part | ms | part | ms |
|---|---|---|---|
| wall | **42,395** | garbage collection | 966 |
| Julia's start | 343 | the work itself | 870 |
| code generation | 27,030 | the box's checks (at run time) | 379 |
| inference | 6,612 | the member check, compiling | 233 |
| compiling while inferring | 2,335 | lookup's slow path | 223 |
| load: the rest (files) | 1,130 | load: the walk, the memberships, the image hook | 192 |
| load: methods' insertion | 672 | load: `__init__` (compiling 81) | 158 |
| load: restore, validation | 841 | the harness; exit | 188; 100 |

- By pass (its own `T` lines, two sessions): first 19.5, 19.3 s (compiling 19.1, 19.0); graphtype 7.9 s; changed 0.71, 0.66 s; params 0.61, 0.50 s; **again (the steady state) 313 and 423 ms** (E-514: 312-313).
- The compiles (`top-nd-H.md`, 958 dispatched, 37.5 s): composition 506 compiles, 30.3 s (the session's networks of NetworkDynamics', Graphs' and the solvers' types); own image 232, 4.9 s; recompile 28, 0.73 s. The largest: the workload's closures at the network (2.8 s, 1.2 s), `NetworkDynamics.extend_knowns_by_formulas!`'s body at `Dict{Symbol,Symbol}`, `Set{Symbol}`, `IOStream` (1.58 s inclusive; NetworkDynamics' own types with Julia's), `getindex(::NWState…)` (1.17 s), `normalize_valuedict` at `Dict{Symbol,Symbol}` (0.55 s, its own types).
- **The box's checks at run time, 379 ms** (0.9 % of the samples): `Compiler.declared_field_in` and `declared_field_type` under the box's `getproperty` (`TraitWorld._dynamic_field_type`), which folds only where the field's name is a constant; here it is called at run time.

### What is dispatched at run time (the head's dispatch profiler, whole process)

In every session most dynamic calls are the Compiler's own (`simple_dce!` → `maybe_erase_unused!` 16,717 in the ODE session, `widenconst`, `doworkloop`): inference dispatches dynamically. The trait code's own: the ODE port's right-hand side through its box, 12,222 calls to `_checked_result` and as many to `PartialFn` (2 dynamic calls per evaluation; at E-513's 25 ns, 0.6 ms in the session); the library's image hook, `_check_membership_calls` (implement.jl 400-402), 4,323 calls each to `getproperty`, `unwrap_unionall`, `isempty`, `getindex`, `!` at values typed `Any`. `TraitWorld.bare` 1,793 (table), 3,326 (report).

### The candidates (largest saving first within each class)

**(a) Follows from a rule; little code.**

| candidate | sessions | what it saves | the rule | size | known |
|---|---|---|---|---|---|
| A1. The box's field read at run time cached per (trait instance, field): `_dynamic_field_type(X, s)` answered from a table filled at the first read | NetworkDynamics (379 ms of the session, bounded by the profile's share; the steady state's part not separated) | at most 0.38 s of 42.4 s, measured as a share | a declared field's type is fixed once the trait is declared (traits §4.3, compiler §7.1; the function is `:foldable` for that reason) | about 10 lines in `TraitWorld/src/dynamic.jl` | W-167's README names the call; no open issue |
| A2. The library's hooks reach no instance the system image holds without machine code, and their records are typed (a struct for the (type, set, how) triples in place of a tuple of `typeof(DataType)`, `UnionAll`, `How`) | every trait program's load: table, plot, report about 17 ms; the ODE ports about 30 ms | 17-30 ms a load (the instances' code generation, measured by the dump) | the porting guide's 0.1 as the library applies it to itself (W-167): a loop over a value typed `Any` written in the library's own code; compiler §10.1 (the hook runs once per image) | about 20 lines in the library | PE-32 (the pattern); open issue 255 (b) for the rest of the hook |
| A3. The membership walk skips its search for code at a member whose type is new with the image | the ODE port (57-62 ms of its load), the forks (28), the table, plot, report (1-3) | at most 35 ms of the ODE load (65 of the 113 memberships are of new types, E-531), bounded | facts §2.2 (a membership of a type new with the load ends no code compiled before it); compiler §5.5 | small, in `src/gf.c` | open issue 255 (a); GT-9 |
| A4. The definition-time check's own instances held by the library's image | every trait program: 9-12 ms compiling at load | about 10 ms a session | traits §11.2, compiler §6.7 | the library's workload | GT-12 (a) |

**(b) Julia's own; would stand upstream without traits.**

| candidate | sessions | what it costs | size | known |
|---|---|---|---|---|
| B1. A load's file work: each candidate cache file opened and its header read, every source file of a package `stat`ed, the `.ji` checksummed (`stat`, `isvalid_cache_header`, `ispath`, `open`, `readbytes_all!`, `unsafe_crc32c` under `require`) | every session: 36-38 ms (table), 101-155 (ODE), 229-259 (plot, report), 2.13-2.16 s of the frames sessions' 6.3 s of loads; the same on vanilla (2,154 ms) | 10 to 45 % of every load; it grows with the number of cache files in the depot stack | Julia's loading (`base/loading.jl`) | — |
| B2. Machine code for instances the system image holds inferred only: `@static` 27 ms, `(@main)` 12 ms in every program; `getindex(::SimpleVector, ::UnitRange)`, `iterate(::Enumerate{Vector{Symbol}})` 17 ms in every trait program | every program; vanilla the same (`probe-macro-compile.txt`) | 40-57 ms a session | the system image's build | PE-32 |
| B3. Plain code compiled again after unrelated loads | frames, plain: 5.2-5.4 s | the design's problem, not a candidate: by facts 1.46 s | — | G-1 |
| B4. The edges' validation and the images' restore | every load; the same on vanilla | 1.3-1.4 s each in the frames sessions | — | E-185 |

**(c) A port's or the library's own code.**

| candidate | sessions | what it saves | size | known |
|---|---|---|---|---|
| C1. ODECore's callback machinery at `Vector{Float64}` held by the port's image: the program's form (a callback given to the problem, a tuple of callbacks to `solve`) in the workload, then open issue 228's question (why an instance the workload reaches past a dispatch at run time is missing) | ODE with callbacks: the first run 306 against the twin's 125 ms | up to 180 ms of the first run (129 ms of the census's own-image instances) | a workload line; 228's rule if that is not enough | open issue 228 |
| C2. PrettyTables compiled by facts (one line per module, the porting guide 0.1) in the facts environment and the forks | the work after the nine loads: by facts 1.46 s, the forks 2.27 s | 0.92 s of each (PrettyTables' printing, ended by the loads); the port following the design | one line per module of PrettyTables | — |
| C3. `CSV._parse` compiled again after the loads (SparseArrays' `vcat` at `vcat(::Int64, ::Vector{Int64})`) | by facts 0.39 s, the forks 0.64 s | 0.4-0.6 s | upstream's remedy: SparseArrays' methods for sparse arguments only | GT-8, PE-5 |
| C4. NetworkDynamics' `extend_knowns_by_formulas!` and `normalize_valuedict` at its own types in its image (a workload line) | NetworkDynamics' first pass | up to 2.1 s (inclusive trace times; what is shared with other compiles is not separated) | a workload line | — |

**(d) Not candidates.** The work itself; the session's own code (`main`, the right-hand sides, the workload's closures: 314 ms of the ODE session's compiles, 3.2 s inference and 3.1 s code generation of NetworkDynamics' session-class instances); the compositions of NetworkDynamics' session (30.3 s of compiles at the session's networks: a cache across sessions could hold them, no image can). The Compiler's instances ended at a load (GT-3's count): not compiled again in any session measured.

## Trust: what is measured how, and what is not

- **The profiler changed the loads when the Profile standard library was loaded before the session.** The first profiled runs on the head (`frames-up` H 355 s, `frames-facts` 192 s, `frames-forks` 257 s against 17, 11, 11 s unprofiled; `logs/run-r1.log`) precompiled packages inside the timed loads: CairoMakie's and Makie's images were rejected and written anew (their `.so` files' times, 16:13, 16:18, 16:23; a precompile killed in one of them left the pidfiles whose warnings `frames-facts-H-prof-1.out` printed). NetworkDynamics' images, which depend on them, were then stale, and its first unprofiled run precompiled them (that run is superseded, `logs/r1/superseded/`). `probes/profiled_load.jl` does not reproduce it on `using CSV, DataFrames` alone (`logs/probe-profiled-load.txt`), so which image the order of loading made unacceptable is not known. Since then the profiler is driven without the standard library, every run fails if a `.so` is written during it, and every run of the frames sessions was made again on the images as they are now (`chainD.sh`). The profiled runs used in the tables load at their unprofiled times (the frames sessions 1.1-1.3 s for `using CSV, DataFrames`).
- **The ODE port's load sleeps under the profiler.** Profiled, `include` of the ODE programs takes 2.8-3.8 s of wall time with 532-605 running samples (`ode-H-prof-{1,2}.out`, `odecb-H-prof-1.out`); unprofiled it takes 522-534 ms, and PlainODE's load is 340-350 ms profiled. The running samples match the unprofiled time, and only they are classed, so the shares stand; what the process waits for under the profiler is not known.
- **Profiled shares, scaled.** The profiler slows a phase (NetworkDynamics' session 75.8 s profiled against 41.8 s), so a class's time is its share of the profiled phase times the unprofiled median. Where a phase has few samples the shares are coarse: the table's first run has 50 samples, the table's whole session 293; a class under 10 ms there is a few samples.
- **Julia's start varies by 150 ms between runs** (189 to 363 ms with no other difference; the file system of a shared host). The walls of a port and its twin differ by less than that in the ODE sessions; compare the phases.
- **The harness's own time** (about 200 ms: its first printing, its driver's compile, Julia's first top-level work in a script) is outside every phase and stated apart. `--trace-compile` compiles code to print the signatures (`show` of tuples of symbols); `tools/top.py` leaves out what it can tell to be the harness's, and the "julia" class still holds the harness's printing (60-100 ms).
- **The census's "inferred in the session"** is "outside every image" (`jl_object_in_image`); its times are each instance's own (`time_infer_self`, `time_compile`, Float16); the trace's times are inclusive. The two are not summed.
- **The dispatch profiler** counts the whole process, inference's dynamic calls included; it gives counts, not times.
- **Not measured:** NetworkDynamics' plain run (upstream's packages are missing offline, as for E-514); a profile of each of NetworkDynamics' passes (one phase); the steady state (E-537, `stiff/`); strict mode; the ODE port's load with the library loaded first (E-531 has it); the savings of A1 to A4 and C1 to C4 (bounded or read from shares, none built); which method ends `setindex!(::IdDict{Any,Vector{Any}}, ::Any, ::Any)` at the ODE port's load.
