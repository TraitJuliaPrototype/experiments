# W-158, first part: the ODE program's own errors in a trimmed build (E-510)

**The question** (registry row E-510): which rule of compiler §7.6 should serve the call
`_problem_of(f::Dynamic{Callable{…}}, getfield(f, :object)::Callable{…}, …)` (ODECore `frontend.jl` 69), a call at
a value known only by its trait (the box's object) that two methods take, the member's type choosing; once it is
served, does the ODE program (`../w135/apps/ode.jl`, no callbacks) build with only plain Julia's hole in a JLL's
`__init__` left? And that hole (`unique!` → `issorted` with keywords): why, and the smallest patch. What would change
the design: a call the closed rules cannot serve without a rule beyond §7.6's one input, or a session that pays.

## How to run

```sh
source experiments/implementation/w158/env.sh       # the workspace's env.sh, a depot of this work's own, $JN, $W156
cd experiments/implementation/w158
(cd $TW_ROOT/TraitWorld && [PATCH=1] $JN --project=. $W158/probes/choice.jl)      # the rule, the build's check in a session
[PATCH=1] $JN --project=$W156/env_demo probes/ode_check.jl                        # the ODE program's main, the same check
bash build_app.sh <tree> apps/choice.jl <name> $TW_ROOT/TraitWorld               # the small program, trimmed
bash build_app.sh <tree> apps/uniq.jl <name>                                     # plain Julia's hole, without a JLL
DEPOT=$TW_ROOT/.julia-depot/agent-depots/w158 JULIA_TREE=<tree> VERIFY=1 NAME=w158-<name> bash ../w166/build_c.sh ode
python3 ../w135/summarize.py <log>
bash small.sh <label> <tree>; TREE=<tree> bash sessions.sh <tag> 3
```

- `PATCH=1` lays the worktree's compiler change (`wt/w158-julia`) over the session's (`../w156/tools/cc_patch.jl`):
  the build's check run in a session reads the same closed rules.
- `build_app.sh`, `small.sh`, `sessions.sh`: W-166's, with this directory's depot and logs.
- `../w166/build_c.sh` writes its logs to `../w166/logs/w166c-<NAME>.*`; the logs cited here are copied to `logs/`.
- Builds run with `ulimit -c 0`.

## Results, 2026-11-20

Julia `wt/w158-julia` (branch `w158`: d661fb9eb7 the rule, 61277571fa the `issorted` patch, on `next` f5328f94c5);
control `julia-next` f5328f94c5; plain Julia `julia-vanilla` 45b6d15e34 (v1.13.2). TraitWorld `w158` 1f3567e (a test
only; `unified` 9d4f782 otherwise); TraitDifferentialEquations `unified` 3e60c29; the demonstrators of `../w156/env_demo`.
`--trim=safe`, `VERIFY=1`, one thread, one Julia job at a time; load 3 to 35 of 128.

**The diagnosis.**
- `_problem_of` has two methods: `(k, f, …)` and `(k, f::ODEFunction, …)`; `ODEFunction{F,TJ,TMM}` is a member of every
  `Callable` instance by its pattern. At `f::Callable{…}` (the box's object) both match. Julia's inliner splits a call
  over its matched methods by a type test where each narrowed type is a set or concrete (`probes/choice.jl`: `describe8`
  at a trait, `kind8` at `Ci8` resolve on julia-next), but `ODEFunction` narrows to a family with free parameters: its
  instance is abstract, the call is left to dispatch and its result is the join `ODEProblem{Float64, Vector{Float64}, _A, _B}`.
- The members by use at that instance (the build's report, `logs/w166c-w158-ode-head-report.build.log`): `lorenz!`,
  `robertson!` forgotten at `Callable{Tuple{Vector{Float64}, Vector{Float64}, Vector{Float64}, Float64}, Nothing}`; no
  `ODEFunction`. `Callable` as a whole: 8 (`isless`, `identity`, `temp_cleanup_atexit`, the two, three getters of TraitIndexing).
- No rule of compiler §7.6 serves it: "any other call … runs the method's instance" names one method. Traits §7.4: a
  function outside the contract with a method at the object's own type is reached "by one dispatch for a box"; a
  session compiles that dispatch's target per object type. The build's counterpart is the split over the members.
- Branching over the methods (once per set instance) does not serve this call: the `ODEFunction` branch's instance is
  at a family with free parameters (its field reads are `Any`), and the generic branch's body asks the object
  questions outside the contract (`_mass_matrix(x)`: `hasproperty`, `getproperty`, `_is_identity(::Any)`).

**The rule built** (d661fb9eb7, `Compiler/src/abstractinterpretation.jl`, 39 lines added, 3 removed): in a closed build,
a call at an argument typed by a set instance where a matched method is at a type that is no set (a struct, a family;
not a kept form) is split by `closed_member_split` over the set's members, each branch the call at the member's type,
past them `MethodError` (`closed_choice_bits`). A method at a subtrait or an intersection stays Julia's split at the set
instance. Only `closed_build(interp)` reads it.

| | julia-next | w158 |
|---|---|---|
| `apps/choice.jl` (three members; a method at a trait, a type, a family), `--trim=safe` | 6 errors (`logs/w158-choice-julia-next.build.log`) | 0, 2,179,000 bytes, runs, output equal to the session's (`logs/choice-session-julia-next.out`) |
| the library's test "the member's type chooses the method" | 2 of 4 fail (`logs/verify-julia-next.log`) | 4 pass (`logs/library-w158.log`) |
| `apps/uniq.jl` (plain: `unique!` of a `Vector{String}`) | 12 (vanilla 12: `logs/w158-uniq-julia-vanilla.build.log`) | 0, 1,882,160 bytes, runs, equal |
| the ODE program | 12: 6 JLL, 6 own (`logs/w166c-w158-ode-head-report.build.log`) | 88, all its own; `_problem_of` resolved (`logs/w166c-w158-ode.build.log`) |
| its plain twin (`ODE_PLAIN=1`) | 14: 6 JLL, 8 own (`../w166/logs/w166c-ode_plain-head.build.log`) | 8 (`logs/w166c-w158-ode_plain.build.log`) |
| the ODE program's `verify_main` in the build's process | 3 sites, 5.4 s | 3 sites, 188 s |
| the table program | 0 errors | 0, 2,725,840 bytes, output equal to the tag's (`logs/table-bin-w158.out`) |

- **The ODE program on w158.** The build splits `_problem_of` over `Callable`'s 11 members (2 rounds); each branch
  returns `ODEProblem{Float64, Vector{Float64}, Dynamic{All{…}}, typeof(core_no_jacobian)}`, so the `solve` calls compile.
  The 88 errors are the code they reach, all the program's own: the step and event callbacks (`StepEvent`,
  `StepCallback`: sets with no member in this program; 42), the callbacks' constructors at `Callable`-bounded variables
  and their `hasmethod` test (16), the split's box branch (`_problem_of(k, f::Dynamic{…})`: `_mass_matrix` reads the
  box's declared fields; 14 with the contract's closure), `_plain_function(f::Any, p)` (`@nospecialize`, compiled at
  `Any`; 4), a call of the box's object at an intersection (4), Rodas5's `_rodas5_run`, `rodas5_start`,
  `dual_jacobian` (6). Not each diagnosed.
- **The members by use at a `Callable` instance do not converge in the check run in a session** (`probes/ode_check.jl`
  with `PATCH=1` on julia-next; the same in the build's `verify_main`): 4, 15, 26, … 70 members over 7 rounds, past 64,
  so the split is not made. A family a callable type joins by its pattern (`PartialFn{F,P} where {F,P}`) is under every
  `Callable{A, S}`, so `PartialFn{M}`, forgotten at the join `PartialFn{F, Vector{Float64}} where F`, is a member of
  every instance, and the next round makes `PartialFn{PartialFn{M}}`. Counting only places whose type names a set
  (`/tmp` experiment, not kept) converges at 5 members but leaves 50 calls: the callbacks need the family places.
- Not done: the ODE binary (`--trim=unsafe-warn`), since errors of the program's own are left.

**Part B, the JLL hole.** `issorted(itr; lt = isless, by = identity, rev, order)` only passes `lt` and `by` on to `ord`;
Julia compiles a method at `Function` for an argument of a function type it does not call, so the keyword body runs at
`lt::Function, by::Function`, where `ord`, `_ord`, `Lt`, `By`, `ReverseOrdering` are not resolved. The same on vanilla
v1.13.2 (`apps/uniq.jl`: 12). `../w135/apps/jllhole.jl`'s entry point names `issorted(::Vector{String},
::ReverseOrdering{ForwardOrdering})`, which compiles; the errors are above it, in the keyword body. The patch
(61277571fa): `lt::L = isless, by::B = identity … where {L, B}`.

**Checks on w158.** The gates 72 of 72, 9 of 9 stage gates (`logs/gates.log`); Base's core, subtype, Compiler/inline,
Compiler/inference, sorting SUCCESS (`logs/base-summary.log`); the library 94 testsets (one new); TraitDifferentialEquations
35 testsets (`logs/tde-w158.log`); E-384's eight small programs build, run, output equal (`logs/w158-small.log`); the
sessions (`sessions.sh`, a warm-up and 3 runs, `logs/sessions-next.log`, `logs/sessions-w158.log`): instances equal;
table 19 compiles on both; report 25 on julia-next, 24 on w158 (`issorted(::Vector{String}, ::ReverseOrdering)` is in
the system image).
