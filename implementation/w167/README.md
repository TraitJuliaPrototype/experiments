# W-167: the library's own hooks are not lost at a port's load (open issue 254; then 255)

**The finding** (the round of 2026-11-22, E-515, E-516): the ODE port's, the forks', NetworkDynamics' and upstream CSV's
loads each ended 15 of TraitWorld's own instances. A dependency's method of `promote_rule` (ForwardDiff's, at
`Dual`) ended Base's `string(::Integer)`, below `string.(::Vector{Any})` in the library's `_written_method`, and the
hooks that reach it: the definition hook, strict mode's hook at a load, the module-end hook, the bounded check, the
names a message prints. They were compiled again in the session (0.13 s of the ODE port's load: the package callback
`_strict_at_load!`, with strict mode off), and the library loaded after plain work took 168 ms against 58 ms first.
The library is compiled by facts; its hooks rested on Base's plain code at types the code does not know, so they
were outside the deep class (compiler §3.2): GT-8's pattern in the library's own runtime.

**The rule the library now follows** (the porting guide's 0.1, applied to itself): a call at a value typed `Any` in
code compiled by facts is a run-time site and records no edge; the same call inside Base's plain code commits and
keeps its caller outside the class. So the library
- reaches the code that handles values of any type by its purpose through a run-time site by intent,
  `_runtime_site(f, args...)` (`src/runtime.jl`): every logging macro, Base's printing of a method, a type or a value
  in a message, Base's TOML reader, the compiler's interpreter constructor, `Base.specializations`, `copy` of a
  `CodeInfo`, the fully typed check called from its hook;
- writes its loops over `Vector{Any}`, a `SimpleVector` or an `IdDict{Any}` in its own code (Base's `any`, `all`,
  `findfirst`, `foreach`, `enumerate`, `zip`, filtered `collect`, a broadcast over them are plain code that commits
  at `Any`);
- types its stores (`Set{Module}`, `Set{Core.CodeInstance}` for `IdSet`s; typed lists beside its record stores for
  the walks over all of them; a store into `Dict{Symbol,Any}` of a value of a known type made at `Any`, `_setenv!`);
- gives `_winning_fact` one predicate type (`_NoStake`), so that no callee is named by its instance alone.

The library: TraitWorld branch `w167` (worktree `wt/w158g-tw`), commits eeac4ec (the hooks) and 57879c3 (a box's
field errors), from `unified` 42d60e1. Julia `next` cf0f039f51 (`julia-next`, read only).

## The tools

| File | What it does |
|---|---|
| `flags.jl` | the flags of a CodeInstance through the runtime's own definitions (open issue 257): facts by `Base.Compiler.ci_policy_facts`; G2 and FROM_IMAGE by their `#define` in the build's installed `julia.h` (the runtime has no reader of the G2 bit). It checks itself when included (a facts leaf, a run-time site and a caller of a plain callee outside the class) and stops the run if a reader does not discriminate. |
| `lib_ended.jl <Pkg>...` | the dynamic list: which of the library's instances a load ends, each with the plain callee it rests on (`via`), the library's outermost caller ended with it (`hook`), and the definition that ended it; the runtime's invalidation tree pruned to the branches that reach the library (indent = depth). `ENDED` counts from the caches (valid before, not after), not from the log. `LATE=1`: the packages first, then the library (E-515's late load): its image code rejected at load, from the Compiler's validation log. |
| `lib_static.jl [<Pkg>...]` | the static list: every instance of the library outside the deep class, with its own faults, its direct calls into code outside the class (`ENTRY`) and its culprits (W-157's census predicate, `../w157/census_lib.jl`). Each is put on the first path that reaches it through edges: `hook` (from the 11 hooks the runtime and Base call), `macro`, `site` (from a function passed to `_runtime_site`: allowed), `other`. `EXCEPTIONS`: `@trait`'s expansion (`_trait`, `_equation_value_method`), with the reason. `STATIC OK` when no instance outside the class is on a hook's, a macro's or another path, but the exceptions. `QUIET=1`: the summary only. |
| `../gates/n36_library_deep.jl` | the gate: `lib_static.jl` quiet, every hook in the class, nothing outside but behind a run-time site and the exceptions. |
| `run_lists.sh <label> <S>...` | both lists for a setting: the static list alone and after the ODE port's load; the dynamic list at the ODE port, the forks, NetworkDynamics, TraitMakie, TraitTables with TraitCSV, upstream CSV with DataFrames, and upstream with the library late. |
| `load_parts.jl <walk\|nowalk> <Pkg>...`, `run_parts.sh`, `run_parts2.sh` | open issue 255: a port's load in parts without a profiler: the image hook and each package callback timed through wrappers installed in their place, Julia's compile timer (and of it compiling again); `nowalk` (the walk invalidates nothing); `W167_LOG=1` with Julia's invalidation log on, as `w145/loads/load.jl` runs. `run_parts.sh` adds one profiled load per setting (`../w159/probes/load_profile.jl`). |
| `memb_count.jl <Pkg>...` | the memberships a load activates, by whether the member's type is new with the load. |
| `messages.sh <label> [<tree>]` | the messages' tool (`../w158/messages/`, unchanged) with its logs here. |
| `round/lib.sh`, `round/prepare.sh`, `round/rows/g4_plain.sh`, `round/rows/g4_loads.sh` | W-159's drivers with a setting of their own, **G** (the head with the library at `wt/w158g-tw`): environments under `envs/` (ignored by git), G's depot `.julia-depot/agent-depots/w167/G` stacked before the round's H depot (read only) and the shared one. H, B, V use the round's depots read only; preflight stops a row before a cell could write into them. |
| `jl.sh` | Julia as the tools here run it outside the drivers: depot `agent-depots/w167` (or `W167_DEPOT`), then the round's H depot read only, then the shared one; offline, niced, one thread. |

## How to run

```sh
cd experiments/implementation/w167
bash round/prepare.sh                          # G's images (after each change of the library: about 3.5 minutes)
bash run_lists.sh r2 H G                       # both lists, the freeze's library and W-167's (about 1.5 minutes)
bash round/rows/g4_plain.sh r1 3               # E-515's row, G and H interleaved with vanilla (about 3 minutes)
bash round/rows/g4_loads.sh r1 3               # E-516's rows traitworld ode forks nd, G and H (about 1 minute)
bash run_parts2.sh r2 3                        # open issue 255: the ODE port's load in parts, G, H, B
bash messages.sh w167                          # the messages' tool; the library's tests and the docs' examples in it
LIB=wt/w158g-tw ../gates/run_all.sh julia-next # the gates (with JULIA_DEPOT_PATH=agent-depots/w167:shared)
```

## Results, 2026-11-22

Builds: julia `next` cf0f039f51; **H** the freeze (TraitWorld `unified` 42d60e1, the round's depot); **G** TraitWorld
`w167` 57879c3 (the lists `r2`, the measurements) and eeac4ec (the first lists); the demonstrators and ports at the freeze
(TraitDifferentialEquations 06c28c3, TraitMakie 1888698, TraitTables e1ec1f4, TraitCSV 094dcb2, forks a3a37d6,
NetworkDynamics c2bbf0d); **B** the tag (the round's control). Product setting, strict mode off, one thread, a fresh
process per cell, niced; the machine 128 cores, its 1-minute load 2.8 to 5.8 (others' jobs, and W-168's rows).

### The dynamic list (`logs/lists-r2.log`, `logs/lists-r2-<S>-<load>.txt`): the library's instances a load ends

| load | H (freeze) | G (W-167) |
|---|---|---|
| the ODE port | **15** | **0** |
| the forks (CSV, DataFrames) | 15 | 0 |
| NetworkDynamics | 15 | 0 |
| TraitMakie | 0 | 0 |
| TraitTables with TraitCSV | 0 | 0 |
| upstream CSV with DataFrames | 15 | 0 |
| upstream, the library loaded after it (rejected at load) | 15 | 0 |

At H every one of the 15 hangs from ForwardDiff's (or another dependency's) method of `promote_rule` through
`string(::Integer)` and `Broadcast.materialize` of `string` over a `Vector{Any}` (`_written_method`), and
`sprint.(showerror, …)` (`_strict_at_load!`): the tree in `logs/lists-r2-H-ode.txt`, `logs/before-ended-ode-H.txt`.

### The static list (`logs/lists-r2-<S>-static.txt`, `static-after-ode.txt`): the library's instances outside the class

| | H (freeze) | G (W-167) |
|---|---|---|
| the library alone: instances, deep | 342, 248 | 362, 353 |
| hooks in the class | 1 of 11 | **11 of 11** |
| outside: on a hook's path, other, named exceptions | 50, 42, 2 | **0, 0, 2** |
| outside, behind a run-time site by intent (allowed) | 0 | 7 (the logging and message closures, `_env_binds`) |
| after the ODE port's load: instances, deep, outside | 599, 432, 165 | 632, 547, 76 |

- **The exceptions** (`lib_static.jl`, `EXCEPTIONS`): `_trait` and `_equation_value_method`, `@trait`'s expansion: it
  builds syntax from the user's expressions (values of any type), where the macro expands (a package's build, the
  prompt), never at a load or at a method's definition.
- **After the ODE port's load, 76 remain, all the box's runtime at the port's types, in the port's image** (not the
  library's image; no load of the list ends them; `n36` covers the library's image): `_callable_box_check` 26,
  `_callable_met` 21 and `_forward_box` 20 rest on `hasmethod` at a closure, which names the matched instance alone
  (open issue 219); `_dynamic_field_type` 4 and `getproperty` 4, `setproperty!` 1 of a box rest on
  `Compiler.declared_field_type` at a kind (introspection; it is `:foldable`, so a run-time site there would cost
  every field read of a box its fold). Not changed: a finding for open issue 254's text.

### E-515: plain code's session, the library first and late (`logs/g4-plain-r1.log`; a warm-up and 3 runs, interleaved V, G, H; load 4.5–5.8)

Median (range), n = 3. `w134/plain.jl`, upstream CSV and DataFrames compiled plainly.

| cell | `using CSV, DataFrames` (ms) | first work (s) | repeated (ms) | the library's load (ms) | ended by it | work after it (ms) |
|---|---|---|---|---|---|---|
| vanilla | 819 (657–822) | 3.29 (3.26–3.29) | 0.18 (0.17–0.18) | — | — | — |
| G, no library | 770 (764–778) | 3.39 (3.37–3.40) | 0.19 (0.19–0.19) | — | — | — |
| H, no library | 757 (756–780) | 3.38 (3.38–3.39) | 0.19 (0.19–0.19) | — | — | — |
| G, the library first | **785 (783–1041)** | 3.39 (3.39–3.40) | 0.18 (0.17–0.19) | 57.5 (56.7–85.9) | — | — |
| H, the library first | 1085 (1080–1104) | 3.34 (3.33–3.34) | 0.19 (0.18–0.19) | 60.4 (60.0–69.9) | — | — |
| G, the library late | 762 (757–764) | 3.39 (3.32–3.40) | 0.19 (0.18–0.19) | **32.8 (32.4–33.3)** | 0 of 120,780 | 1.07 (1.05–1.09) |
| H, the library late | 757 (751–762) | 3.38 (3.32–3.40) | 0.18 (0.18–0.19) | 171.3 (168.8–173.5) | 0 of 120,780 | 1.11 (1.06–1.13) |

- The library loaded late takes 32.8 ms, under its first load's 57.5 ms (the round: 168 against 58 at H). W-167's
  criterion is met.
- With the library loaded first, upstream's load takes 785 ms against 1,085 at H: the 300 ms were the library's
  hooks compiled again after CSV's and DataFrames' methods ended them. Against no library (770 ms) it adds 15 ms.
- The first work is within 0.05 s across G and H; G's is 0.10 s above vanilla's in this hour, as H's (open issue
  225, not this work).

