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
35 testsets (`logs/tde-w158.log`); E-384's eight small programs build, run, output equal (`logs/w158-small.log`; build logs `logs/small/`); the
sessions (`sessions.sh`, a warm-up and 3 runs, `logs/sessions-next.log`, `logs/sessions-w158.log`): instances equal;
table 19 compiles on both; report 25 on julia-next, 24 on w158 (`issorted(::Vector{String}, ::ReverseOrdering)` is in
the system image).

## The main session's check of the report's and the plot's programs, 2026-11-20

Julia `wt/w158-julia` (`w158` 61277571fa), TraitWorld `w158` 1f3567e, TraitMakie `unified` 1888698, project
`../w156/env_demo`, depot `agent-depots/w158` before the shared one; `--trim=safe`, one thread; load 18 to 22 of 128.
`JULIA_TREE=wt/w158-julia DEPOT=… NAME=w158-<app>-main bash ../w166/build_c.sh <app>`.

| | errors | binary | runs |
|---|---|---|---|
| the report's program | 0 (6 on `next` f5328f94c5) | 5,448,544 bytes, object in 10 s | exit 0, 0.16 s, 57 MB; its output and its PNG equal a session's, byte for byte (`logs/m-report-bin.out`, `m-report-session.out`, `m-png.sha256`) |
| the plot's program | 0 (6 on `next`) | 5,018,496 bytes, object in 8 s | exit 1: `MissingCodeError` for `render_png(::Figure, ::String, ::Float64)`, invoked from `save` (`logs/m-plot-bin.err`). The verifier counted no error. |

The six errors that are gone were the hole in `issorted`'s keyword body (61277571fa). The plot's binary shows a build
that passes the verifier and lacks an instance its code invokes; the report's program calls the same `save`.

## The library's pieces (W-158, second part), 2026-11-21

Three pieces of daily use in the library: `withfields` on a kept form (traits T-157), the bounded check's message (open
issue 235), and the gate `n14_callable_args` against the box's rule. Julia `julia-next` f5328f94c5, read only; the
library in the worktree `wt/w158b-tw`, branch `w158b` from `unified` 9d4f782; a depot of its own
(`agent-depots/w158b` before the shared one). One Julia job at a time, 4 cores; load 3 to 4 of 128. Logs: `logs/b-*`.

**How to run** (from `wt/w158b-tw`, after `source env.sh` and the depot):
```sh
$JN --project=. -e 'using TraitWorld; include("test/runtests.jl")'                  # the library (Pkg.test lacks Test)
$JN --project=. $W158/b-probes/withfields_closed.jl                                  # piece 1: the build's own check
$JN --project=. $W158/b-probes/withfields_closed_overlay.jl                          # the same without the overlay
$JN --project=. $W158/b-probes/callable_nospecialize.jl                              # piece 3
bash $W158/messages/run.sh <label> $TW_ROOT/wt/w158b-tw                              # piece 2: messages/README.md
LIB=wt/w158b-tw experiments/implementation/gates/run_all.sh julia-next               # from the workspace root
(cd TraitTables && $JN --project=$W158/env_tables_b -e 'using TraitWorld, TraitTables; include("test/runtests.jl")')
```
`env_tables_b/`: TraitTables' manifest with the library at `wt/w158b-tw`, so that its suite tests this branch.

