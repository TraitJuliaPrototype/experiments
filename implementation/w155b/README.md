# W-155, continued: D-9, D-11, D-12, D-13 (the third wave)

The plan's rows D-11 (a membership adds no type equality), D-12 (a pirate reported by default), D-9 (owner-only functions) and D-13 (a membership taken back), built in `julia-s3` (branch `next-s3`, from `next` 9b6dacf5c5) with the library in `TraitWorld-s3` (branch `s3`, from `unified` bb4ad00). Registry: E-431, E-456 to E-459 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md` §1, "The third wave on `next-s3`". The agent's session note: `session-notes/2026-11-15-agent-w155b.md`.

## How to run

```
source env.sh        # the workspace's env.sh, a depot of this agent's own in front of the shared one, $JS, $CSVFILE, $LOADS
$JS --project=env_lib gate_d11.jl                         # E-456: D-11's gate, the unions inside a parameter
bash suites.sh julia-s3 <label> [tests library digests gate]   # Base's core, subtype, Compiler/inline,
                                                          # Compiler/inference; the library's suite; the forks' digests
bash owner_only/run.sh <label>                            # E-431: precompile the three environments, then the census
$JS --project=<env> diag/why_not_deep.jl [csv] <pkg>...   # open issue 211's tool: why each instance is outside the class
SITES_ROOTS=CSV,DataFrames,Tables $JS --project=env_forks sites2.jl CSV DataFrames   # E-458 (a): run-time sites by callee
bash diag/roots.sh [julia tree]                           # open issue 189's tool: globals the collector does not see
$JS --project=env_forks loads.jl $CSVFILE $LOADS          # E-457: the nine loads, the deep endings and the reports
bash chain_b.sh; bash chain_c.sh                          # the checks after D-9 and after D-13, one after another
```