### E-516: a port's load (`logs/g4-loads-r1.log`; `w145/loads/load.jl`, the library loaded inside the timed `using`; a warm-up and 3 runs, G and H the same hour; load 3.4–3.6)

| row | G (ms) | H (ms) | log G / H | the library's ended G / H | the round (H; B) |
|---|---|---|---|---|---|
| TraitWorld | 56.8 (56.2–57.1) | 61.8 (61.5–62.8) | 9 / 9 | 0 / 0 | 59.6; 61.6 |
| the ODE port | **388.3 (384.7–391.8)** | 515.7 (515.3–516.2) | 623 / 643 | 0 / 15 | 508.2; 300.6 |
| the forks | **934.8 (933.3–945.2)** | 1,212.7 (1,204.8–1,216.5) | 666 / 695 | 0 / 15 | 1,195.7; 1,146.2 |
| NetworkDynamics | **1,859.5 (1,845.5–1,871.1)** | 1,975.2 (1,973.6–1,978.9) | 1,545 / 1,574 | 0 / 15 | 1,968.4; 1,787.2 |

The tag's numbers are the round's (another hour); the tag was not run in this row.

### Open issue 255: what is left of the ODE port's load (`logs/parts-r2.log`, `logs/parts-r1.log`, `logs/parts-r1-profile-{G,H,B}.txt`, `logs/memb-count-ode-G.txt`)