**1. `withfields` on a kept form** (TraitWorld ccd6c48). On a box `Dynamic{X}`, the object rebuilt and boxed at `X`
as any box is made: a rebuilt object outside `X` raises `TypeError` (a `WCell{Int}` from a box of `WHas{Float64}`), a
name that is no declared field of `X` raises `ArgumentError`, as the box's `getproperty` does. On a wrapper, the
wrapper of the rebuilt object. `nudged(p::WPlaced) = withfields(p; x = p.x + 1.0)` of a trait that erases by default
is accepted in a `bounded` scope and gives the box of the rebuilt object. The box's result needs an assertion
(`::Dynamic{X}`): Core's constructor at an argument of unknown type joins its four methods as `Any`.
- **The build's own check** (`logs/b-withfields_closed-e32d443.log`): rebuilding boxes of three members has no hole at
  the rebuilding: the inner call at the object known only by its trait (`_rebuilt(getfield(d, :object)::X, nt)`) and
  the box made of its result. Two holes of another kind:
  - `getproperty(getfield(d, :object)::VPlaced, s::Symbol)::Any` in the box's `getproperty` (`src/dynamic.jl` 43): a
    declared field read at a box (`p.x`), found also in a program that only reads `d.x` (`vread`);
  - `getindex(Core._svec_ref(…)::Core.SimpleVector, 2)::Any` in `Compiler.declared_field_in`, reached from
    `_dynamic_field_type`, from the box's `getproperty` (`dynamic.jl` 41) and from `withfields`' declared-name test.
    Without the overlay of the build's replacements of Base the test folds and the hole from `withfields` is gone
    (`logs/b-withfields_closed_overlay-e32d443.log`); the box's `getproperty` keeps both.
  - `test/verify.jl` marks the remaining hole `@test_broken`.
- The tutorial's `nudged` is written without `@unbounded`; its checks: a box of a new `Sprite` at the box, and a trait
  module that accepts it.

**2. The messages' form** (TraitWorld e32d443): the tool and its counts, `messages/README.md`. Tuple types 13 to 0,
generated names 2 to 0, library internals 1 to 0; six of Julia's own (`MethodError`'s candidates at the wrapper's
forwarding methods) listed, not fixed. `intro.jl`'s mark for open issue 235 is a plain check.

**3. The gate `n14_callable_args`.** Its first assertion (`callit(g1, 1) == 2`) is compiler §6.2: an argument at a set
declared `@nospecialize` is the object passed as itself. Its second and third (a call outside `A` raises `MethodError`
though `g1(::String)` exists; a call proved outside `A` infers as never returning) pin no sentence of the references:
traits §9 and compiler §7.4 put the check of `A` at the box (its making and its call) and at a wrapper's entry, and a
wrapper's call is the function's own. The code checks every call of a value inferred as `Callable{A, S}`
(`abstract_call_unknown`, `handle_callable_call!`, `Core._callable_argcheck`). On julia-next with the library
(`logs/b-callable_nospecialize-e32d443.log`): `callit(g1, "s")` raises `MethodError`; `callit(compiled_for(g1), "s")`
returns 0. The gate is unchanged: the reference and the code disagree, and the case goes to the record as a deviation.

| Check | Before (9d4f782) | After (e32d443) |
|---|---|---|
| the library | 93 testsets pass (`logs/b-library-before-9d4f782.log`) | 96 testsets pass, 1 broken check (`logs/b-library-piece2.log`) |
| docs examples: intro, tutorial, strict | 26 pass and 1 deviation (open issue 235), 95, 5 | 27, 96, 5 pass, no deviation (`logs/b-docs-*-piece2.log`) |
| the gates (`LIB=wt/w158b-tw`) | | 72 of 72, stage gates 9 of 9 (`logs/b-gates-e32d443.log`) |
| TraitTables' suite, with the branch | | 27 pass, 3 testsets (`logs/b-tables-e32d443.log`) |

## The library's pieces, continued (W-158), 2026-11-21