- **Environments.** Copies, so that no gate loads a tree another agent changes. `env_forks`, `env_facts`, `env_session` are W-155's (`../w155/`), the library at `TraitWorld-s3`. `env_demo` is W-134's (`../w134/env_demo`): the library at `TraitWorld-s3`, the ODE packages at `TraitDifferentialEquations-s3`, a detached worktree of `TraitDifferentialEquations` at the tag `prototype-2026-11` (b730628); TraitCSV, TraitTables, TraitMakie from their `-unified` trees. `env_lib` is W-134's, the library at `TraitWorld-s3`.
- **The depot.** `.julia-depot/agent-depots/w155b` in front of the shared depot: every rebuild of `julia-s3` precompiles the environments again there.
- **`owner_only/census.jl`** (E-431): every method whose function belongs to another owner, who names the definer no joint owner, and is neither exported nor `public` there; by the function's module: (a) declares `facts`, (b) a package's module that does not, (c) Julia's own. For (a) and (b): whether the owner's own code compiled by facts calls the function, and whether code compiled by facts relies on the method.
- **`diag/why_not_deep.jl`** (open issue 211): every valid instance outside the deep class, by the first edge that keeps it out. The reason "membership" counts the pattern: an edge kind the class allows that the predicate tests as a callee.
- **`sites2.jl`** (E-458): the run-time sites of a package's code compiled by facts, by who owns the function called. It reads each call's inference info: a call with no match recorded (`NoCallInfo`) is a run-time site; a dynamic call with matches and edges is a fact dispatched when it runs (several methods). `w152/p5/sites.jl` (E-396) counts both as dynamic calls. `diag/residue.jl`: the argument types and info of an owner-only call left to run time.
- **`diag/roots.sh`** (open issue 189's pattern): each global of the trait code annotated `JL_GLOBALLY_ROOTED`, which the stock collector does not read, that no root list names.
- **`diag/older_world.jl`** (E-459): a task in an older world after a membership is taken back; which method a call selects there and in the latest world.
- **Log headers.** The `b-*` logs' headers name `1dc4c7b3ae` where the binary was e483299622 (the header read the tree's commit while D-13's build had not finished); `b-summary.log`'s first line names the binary.

## Results

### E-456 (2026-11-15): D-11's gate

`next-s3` e967266d9e against the baseline 9b6dacf5c5; TraitWorld-s3 bb4ad00, forks 439bae7; product setting, strict mode off, one thread; load 4 to 6 of 128. `logs/e456-gate.log`, `logs/e456-gate-before.log`, `logs/d11-*`, `logs/base-*`.

| | the baseline | D-11 |
|---|---|---|
| `gate_d11.jl`: checks failed of 33 | 7 | 0 |
| Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` | pass (W-155's `final-*` logs, the same commit) | pass |
| the forks' digests | equal (W-155) | equal, 26 steps |
| the library's suite | fails 8 checks of `test/strict.jl` | the same 8 (open issue 211) |

- The first build left `<:` unchanged: a question asked afresh from inside the walk (`jl_subtype` in `local_forall_exists_subtype`, the tuple walk's separable elements, intersection's fast paths) dropped the walk's rule. Fixed in the commit (`subtype_fresh`).

### E-431 (2026-11-15): methods that extend another package's internal function

`next-s3` e967266d9e (the count does not depend on D-9); TraitWorld-s3 bb4ad00, forks 439bae7, the ODE packages b730628, TraitMakie c862914; after the loads (and the CSV work in `env_forks`, `env_facts`); load 6 to 8 of 128. `logs/e431-census.log`.

| | the forks and the loads | upstream by facts and the loads | the trait demonstrators, the ODE packages and the loads |
|---|---|---|---|
| methods of packages | 55,711 | 54,876 | 52,595 |
| (a) the function's module declares `facts` | 0 | 86: CSV → Tables 53, DataFrames → Tables 27, StructArrays → Tables 6 | 12: TraitMakie → TraitWorld 8 (`_fwd`, `_like`), TraitRodas → ODECore 4 (`step_*!`) |
| (a): the owner's facts code calls the function; facts code relies on the method | — | 71; 15 | 1; 1 |
| (b) a package's internal function, its module without `facts` | 479 | 394 | 369 |
| (c) Julia's internal functions | 3,951 | 3,843 | 3,595 |

- The forks' modules that CSV and DataFrames extend (`Tables` itself) do not declare `facts`: their 79 methods are in (b).
- Upstream by facts is the path's first step: one line per module. Under a default for every module that declares `facts`, the Tables interface that CSV, DataFrames and StructArrays extend (`istable`, `getcolumn`, …; 71 of the 86 methods are of functions Tables' own facts code calls) would be owner-only, and those methods pirates.
- TraitMakie's 8 are methods the library's lowering generates in the member's module (forwarding, `like`) at the library's own internal functions; TraitWorld declares `facts` by `@compiler_options`, not as a trait module.

### E-458 (2026-11-15): D-9's gate

`next-s3` e483299622; TraitWorld-s3 4210852 (4f34916 for the library's suite), forks 439bae7, TraitMakie `unified` d905a0b, the ODE packages b730628 with `logs/ode-public.diff` (open issue 212); product setting, strict mode off, one thread; load 3 to 7 of 128. `logs/b-*`, `logs/e458-*`.

| | count |
|---|---|
| (a) the forks: dynamic calls in code compiled by facts / run-time sites (no match recorded) / facts dispatched when they run | 8,966 / 8,128 / 838 |
| (a) the forks' run-time sites at an owner-only function | 134: 74 where more methods match than `max_methods`, 60 where the tool finds at most three |
| (a) the trait demonstrators: dynamic calls / run-time sites / at an owner-only function | 155 / 136 / 0 (E-396: 33 at the own internal functions) |
| (a) the ODE packages: dynamic calls / run-time sites / at an owner-only function | 472 / 407 / 26 (E-396: 116) |
| (a) the old tool on the same build, the forks' "own function, not public" | 932 (E-396: 678): it counts the facts dispatched when they run |
| (b) a later `public` or `export` ends the code that relied on the status | fails: nothing ends (compiler C-130) |
| (c) TraitMakie's suite, its eleven asserted barriers removed | passes, 79 checks (`logs/e458-traitmakie.log`) |
| (d) the library's `test/owner_only.jl` | 22 of 22 |
| (e) the census again, the demonstrators' (a) | 8, all at TraitWorld, no trait module: none owner-only |
| (f) Julia's four tests; the forks' digests; the library's suite | pass; equal, 26 steps; pass |

- TraitRodas failed to precompile: its four methods of ODECore's internal step interface are a pirate's under D-9, and TraitRodas declares `no_pirates` (open issue 212). With ODECore's `public` line (`logs/ode-public.diff`, the gate's worktree only) it loads.

### Open issue 189 (2026-11-15): the segfault in the membership walk

- The membership dispatch walk held the member's substituted signature in a local the collector did not see, across an allocation; fixed on `next-s3` c31fce89d7, with `activation_ambiguities`, a global annotated `JL_GLOBALLY_ROOTED` and unrooted.
- `diag/roots.sh` (`logs/roots.log`): before the fix 1 global unrooted (`activation_ambiguities`), after it 0 (`jl_implements_ft` is reachable from Core's constant binding).

### E-459 (2026-11-15): D-13's gate

`next-s3` 213c759370 (D-13 amended), TraitWorld-s3 9e0e3f4, forks 439bae7; product setting, strict mode off, one thread; load 5 to 7 of 128. `logs/c-*`, `logs/e459-older-world.log`, `logs/visibility.log`.

- **The library's `test/delete.jl`: 27 of 27.** From the next world `Circ` is no `DShape`; the folded positive (`isa` compiled before) ended; a call that selected a method at the trait selects anew (`describe` gives "other"); the default no longer applies (`MethodError`); a call that reached `Circ`'s own method keeps its code; `Circ` leaves the candidates; a task in the older world keeps the membership and its selections; a member by its definition, `Dynamic{DShape}`'s and a missing membership refused; declared again, checked anew; by a third module, refused in strict mode where deep code relies on it, warned otherwise.
- **The first run, before the fix in the commit (the build 1dc4c7b3ae, not kept): 26 of 27.** A task in the older world took the new selection ("other"). `diag/older_world.jl`: whichever world asked first cached its selection for both. The pattern: a change of an entry's worlds that does not raise the runtime's latest change (`jl_membership_changed`); a match's range at a query in a later world is taken without a walk, so it spans the change. Fixed in the amended commit (`jl_membership_changed(world + 1)`). `diag/visibility.sh` lists every function that changes an entry's worlds: 1 that does not raise the change before the fix (`jl_delete_membership`), 0 after (`logs/visibility.log`).- **The suites** (`logs/c-summary.log`): the library's suite passes (`test/delete.jl` with it); Julia's `core`, `subtype`, `Compiler/inline`, `Compiler/inference` pass; the environments' images made again (the demonstrators' with `logs/ode-public.diff`); the forks' digests equal upstream's at 26 steps. The binaries report `1dc4c7b3ae*`: the tree of 213c759370 before the amend.
- **Not gated:** an image written after a membership is taken back (the writer skips an entry not in force); Revise, which is not in the depot (lowering L-64).

### E-457 (2026-11-15): D-12's gate

TraitWorld-s3 2770c10 (the library's case), 9e0e3f4 (the loads); forks 439bae7; product setting, strict mode off, one thread. `logs/b-loads.log` (e483299622, 2 runs each, load 3.7 to 6.1), `logs/c-loads.log` (213c759370, 4 runs each, alternating, load 3.2 to 4.0).

- **(a) The library's `test/report.jl`: 21 of 21.** A pirate that ends deep code is reported with its method, definer and the code ended; a pirate that ends no deep code, and a stakeholder's method that does, are not; `report_pirates!(false)` silences it.
- **(b) The nine unrelated loads after the forks' work end 0 deep instances, and 0 reports,** on both builds.
- **(c) The loads' time, the runtime's list off (as before D-12) against on with the report:**

| build | off | on |
|---|---|---|
| e483299622 (2 runs each) | 5.25, 5.23 s | 5.53, 5.37 s |
| 213c759370 (4 runs each) | 5.82, 5.58, 5.47, 5.46 s (mean 5.58) | 5.81, 5.79, 5.38, 5.45 s (mean 5.61) |

- The difference, 0.03 s of 5.6 on the second build, is within the spread of a run (0.4 s). Nothing measurable, as the rule needs: the list is filled only where deep code ends.

### Open issue 211 (2026-11-15): the tool's counts

`diag/why_not_deep.jl` on 213c759370 (`logs/c-why-*.log`): the forks' session after the CSV work, 116,323 valid instances, 77,528 with the bit; 481 hold a positive membership's edge; none is kept out of the class by that edge alone (the pattern: 0). The library alone: 69,670 instances, none with such an edge. The `b-why-forks.log` line "membership" (177) came from the tool before its fix, which took the edge for the reason wherever it came first.