`load_parts.jl`: the library loaded first, then `using TraitDifferentialEquations` timed. A warm-up and 3 runs, G, H, B
interleaved; load 2.8–3.0.

| | G (W-167) | H (freeze) | B (tag) |
|---|---|---|---|
| the load (ms), log off | **313.3 (312.2–313.9)** | 439.2 (438.3–443.2) | 249.5 (245.7–253.2) |
| the load, Julia's invalidation log on | 315.7 (313.3–316.3) | 439.5 (439.2–441.7) | 244.2 (243.9–247.4) |
| the library's image hook (23 images) | 47.9 | 41.0 | 16.5 |
| package callbacks (strict mode off) | 0.0 | `_strict_at_load!` 133.2–133.9 (its code compiled again) | `_strict_at_load!` 8.1 |
| compiling, of it again | 56.3, 14.0 | 183, 133 | 57.5, 0 |
| the walk's invalidation (`nowalk` against `walk`, r1) | 311.8–316.3 against 312.6–316.3: none measurable | | |

The profile at 1 ms (one load each; samples, inclusive):

| frame | G (331) | H (486) | B (365) |
|---|---|---|---|
| an image's restore (`jl_restore_package_image_from_file`) | 241 | 236 | 119 |
| the memberships' activation (`jl_memberships_activated`) | 86 | 88 | under 20 |
| of it the walk (`jl_membership_dispatch_walk`) | 57 | 65 | under 20 |
| the image hook (`_image_methods_hook`) | 60 | 53 | 29 |
| of it the check of the image's methods (`_check_membership_calls`) | 56 | 51 | 25 |
| the library's records brought up (`_sync_image_records!`, `_sync_image_checks!`) | 31, 31 | 38, 38 | under 20 |
| validation (`insert_backedges`) | 50 | 46 | 73 |
| methods' activation (`jl_activate_methods`) | 36 | 33 | 28 |
| compile (`jl_compile_method_internal_policy`) | 46 | 161 | 33 |
| package callbacks (`run_package_callbacks`) | under 20 | 140 | under 20 |