Two pieces: a vararg of members read by the bounded check at the box (traits T-158), and `@enforce_fully_typed` at
a call on an element of `Vector{Any}` (the messages tool's case `cf1`). Julia `julia-next` f5328f94c5, read only;
the library in `wt/w158b-tw`, branch `w158d` from `unified` e32d443; the depot `agent-depots/w158b` before the
shared one. One Julia job at a time, niced, 4 cores; load 4 to 5 of 128. Logs: `logs/d-*`; probes: `d-probes/`.

**How to run** (from `wt/w158b-tw`, after `source $W158/d-probes/env.sh`):
```sh
$JN --project=. -e 'using TraitWorld; include("test/runtests.jl")'                  # the library
$JN --project=. $W158/d-probes/positions.jl         # piece 1: what the forwarder boxes, what the check reads, per position
$JN --project=. $W158/d-probes/vararg_check.jl      # piece 1: what runs at a vararg of boxes; the check's verdicts
$JN --project=$W158/env_demo_d $W158/d-probes/demo_check.jl   # piece 1: the check over the demonstrators' modules
$JN --project=. $W158/d-probes/fully_typed_any.jl   # piece 2: the case, its controls, the case that replaces it
(cd $W158/d-probes/apps && bash $W158/build_app.sh julia-next ftany.jl d-ftany $LIBD)   # piece 2: the closed build
for s in intro tutorial strict; do $JN --project=. -e "using TraitWorld; include(\"$TW_ROOT/experiments/docs-examples/$s.jl\")"; done
(cd $TW_ROOT/TraitDifferentialEquations && $JN --project=$W158/env_demo_d -e 'using TraitWorld, TraitDifferentialEquations; include("test/runtests.jl")')
(cd $TW_ROOT/TraitMakie && $JN --project=$W158/env_demo_d -e 'using TraitWorld, TraitMakie; include("test/runtests.jl")')
```
`env_demo_d/`: W-161's `env_demo` with every path absolute and the library at `wt/w158b-tw` (no resolve).
`build_app.sh` writes `TraitWorld <rev>` of the workspace's `TraitWorld/` in its log's head; the build's project was
`wt/w158b-tw` at 327f253.

### 1. A vararg of members, read at the box (TraitWorld 327f253)

**What runs.**
- **The forwarder boxes no vararg's members.** The expansion hook skips a `Vararg` position
  (`src/erasing.jl`, `_expand_definition`: `T isa Core.TypeofVararg && continue`). A method whose only trait argument
  is a vararg gets no forwarder, also at a trait that erases by default; plain members run as themselves, compiled
  per tuple of their types: traits §6.6, "A vararg of members, `ts::ColTable...`: elements may be different members;
  code is compiled per tuple of their types." Compiler §6.3 asks the hook "at each positional argument"; traits §7.8's
  list of the arguments that erase names no vararg.
- **A box passed at a vararg runs the method as written at the box.** `u(ts::VTab...) = sum(t -> sum(t), ts)` with
  1, 2 and 5 boxes raises `MethodError: no method matching iterate(::Dynamic{VTab})`; Julia compiled
  `u(::Dynamic{VTab})` and, for 2 and 5 boxes, `Tuple{typeof(u), Dynamic{VTab}, Vararg{Dynamic{VTab}}}`
  (`logs/d-vararg_check-81c04c3.log`). This holds at every trait: a box is a member (traits §7.1).

**The rule built.** Traits §7.3, "Where the instance is read": "Each argument at a trait, … at the box of that
trait"; a vararg `ts::X...` is such an argument. The check reads `Tuple{typeof(f), Dynamic{X}, Vararg{Dynamic{X}}}`,
the instance Julia compiles for a call that passes several boxes there (at least one: a call with none passes no
box).
- `box_signature` and `_at_box_checked` (`src/atbox.jl`) read a `Vararg` position at a trait, a `where` variable
  bounded by one included; a fixed count (`Vararg{X, 2}`) Julia spells out in the method's signature, read as before.
- Two widenings were needed for the reading to see the fault, both at the rule "a call in that instance, with a
  value at the box, … that only throws":
  - **A tuple that holds a value at the box passes it on** (`_at_box_value`). Without it, `sum(f, ts)` at a tuple of
    boxes was no call "with a value at the box", and `c2(ts::Vararg{VTab, 2}) = sum(t -> sum(t), ts)`, read at two
    boxes since before, was accepted.
  - **A call left to run time whose result inference gives as `Union{}` only throws.** At a tuple of no fixed length
    the call into Base is not compiled (`dynamic Main.sum(…)::Union{}`), but its result is known.
- The refusal's head names the vararg once: "read with each of `ts` in a box, `Dynamic{CTab}`".
- **A closure in a fault line prints as written,** `sum((t) -> …, ts)`; it printed `sum(::var"#call##0#call##1", ts)`,
  a generated name (traits §11.3; the pattern of open issue 235, not provoked by the corpus before). An untyped
  closure argument printed `(t::) -> …` (`_written_method`, `src/errors.jl`).
- Tests (`test/messages.jl`, "the bounded check names the method as written", 11 to 19 checks): a vararg method not
  bounded is refused, named as written; a bounded one is accepted; a fixed trait argument and a vararg, each way; a
  vararg typed by a `where` variable; `box_signature` of a vararg method.

**The check's verdicts** (`logs/d-vararg_check-before-e32d443.log`, `logs/d-vararg_check-81c04c3.log`): before, all
ten methods of the probe accepted. After: refused `call(ts::VTab...)`, `cfv(a::VTab, ts::VTab...)`,
`c2(ts::Vararg{VTab, 2})`, `cw(ts::T...) where T<:VTab`, `eva(ts::VETab...)` (a trait that erases by default),
`cfirst(ts::VTab...) = first(ts[1])`; accepted the bounded `callok`, `cfvok`, `evaok` (each also runs) and
`cplain(xs::Int...)`.

**What is not settled.**
- **At a trait that erases by default the check reads what a box passed at the vararg runs, not what a plain member
  runs** (per tuple of its types, no forwarder). That is the position of every argument at a trait that does not
  erase; whether a vararg at a trait that erases should be boxed by the forwarder (traits §7.8 against §6.6) is a
  question for the references. A fixed count (`Vararg{ETab, 2}`) is the same: the hook sees the vararg and makes no
  forwarder; the check reads two boxes.
- **The fault line of a closure over a vararg of boxes names the call, not what it reaches:** "`sum((t) -> …, ts)` only
  throws". At a tuple of no fixed length Base's `mapfoldl_impl` makes a `Generator` whose element type is lost
  (`Any`) below; at a fixed count the chain to `iterate(::Dynamic{VTab})` is deeper than `_reaches_no_method`'s bound
  of 20 calls. Traits §7.3: "The report names … what the call reaches."

**The positions** (`d-probes/positions.jl`; `logs/d-positions-before-e32d443.log`, `logs/d-positions-81c04c3.log`):
each position at a trait that does not erase (`PTab`) and one that erases by default (`ETab`).

| Position | What the forwarder does (`ETab`) | What a plain member's call runs (`ETab`) | What the check reads, before → after |
|---|---|---|---|
| `t::X` | boxes | the method at the box | `Dynamic{X}` |
| `ts::X...` | no forwarder | per tuple of member types | not read → `Dynamic{X}, Vararg{Dynamic{X}}` |
| `a::X, ts::X...` | boxes `a`; the tail as it is | `a` boxed, the tail per member type | `Dynamic{X}, Vararg{X}` (the tail at the trait, unboxed) → `Dynamic{X}, Dynamic{X}, Vararg{Dynamic{X}}` |
| `ts::Vararg{X, 2}` | no forwarder | per member types | `Dynamic{X}, Dynamic{X}` |
| `ts::T... where T <: X` | no forwarder | per member types | not read → `Dynamic{X}, Vararg{Dynamic{X}}` |
| keyword `k::X` | the keyword body's own forwarder boxes it | the body at the box | the body at `Dynamic{X}`; the sorter not read |
| `t::X; k::X` | the method's and the body's forwarders box both | both boxed | both at `Dynamic{X}` |
| `t::Union{X, Nothing}` | none | the member as it is | not read |
| `t::Tuple{X, X}` | none | the members as they are | not read |
| `t::X, k::Int = 1` | each of the two methods forwarded | boxed | each at `Dynamic{X}` |
| `k::Int, t::X = M1()` | the longer method forwarded; the shorter has no trait argument | boxed | the longer at `Dynamic{X}`; the shorter not read |
| `v::Vector{<:X}` | none | the vector as it is | not read |

At `PTab` nothing is forwarded and the check reads the same signatures. After the change the check and the
forwarder disagree only at a vararg of a trait that erases (rows 2 to 5): the check reads boxes, a plain member runs
unboxed. A keyword at a trait that erases arrives boxed (the body's forwarder); traits §7.8 says only "Keyword
arguments are passed on whole", of the positional forwarder.

**The demonstrators** (`d-probes/demo_check.jl`, every method at a trait in 11 modules of TraitTables, the ODE port
and TraitMakie read at the box, bounded scope or not): 173 methods read, none with a vararg of members, 0 faults,
before (`logs/d-demo_check-before-e32d443.log`) and after (`logs/d-demo_check-81c04c3.log`). The two widenings refuse
nothing there.

### 2. `@enforce_fully_typed` at an element of `Vector{Any}` (TraitWorld 81c04c3)

**The case is ill-formed.** `@enforce_fully_typed cf1(xs::Vector{Any}) = cn(xs[1])`, `cn` an operation of `CTab`,
raises nothing, and by the reference it must not:
- traits §14: "The modes raise where a build would refuse. … code with a call that a session leaves to run time and
  a build resolves by the members runs without a fault"; compiler §2.7: "The fault is the closed build's refusal".
- **The build resolves it.** `fully_typed(cf1, (Vector{Any},))`, the build's own check, lists no call; a trimmed
  build of the program (`d-probes/apps/ftany.jl`; `logs/d-ftany.build.log`) builds, 2,075,416 bytes, and prints 2
  with exit 0 for a member, a box and a wrapper in `xs` (`logs/d-ftany-run.out`).
- **The session splits it.** Julia's inference tests `isa(x, CT)` (the member's method, inlined) and leaves the
  kept forms' methods (`cn(::Dynamic{<:CTab})`, `cn(::Compiled{<:CTab})`) to dispatch; no check is compiled in.
  A plain function of two methods at `Any` is split the same way, with a `MethodError` at the end; of one method,
  likewise (`logs/d-fully_typed_any-81c04c3.log`).
- So `cf1` is fully typed when closed, not in a session: the difference traits T-122 says the report does not list
  apart.

**The case in the tool** (`messages/cases.jl`) is replaced by one the reference says raises: a call on an operation's
result of an abstract type, at a box (`cf1(t::CData) = sum(cdata(t))`, `cdata(t::CData)::AbstractVector`; traits §14,
"a call on such a result is a call the caller cannot resolve, and the report of the caller names the result as its
root cause"). It raises `NotFullyTypedError`; at a member it runs.

**What the new case showed:** the report's root cause printed the callee as the compiler's tuple type, "`cdata`
returns AbstractVector at Tuple{typeof(cdata), Dynamic{CData}}" (`src/fullytyped.jl`, `_origin`): open issue 235's
pattern, where no case had computed it. It prints `cdata(::Dynamic{CData})` now (`_callform`). Tests in
`test/fullytyped.jl` (23 to 27 checks): the operation at `Vector{Any}` runs at a member and at a box; the abstract
result at a box raises, and its message has no tuple type.

### The checks, TraitWorld 81c04c3

| Check | Result |
|---|---|
| the library | 96 testsets pass, 1 broken check in `test/verify.jl` as before (`logs/d-library-81c04c3.log`) |
| docs examples: intro, tutorial, strict | 27, 96, 5 pass, no deviation (`logs/d-docs-*-81c04c3.log`) |
| the gates (`LIB=wt/w158b-tw`) | 72 of 72, stage gates 9 of 9 (`logs/d-gates-81c04c3.log`) |
| TraitTables' suite (`env_tables_b`) | 27 pass, 3 testsets (`logs/d-tables-81c04c3.log`) |
| the ODE port's suite (`env_demo_d`) | 35 testsets pass (`logs/d-tde-81c04c3.log`) |
| TraitMakie's suite (`env_demo_d`) | 8 testsets pass (`logs/d-makie-81c04c3.log`) |
| the messages tool (`messages/run.sh`, its `b-messages-` logs renamed `d-messages-`) | 109 distinct messages; tuple type 0, generated name 0, compiler object 0, library internal 0; box or wrapper type 40, read (`logs/d-messages-after-81c04c3-*`) |

## Second part: the closed build's members, 2026-11-21

**The question** (E-510, continued): build compiler §7.6's members by the types that flow to a set instance and the
kept form by use (C-152), and an operation on a set with no member as a "no method" fact (C-102); does the session's
check of the ODE program then converge, with which members, and which of its errors are left?

**How to run** (besides the first part's tools):

```sh
source experiments/implementation/w158/env.sh; J=$TW_ROOT/wt/w158-julia/julia
(cd $TW_ROOT/TraitWorld && $J --project=. $W158/probes/flow.jl)          # the gates' programs: members, rounds, errors
(cd $W158 && $J --project=$W156/env_demo probes/ode_members.jl)           # the ODE program's check: rounds, members, s
bash build_app.sh wt/w158-julia apps/flow.jl <name>                      # the small trimmed program (run it, compare)
```

- `probes/patch_c.jl` lays the worktree's change over a session built before it (`include` it first); `probes/rounds.jl`
  (`check_rounds(f, args; show, showcode)`) runs the check's rounds one by one and prints each round's splits, chosen
  instances and their code; `probes/flowdebug.jl` prints why a type is a member at a set type (its places, the flows).
- `JULIA_CLOSED_BUILD_REPORT=1` before a build prints the build's rounds and each split's members.

**What was built** (julia `w158`: d487737095, 8b35e4b77c on 61277571fa; TraitWorld `w158` d50e3d2, tests only):
- Per forgotten type, the places it was forgotten at (as before); beside them the flows between places: a value typed
  `S`, not keeping its type, passed on to a place typed `P` or narrowed to `P` by a test. The members at a set type `X`
  are the types under an entry forgotten at a place typed by a set under `X`, or at a place whose values flow there.
- The box is a member by use: a branch only where a box is forgotten at such a place; not at `getfield(d::Dynamic,
  :object)` read directly.
- No member: the split raises `MethodError`, in the last rounds only (when no round adds a member): before that the call
  is left as it is, so that the code below it is compiled and read.
- A method at a kept form takes some members only, as a method at a family: the call branches over the members.
- Julia's despecialization of a function argument that is not called (`Function`) skips an argument declared at a set
  (`src/gf.c`): the forwarder at a `Callable` signature was compiled at `Function`, one place for every signature.
- The check's rounds: a caller found by its edges (an inlined callee too), an instance ended also where its worlds end
  at a later world (the session's world advances during the check), the verifier in the check's world.

**Results.** Julia `wt/w158-julia` 8b35e4b77c (built in 788 s); controls `julia-next` f5328f94c5, `w158` 61277571fa (the
first part's numbers). TraitWorld `w158` d50e3d2; TraitDifferentialEquations, TraitTables, TraitMakie `unified`
(3e60c29, e1ec1f4, 1888698); project `../w156/env_demo`, depot `agent-depots/w158`. `--trim=safe`, one thread, one Julia
job at a time; load 3 to 12 of 128.

| | before | 8b35e4b77c |
|---|---|---|
| the gates' programs, the check in a session (`logs/c-flow-w158.log`) | 61277571fa: a hole each in `lonely` and `viaany`; the family case 7 rounds, `Wrap{Wrap{…}}` growing, 6 errors (its rules, the new `closed_check` laid over for the report); every function a member at both signatures | 0 errors each; `F1`: `double`; `F2`: `inc` (`triple` once handed on); `Wrap{double}` at `F2` only, 4 rounds; `quad` through `Any` and `isa` counted |
| `apps/flow.jl`, trimmed | `julia-next` 4 errors (`logs/c-flow-julia-next.build.log`) | 0, 2,192,728 bytes, 4 rounds; runs, output equal to a session's (`logs/c-flow-bin.out`) |
| `apps/choice.jl`, trimmed | 0 (61277571fa) | 0, 2,172,008 bytes, runs, equal |
| the library's `test/verify.jl` | `julia-next`: the two new testsets 6 of 19 pass, 1 error (`logs/c-verify-julia-next.log`) | 8 testsets pass (`logs/c-verify-w158.log`) |
| the ODE program's check in a session (`probes/ode_members.jl`) | 61277571fa: no convergence, 4 … 70 members over 7 rounds; 188 s in the build's process | 5 rounds, 12.1 s, 26 errors (`logs/c-ode-members-w158.log`) |
| the ODE program, trimmed, `VERIFY=1` | 88 errors (61277571fa); 12 (`julia-next`) | 36 errors; `verify_main` 9.1 s, 20 sites; 3 rounds (`logs/c-ode.build.log`) |
| the table program | 0 errors | 0, 2,725,504 bytes, 1 round; output equal to the tag's (`logs/c-table-bin.out`) |
| the table's `verify_main` in the build | 2.5 s, 25 sites (`julia-next`) | 2.5 s, 25 sites (`logs/c-table-verify-*.build.log`; 6 errors with `VERIFY=1` on both) |
| the report's program | 0 | 0, 5,413,976 bytes; exit 0, 0.77 s, 47 MB; its output and PNG equal a session's (`logs/c-report-bin.out`, `c-png.sha256`) |
| the plot's program | 0 | 0, 4,980,264 bytes (count only) |

**The ODE program's members** (the check / the build): at the right-hand side's `Callable{Tuple{Vector{Float64} ×3,
Float64}, Nothing}`: `lorenz!`, `robertson!` and the three getters of TraitIndexing (concrete entries of `Callable`),
5 / 5; at the callbacks' signatures 4 / 4 (the getters, the box of the signature); `StepCallback`, `StepEvent`,
`Solvable`: none, a "no method" fact; `LinearSolver`: `DenseLU`. They differ at `Callable` bare: 12 / 7, the check's five
`PartialFn{…}` more (`PartialFn(f::Any, p)` in `_plain_function`, a call the build leaves to dispatch: below).

**The ODE program's 36 errors**, 18 statements reached by both `solve` calls:
- 22, the callbacks' entry (`enter_callbacks`, `enter_step_callbacks` over `cbs::Vector{Any}`): calls at `Any`
  (`_enter_callback!`, `_enter_step_callback!`); the constructors `FunctionCallback{U,T,P}`, `FunctionEventCallback{U,T,P}`
  at values known only by `Callable{…}`, whose forwarder runs at the set instances: its box check `hasmethod(f, A)` does
  not fold (16 with the constructors' calls), and `push!` of the constructors' join.
- 4, the call of the object a box of `All{Callable{…}, Callable{…}}` holds (`callable.jl` 42, 44): left to dispatch.
- 6, Rodas5: `dual_jacobian(@nospecialize(f), n, Val(N))` with `N` chosen at run time and `f::Any`, and the two calls that
  take its result (`rodas5_start`, `_rodas5_run`).
- 4, `PartialFn(f::Any, p)` in `_plain_function(@nospecialize(f), p)`.

**Checks on 8b35e4b77c:** the gates 72 of 72, 9 of 9 stage gates (`logs/c-gates.log`); Base's core, subtype,
Compiler/inline, Compiler/inference SUCCESS (`logs/c-base-summary.log`); the library 96 testsets (`logs/c-library-w158.log`);
TraitDifferentialEquations 35, TraitTables 3, TraitMakie 8 testsets (`logs/c-suite-*.log`); E-384's eight small programs
build, run, output equal (`logs/c-small.log`, `logs/small-c/`); the sessions (`sessions.sh`, a warm-up and 3 runs,
`logs/sessions-c.log`): report 24 compiles, table 19, instances equal to 61277571fa's (`logs/sessions-w158.log`).

**Not done:** the box branch at the object a box holds is dropped only where the code reads `getfield(d, :object)`; the
box's forwarding methods read it through the library's `_fwd`, so a program that keeps a box at a place typed by the set
has a (dead, recursive) box branch there (`logs/c-box-object-ir.log`). No ODE binary: errors are left.