- With the hooks no longer compiled again, the ODE port's load (the library loaded first) is 313 ms against the tag's
  250 in the same hour: 64 ms above it, not 0.21 s.
- **What is left above the tag:** the image hook, 31 ms more (48 against 16.5), nearly all of it the check of the
  image's methods against the memberships in force and the library's records brought up to the activated
  memberships; the membership walk, about 57 of 331 samples, absent at the tag; less validation than at the tag
  (50 against 73 samples).
- **The walk:** compiler §5.5, a membership activated at a load walks for the code it ends, as a method's insertion
  does; 113 memberships activated by the ODE port's load, 65 of them of a type the load itself brings (ODECore 39,
  TraitNonlinearSolve 16, TraitRodas 5, TraitIndexing 4, TraitArrayTools 1), 48 of Core's types. A membership of a
  type new with the load can end no code compiled before it (facts §2.2, "What invalidates nothing"); the walk's
  search for code is spent there; only the dispatch caches need lowering. `nowalk` shows the invalidation itself
  costs nothing measurable; the search is the cost. The image cannot hold it (it searches the session).
- **The image hook:** compiler §10.1 (it runs once per image, with its methods for other modules' functions; both
  hooks first bring the library's records up), traits §5.10 (a member's check kept while it is a member). The check of
  an image's methods against memberships its build already had in force (its dependencies') repeats the build's; the
  records are made anew from the runtime's list at each load. Work an image could hold.
- Compiling again 14 ms at G: none of it the library's (0 ended); not attributed further.

### The checks

| Check | Result |
|---|---|
| the library's suite (`logs/suite-library-w167.log`, 57879c3) | 118 testsets pass |
| the docs' examples and the messages' tool (`logs/messages-w167-*.out`, `-scan.txt`) | intro, tutorial, strict, cases: exit 0; 157 distinct messages, tuple type 0, generated name 0, compiler object 0, library internal 0 (box or wrapper type 56, read); the same 144 messages as the freeze's library but for the random module names (`logs/messages-freeze-*`) |
| the gates (`logs/gates-w167.log`; `LIB=wt/w158g-tw`, load 3.2–3.4) | 75 of 75 (with `n36`), stage gates 9 of 9; `n36` fails on the freeze's library (`logs/gates-n36-freeze.log`) |
| the ODE port's, TraitTables', TraitMakie's suites with this library (`logs/suite-{tde,tables,makie}-w167.log`; `envs/G/demo`, G's depot) | 35, 3, 8 testsets pass |

## Not verified

- The tag's E-516 rows were not run in this hour (their numbers are the round's); the tag's ODE load in parts was.
- The static list covers the instances the library's image has and those after the ODE port's load; not the
  library's instances that a session compiles later (a REPL's definitions) nor those in TraitMakie's or the forks'
  images.
- strict mode on: not measured (the library's suite and the docs' strict example exercise it).
- `flags.jl` reads the G2 bit from `julia.h`, checked by its self-check; W-168's helper for open issue 257
  (`experiments/tools/`) was committed meanwhile and is not used here.
