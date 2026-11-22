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

## Third part: a function known only by its signature, 2026-11-21

**The question** (E-510, continued; compiler C-154, C-151's rest, C-152's rest, C-153; the plot's binary that lacks
code): does a closed build serve the call of a function known only as `Callable{A, S}` (the object a box holds, a
`@nospecialize` argument) and a call with several arguments where the member's type chooses the method, by the rules
of compiler §7.6 as written; and which rule let the plot's program on 61277571fa pass the verifier and stop with
`MissingCodeError`? What would change the design: a case the rules as written cannot serve, or a session that pays.

**How to run** (after `source env.sh` of this directory; `J=$TW_ROOT/wt/w158-julia/julia`):

```sh
(cd $TW_ROOT/wt/w158b-tw && [PATCH=1] $J --project=. $W158/e-probes/callable.jl [case ...])   # the patterns, the check in a session
(cd $TW_ROOT/wt/w158b-tw && $J --project=. $W158/e-probes/box_object.jl)                       # C-152: the forwarding method's split
(cd $TW_ROOT/wt/w158b-tw && OLD=2 [PATCH=1] $J --project=. $W158/e-probes/stale_invoke.jl)    # item 5: a caller the rounds miss
bash e-apps.sh <label> <tree> [app ...]      # apps/e-*.jl, choice.jl, flow.jl: session, trimmed build, run, compare
bash e-builds.sh <label> <tree> [app ...]    # the table's, report's, plot's programs with env_demo_d (the library at wt/w158b-tw)
```

- `e-probes/patch_e.jl` lays this part's compiler change over a session of 8b35e4b77c (`PATCH=1`), as `probes/patch_c.jl`
  did for the second part; `old_invalidate.jl` (`OLD=1`) lays the rounds' caller search of 61277571fa over.
- Logs `logs/e-*`; the build logs of `e-builds.sh` are `../w166/build_c.sh`'s, moved here (`logs/e-<label>-<app>.*`).

**What was built.** Julia `wt/w158-julia`, branch `w158` from 8b35e4b77c (`Compiler/src`: 199 lines added, 77 removed):

| commit | what |
|---|---|
| ea3ae656c3 | the declared field lookup (`declared_field_in`) reads its types' vector asserted a `SimpleVector` (C-153) |
| 4c9949fa78 | a call branches over each argument where the member's type chooses, binds a static parameter or is a wrapper, the product within 64 branches; a closed build lists up to 64 methods of a call at a set argument (C-151) |
| 8dbd516439 | the call of a function known only as `Callable{A, S}`, or an intersection of such, branches over the set type's members by use, its result asserted to `S`, no box branch at the object a box holds; a splatted such call is inferred (C-154) |
| 583752d13d | a constant the code holds counts the members in its fields, wherever the code uses it (a soundness hole, below) |
| 0b0924ef96, 9e742cd3cd | the verifier refuses an invoke whose code the build does not compile unless the build compiles the instance's code of the policy the trampoline's `jl_invoke` asks (item 5) |

The library `wt/w158b-tw`, branch `w158e` from `unified` cedb718: ae31f9e (a box's signatures one by one: the
constructor's `hasmethod(f, A)` and the call at the second signature at a constant `A`, `S`), e1a2200 (the kept forms'
forwarding methods read `getfield(d, :object)`, as lowering §2 says, marked `:kept_forwarding` for the library's
readers), 82959cf (tests). The gate `../gates/n34_closed_invoke_compiled.jl`.

**The patterns, in a session's check** (`e-probes/callable.jl`; before `logs/e-probe-before-8b35e4b.log`, after
`logs/e-probe-9e742cd.log`):

| case | 8b35e4b77c | 9e742cd3cd |
|---|---|---|
| `boxall`: a box of `All{Callable{Tuple{Float64}, Float64}, Callable{Tuple{Int}, Float64}}` called at each | 6 errors (the object's call at both; the box's constructor `hasmethod(f::Any, …)`) | 0; members `hh`, `kk` |
| `boxone`: a box of one signature called | 1 (the object's call) | 0 |
| `nospec`: a function at an argument declared `@nospecialize` | 2 | 0 |
| `ctor2`: a constructor at two signatures, values known only by bare `Callable` | 0, **unsound** (below) | 0; members at `Callable` and at each signature |
| `ctor1`: the same with one such argument | 1 (the box's call) | 0 |
| `twochoice`: five methods at two arguments of a trait | 2 (more methods than Julia's three) | 0 |

**The small programs trimmed** (`e-apps.sh`; `logs/e-apps-before-8b35e4b.log`, `logs/e-apps-9e742cd.log`; errors are
the verifier's `Error #` lines):

| program | 8b35e4b77c | 9e742cd3cd |
|---|---|---|
| `apps/e-boxcall.jl` | 18 | 0, 2,167,048 bytes; runs, output equal to a session's |
| `apps/e-ctor2.jl` (picked at run time, and a constant) | 8 | 0, 2,158,464 bytes; runs, equal |
| `apps/e-twochoice.jl` | 6 | 0, 2,062,104 bytes; runs, equal |
| `apps/choice.jl`, `apps/flow.jl` | 0, 0 | 0, 0; run, equal |

**A soundness hole found** (G1). `ctor2`'s check on 8b35e4b77c had 0 errors and the members at bare `Callable` none:
`[Raw2(hh, kk), Raw2(kk, hh)]` is folded by inference into a constant tuple read by `getfield(tuple, i)`, a builtin's
operand, and the build read a constant only where the code passed it to a place, and a field only where its type did
not keep its values' types. So the set had no member, the call `mkpair(r.c, r.a)` a "no method" fact: the build
would raise where the session returns 14.0. The same for a constant tuple of boxes (`boxone`: the box's object at
`G1` never counted). 583752d13d reads every constant operand, and through fields that keep their types (an isbits
type holds none). The pattern: a value made by constant folding never passes through a statement the build reads.

**C-154.** `Callable`'s call in a closed build branches as an operation's call does: members by use of the signature's
set type, each branch the call at the member's type, the result asserted to `S`, past them `MethodError`. Two gaps
met on the way: the box's call method calls its object splatted, and Julia's inference gives up on a splatted call
of a function of no concrete type (`abstract_apply`): a closed build now infers it where the function is known only by
a signature; and the instance with such a call is noted, so the rounds infer it again when members grow. Where the
arguments may be outside `A`, the session's checked dynamic call stays (a narrowing; no case met). The box's test
`hasmethod(f, A)` at a value known only by its signature is not split by name: the forwarder that holds it is called
at a set argument where the method as written, at the kept forms, takes some members, so the member's type chooses
(§7.6) and the forwarder runs per member, where the test folds (`ctor1`, `ctor2`). Past 64 members, or past the
product's bound, the forwarder would run at the set instance and the test stays unresolved: not built, not met.

**C-151.** Each choosing argument is split; the branches are the product, taken in order while it stays within 64
(an argument past it left as it is). Julia's `max_methods` (3) made a call that four or more methods take a failed
match before the member split was asked: a closed build lists up to 64 methods at a call with a set argument.

**C-152.** The kept forms' forwarding methods read `getfield(d, :object)`; the split at the object has no box branch
(`logs/e-box-object-ir.log`, against `logs/c-box-object-ir.log`). A default's method at a trait still reads its
receiver through `_fwd` (it serves every member), so at a box a default's split keeps the box branch.

**C-153.** (a) The box's `getproperty` at a name that is no constant calls `getproperty` of the object, where Base's
method at `Any` and the kept forms' methods (`Dynamic{<:X}`, `Compiled{<:X}`) take it: a method at a kept form makes
the member's type choose, the rule built in d661fb9eb7 and 8b35e4b77c; the hole is gone since 8b35e4b77c
(`logs/e-withfields_closed-8b35e4b.log`: only the lookup's hole left, at each of the three programs). (b) The lookup's own code read `df[2][k]`, a call left to run
time: it left the generic `getproperty` unresolved, and it tainted the lookup's effects (`!o`), so under the overlay of
the build's replacements the check did not evaluate the `:foldable` `_dynamic_field_type` (concrete evaluation under an
overlay needs effects free of overlaid calls; without the overlay the interpreter is not overlaid and folds). The rule
that holds: the check folds what the build folds; the least mechanism, the lookup typed (ea3ae656c3). The library's
`verify_main: withfields on a box` passes, no hole.

**Item 5: the plot's binary that lacked code** (61277571fa: `MissingCodeError` for `render_png(::Figure, ::String,
::Float64)` from `save`, through `tojlinvoke` and `ijl_invoke_facts`, `logs/m-plot-bin.err`).
- Codegen calls the code instance an invoke names as itself (`aotcompile.cpp`, `resolve_workqueue`); one not compiled
  becomes a trampoline to `jl_invoke_plain` or `jl_invoke_facts` by the named code's policy, which runs the instance's
  compiled code of the policy that call asks (`mi_policy_facts_at`) or else raises `MissingCodeError`.
- The verifier took such an invoke as resolved wherever the instance had *any* code in the build ("assume that only
  this_world matters"), of either policy. The plot's trace (`ijl_invoke_facts`, no code found) fits a build whose
  caller kept invoking code ended between rounds while the instance's compiled code was of the other policy.
- On 8b35e4b77c the plot's program runs (`logs/e-plot-before.build.log`, exit 0, its PNG written): 8b35e4b77c finds a
  round's callers by their edges' instances, so the caller is inferred again. The verifier's gap stays.
- The fix at the rule (9e742cd3cd): the verifier models the trampoline's call: resolved where the build compiles the
  code named, a constant's, or the instance's code of the policy asked. 0b0924ef96 refused every invoke of code not
  compiled: 60 errors in the report's and the plot's builds, all JLLs' `__init__` from their images
  (`logs/e-0b0924e-plot.build.log`), whose calls run; 9e742cd3cd refuses none of them.
- The gate `n34_closed_invoke_compiled.jl` makes the build's list by hand: it fails on 8b35e4b77c (code of the other
  policy only, accepted) and on 0b0924ef96 (code of the policy asked, refused); passes on 9e742cd3cd.
- Not shown: the plot's failure itself, reproduced (61277571fa is not built again). `e-probes/stale_invoke.jl` with
  `OLD=1` (61277571fa's caller search) does not reproduce a missed caller in a session; with `OLD=2` (no caller
  searched) the check's code all has one policy, and the runtime's fallback would find the code.

**Checks on 9e742cd3cd** (library `w158e` 82959cf; load 4 to 9 of 128; one Julia job at a time):

| check | result |
|---|---|
| the gates (`LIB=wt/w158b-tw`) | 73 of 73 (n34 new), stage gates 9 of 9 (`logs/e-gates-9e742cd.log`) |
| Base's core, subtype, Compiler/inline, Compiler/inference | SUCCESS (`logs/e-base-summary.log`) |
| the library | 103 testsets, no broken check (`logs/e-library-9e742cd.log`); verify.jl on 8b35e4b77c: 10 checks fail in 4 testsets (`logs/e-verify-before-8b35e4b.log`) |
| TraitTables' suite (`env_tables_b`), TraitMakie's (`env_demo_d`) | 3 and 8 testsets pass (`logs/e-suite-*.log`) |
| the table's, report's, plot's programs, trimmed (`env_demo_d`) | 0 errors each; table 2,725,208 bytes, output equal; report 5,394,320 bytes, output and PNG equal a session's; plot 4,942,832 bytes, runs, output and PNG equal (`logs/e-builds-9e742cd.log`) |
| E-384's eight small programs | build, run, output equal (`logs/e-9e742cd-small.log`) |
| the sessions (`sessions.sh`, a warm-up and 3 runs) | report 24 compiles, table 19, on `next` 8b35e4b77c and 9e742cd3cd alike; instances equal between the two Julias with either library (`logs/sessions-e-*.log`). With `w158e` TraitWorld holds 20 fewer instances at a kept form (474 against 494 in the report, 413 against 426 in the table): the forwarding methods call no `_fwd` |

**Not done:** the ODE program (another agent's tree changes; the main session builds it after both merges). The
session's check counting more members than the build at bare `Callable` (C-152's second sentence): not looked at.

## The check's reading of optimized code; the front ends' result (W-158), 2026-11-21

Three pieces: the bounded check reads the other branch of a split as "no method" (open issue 249); a session infers
`Any` for the ODE and the nonlinear front ends (open issue 250); the fault's line for a closure over a vararg of boxes
(traits T-159). Julia `julia-next` d8f65ef1ea, read only; the library in `wt/w158g-tw`, branch `w158g` from `unified`
82959cf; the ODE port TDE `unified` 3a1c4c3, read only; the depot `agent-depots/w158g` before the shared one. One
Julia job at a time, niced, 4 cores; load (1 min) 6 to 30 of 128. Logs: `logs/g-*`; probes: `g-probes/`.

**How to run** (after `source $W158/g-probes/env.sh`; `env_demo_g/`, `env_tables_g/`: `env_demo_d`, `env_tables_b`
with the library at `wt/w158g-tw`, no resolve):
```sh
cd $LIBG
$JN --project=. -e 'using TraitWorld; include("test/runtests.jl")'      # the library
$JN --project=. $W158/g-probes/split.jl          # piece 1: the two cases in small, the controls
$JN --project=. $W158/g-probes/artifacts.jl      # piece 1: the pattern, P1 to P10, read optimized and before optimization
$JN --project=. $W158/g-probes/vararg_chain.jl   # piece 3: the walk below the call, level by level
$JN --project=. $W158/g-probes/vararg_mapfoldl.jl   # piece 3: Base's mapfoldl_impl at a tuple of no fixed length
cd $TW_ROOT/TraitDifferentialEquations
$JN --project=$ENVG $W158/g-probes/split_tns.jl      # piece 1: the port's two cases, written beside the port
$JN --project=$ENVG $W158/g-probes/split_tns_dump.jl # piece 1: the keyword body at the box, whole
[RUN=1] [DUMP=1] $JN --project=$ENVG $W158/g-probes/frontends.jl   # piece 2: infer_return_type of the front ends
$JN --project=$ENVG $W158/g-probes/frontends_why.jl  # piece 2: the statement, its fact status, both interpreters
$JN --project=$ENVG $W158/g-probes/frontends_rt.jl   # piece 2: nl_with_problem at sys::Any, per interpreter
RUN=1 $JN --project=$ENVG $W158/g-probes/frontends_fix.jl   # piece 2: the two declared results, in the session only
```

### 1. A split's other branch (open issue 249; TraitWorld 86bad24)

**The case.** Where a call's argument is abstract and its methods cover a part of it, Julia's optimizer compiles a
test of the argument's type, the method's call, and else `Core.throw_methoderror(f, args...)`. `check_at_box` counted
that branch as a call that finds no method. Both of the port's cases reproduce (`logs/g-split_tns-before-82959cf.log`):
- `vA`, `solve_nonlinear` as it was at TDE 1425aec (the operation's result `::NLCoreSolution`): `isa(%2,
  NLCoreSolution{Float64})`, else `throw_methoderror(nl_with_problem, %2, _2, nothing)`; refused.
- `vB`, the front end at 3a1c4c3 without its assertions, and `vB2`, the front end at 1425aec (`_opts(; kw...)`): the
  keyword body read at keywords of type `Any`. Under the facts rule `NLOptions(::Any, ::Any, ::Any)` is a run-time
  site, its result `Any`; the call `solve_nonlinear(prob, alg, ::Any)` is split on it (`isa(%4, NLOptions)`, else
  `throw_methoderror`); refused (`logs/g-split_tns_dump-82959cf.log`). Plain inference types the constructor and
  emits no split: only the facts reading shows it.

**The rule built** (traits §7.3, "left to run time with no method at the types the code knows"; "A call left to run
time that finds a method when it runs is Julia's function barrier, no fault"): *a call is read as written, at the
types the code knows. Where the optimizer splits a call at an abstract argument into the methods that cover a part of
it and a `MethodError` for the rest, the call has a method at those types: no fault. A call that finds no method at
the types the code knows is a fault, split or not.*
- `_has_method_at` (`src/atbox.jl`): Julia's lookup (`Base._methods_by_ftype`) at the types `throw_methoderror` is
  called at, the call it stands for. A `throw_methoderror` with a value at the box is a fault only where it finds
  none, in `check_at_box` and in the walk below a call that only throws. The same test the check makes of a call left
  to run time. A lookup that fails (no answer) stays a fault.
- **Soundness, both directions** (`logs/g-split-f0a8c3e.log`, `logs/g-artifacts-f0a8c3e.log`): `sum(p)` at a box,
  `nometh(p)` with `nometh(x::Int)`, and `gint(xs(t), t)` with `xs(t)::Sol` and `gint(x::Int, t::X)` (an abstract
  argument no method covers: the optimizer emits `throw_methoderror` with no test) stay refused.
- Tests (`test/messages.jl`, "the bounded check reads a split as the call as written", 7 checks): the two cases
  accepted in a bounded module; three refused (no method at the box; an abstract argument no method covers; the box
  beside an argument of type `Any`); the split's `throw_methoderror` is in the instance at the box and
  `check_at_box` gives no fault.
- **A message fixed on the way:** a named function with one method printed as its written signature in a fault line,
  "`nometh(x::Int64)(p)` has no method", "`bad(t)(t)` only throws" (`logs/g-artifacts-before-82959cf.log`):
  `_closure_form` answered for any type named `#…`, and a function's type is `typeof(nometh)`, named `#nometh`. It
  answers for closures only now. The messages tool's corpus held one, uncounted: "`never(p::…Pt)(p, 1)` has no
  method" (`trait_modules.jl`; `logs/d-messages-after-81c04c3.tsv`); now "`never(p, 1)` has no method".

**The pattern: statements of the optimized instance the check reads** (`g-probes/artifacts.jl`; before
`logs/g-artifacts-before-82959cf.log`, after `logs/g-artifacts-f0a8c3e.log`). "Before optimization" is the same
reading (`_box_faults`) over the instance's inferred code before optimization (`optimize = false`): no inlining, no
split.

| Statement | Probe | Before | After | Before optimization | Verdict |
|---|---|---|---|---|---|
| a split's other branch: `isa(x, T)`, the call, else `throw_methoderror` (an operation's result `::Sol`, one method at `Sol{Float64}`) | P1 | fault | none | none | an artifact of the split; fixed |
| the same over a union result that the methods cover in part (`gu1(::Int, …)` at `Union{Int, Float64}`) | P2 part | fault | none | none | fixed |
| a union split the methods cover (`gu` at `Int` and `Float64`): no other branch | P2 | none | none | none | right |
| `throw_methoderror` where no method applies at the types known (`gint(::Sol, t)`) | P10 | fault | fault | fault ("only throws") | the method as written; kept |
| a value known only by its trait (`xy(t)::Y`) passed to a function with a method for one member (`onlycirc(::Circ)`): split over the set's members | P8 | fault | none | none | by §7.3's letter no fault (a method at `Y`'s part); a gap below |
| the same with five methods, one at a member | P8 five | fault | none | none | the same |
| a callee inlined at a union split, its branch for the other type only throws (`kk(x, t) = x isa Int ? 1.0 : bad(t)`) | P3 | fault | fault | none | **an artifact of inlining:** `@noinline` the same callee: none |
| a callee with a call that finds no method on one branch (`g4(t, k) = k > 0 ? xv(t) : sum(t)`) | P4 | fault inlined, none not inlined | the same | none either way | **the inliner decides**; neither reading follows a call that returns into its callee |
| `unreachable` after such a call | P1, P3 | not read (no call) | | | right |
| a branch constant propagation removes (`g7(t, 1)`) | P7 | none | none | none | right |
| `Core.typeassert(t, M)` that always fails at the box | P5 | none | none | none | **a miss:** a builtin is not read; the method asks the box what only the object answers (traits §7.4) |
| the method's own error path: `error("negative: ", t)` | P6 | fault | fault | fault | "only throws" by the letter |
| the same with `throw(ArgumentError(string("negative: ", t)))` | P6 throw | none | none | none | **inconsistent with the row above:** `throw` is a builtin |
| `throw(ArgumentError("no"))` from an inlined callee at the other type | P9 | none | none | none | right |
| a call left to run time whose result is `Union{}` (a vararg of boxes) | piece 3 | "only throws" | names the operation | | piece 3 |

What the table shows, beyond 249: the check reads the optimized instance, so **inlining** decides two verdicts (P3,
P4) and the spelling of an error path decides another (P6). The code before optimization gives one verdict per
method as written, but misses P4's fault in either form: no reading follows a call that returns into its callee.
Proposal (open issue text below): read the instance before optimization, and follow every call that passes a value
at the box into its callee's instance where the callee is not checked itself (no argument at a trait), as the walk
now follows a call that only throws; read a type assertion at the box as a call; count an error path only where it
reaches a call that finds no method or an undeclared field.

**The port's lines** (TDE 3a1c4c3, not changed):
- `lib/TraitNonlinearSolve/src/solvers.jl:45`, the three assertions `Float64(abstol)::Float64`,
  `Float64(reltol)::Float64`, `Int(maxiters)::Int`, and the comment on line 43 that gives their reason: the check
  needs them no more (`vB` accepted, `logs/g-split_tns-f0a8c3e.log`). In a session the keyword body is compiled at
  the keywords' own types; only the check read it at `Any`.
- `solve_nl(…, m::NLCoreProblem{T}, …)::NLCoreSolution{T} where {T}` (d96afc6, line 28): the check needs it no more
  (`vA` accepted); it stays, a rule of its own (traits §4.1): a caller that knows the problem knows the solution.

**The demonstrators** (`d-probes/demo_check.jl`, every method at a trait in 11 modules read at the box): 188 methods,
0 faults before (`logs/g-demo_check-before-82959cf.log`) and after (`logs/g-demo_check-f0a8c3e.log`); no method
newly accepted or refused. (173 methods in the `d-` logs: the port has more since.)

### 2. The front ends' result in a session (open issue 250)

**The statement that loses the type** (`logs/g-frontends-82959cf.log`, `-dump-`, `g-frontends_why-82959cf.log`,
`g-frontends_rt-82959cf.log`): the front ends' last call builds the solution from the problem's system object,
`sys = _system(prob)`, typed `Any` (`_system(x::HasSystem) = getsystem(x)`, an operation declared `::Any`):
- nonlinear: `nl_with_problem(s, prob, @nospecialize(sys)) = NonlinearSolution{T,P}(s.u, s.resid, s.retcode,
  s.stats, prob, sys)` (`lib/TraitNonlinearSolve/src/problems.jl:321`);
- ODE: `with_problem(s, prob, sys, names, pt, pu) = ODESolution{T,P}(…, prob, sys, names, pt, pu, s.interp)`
  (`lib/ODECore/src/core.jl:943`).

Both functions are owner-only (a fact at any signature) and inferred; inside them the constructor at `sys::Any`
is no fact signature (`is_fact_sig` false at `NonlinearSolution`'s; `NonlinearSolution` and `ODESolution` are
exported, and a type's constructor is no owner-only function). Under the facts interpreter the call is a run-time site, `Any`; plain inference gives
`NonlinearSolution{Float64, Vector{Float64}}` (a `PartialStruct`). The callees `nl_core`, `solve_nl`,
`core_problem`, `solve_core` infer concrete types. The same after a run (`logs/g-frontends-run-f0a8c3e.log`).

**The verdict: the port's code, by the design's rule.** Facts §3: a call at an abstract argument type of a function
that is not owner-only is a run-time site; and so it must be: the owner of a system type may define
`NonlinearSolution{T,P}(…, sys::MySys)`, no pirate. Facts §4.2: "`Any` spreads into the code after the call, until
a declared result or an assertion narrows it." The port's front ends write no declared result there, while their
docstrings say "a caller's code knows the solution's type" (`solvers.jl` `solve`'s docstring; TDE
`src/TraitDifferentialEquations.jl`, `solve`'s). With `nl_with_problem(…)::NonlinearSolution{T,P}` and
`with_problem(…)::ODESolution{T,P}`, redefined in the session only, every front end infers its concrete type:
`solve_nonlinear`, `TNS.solve`, the umbrella's `solve` for both kinds, `solve_ode` with Tsit5 and Rodas5
(`logs/g-frontends_fix-82959cf.log`); the solves give `Success`. A closed build resolves the call by the members, as
the build's check does. With callbacks `param_integrator(…, sys, …)` (`core.jl:1284`) is a run-time site of the same
kind; its result is the solver's integrator, passed to `adapt_callbacks!`, not the front end's result.
- Test (`test/fullytyped.jl`, "a record built from a value the code does not know", TraitWorld f0a8c3e): in a trait
  module, a record built from a field typed `Any` infers `Any`, with a declared result its type; the constructor's
  signature is no fact.

### 3. What a closure over a vararg of boxes reaches (traits T-159; TraitWorld 1335b13)

`call(ts::CTab...) = sum(t -> sum(t), ts)` was refused with "`sum((t) -> …, ts)` only throws"
(`logs/g-vararg_chain-86bad24.log`, the walk level by level):
- **At a fixed count** (`c2(ts::Vararg{CTab, 2})`) the chain from `sum` to `iterate(::Dynamic{CTab})` is 22 calls
  deep, past the walk's bound of 20 (`depth > 20`). The cause is in the walk.
- **At a tuple of no fixed length** the chain ends at level 7: `mapfoldl_impl` at `Tuple{Dynamic{CTab},
  Vararg{Dynamic{CTab}}}` infers `Any` under the facts rule, `Union{}` under plain inference
  (`logs/g-vararg_mapfoldl.log`). `Base.Generator(f, ts)` is typed `Generator{I, F} where I<:Tuple{…}`, an abstract
  type, so the next call, `Base._xfadjoint(…)`, is no fact signature and a run-time site. The cause is in Base's
  code read by the facts rule, not in the walk: at that type a session cannot see past it. At a tuple of one box
  `mapfoldl_impl` is `Union{}` under both.

**Built** (`_reaches_no_method`, `_fixed_length`, `_link_name`, `src/atbox.jl`):
- the walk follows the chain to the call that finds no method whatever its depth; each signature is read once (the
  set `seen`), which ends a recursion. No bound on the depth.
- a tuple of boxes of no fixed length is read at its fixed elements, or at the vararg's one element where it has
  none: the instance a call that passes one box runs (traits §7.3, a vararg "with each element in a box, at least
  one"). The walk only names what the call reaches; the fault itself is the call that only throws.
- the chain is named by the functions' names. A keyword body printed as its written signature, `sum(a;
  kw::Base.Pairs{Symbol, V, Nothing, NT} where {V, NT<:NamedTuple})`, Base's internals in the message: left out
  now; a closure as written. The messages tool's corpus held 11 such messages, uncounted
  (`logs/d-messages-after-81c04c3.tsv`); now none (`logs/g-messages-f0a8c3e.tsv`).

Now (`logs/g-vararg_chain-f0a8c3e.log`): "`sum((t) -> …, ts)` reaches `iterate(::Dynamic{CTab})`, which has no
method (through mapreduce → mapfoldl → mapfoldl_impl → foldl_impl → _foldl_impl → afoldl → (t) -> … → sum)", at a
tuple of no fixed length and at two; `sum(t)` at a box: "(through sum → mapreduce → mapfoldl → mapfoldl_impl →
foldl_impl → _foldl_impl)". Tests (`test/messages.jl`, "the bounded check names the method as written", 19 to 24
checks): `length` named for `sum(t -> length(t), ts)`; `iterate` named, through the closure, at no fixed length and
at two, with no keyword body in the chain.

### The checks, TraitWorld f0a8c3e

| Check | Result |
|---|---|
| the library | 105 testsets pass, none broken (`logs/g-library-f0a8c3e.log`); 103 before (`logs/g-library-before-82959cf.log`) |
| docs examples: intro, tutorial, strict | 27, 96, 5 pass, no deviation (`logs/g-docs-*-f0a8c3e.log`) |
| the gates (`LIB=wt/w158g-tw`) | 73 of 73, stage gates 9 of 9 (`logs/g-gates-f0a8c3e.log`) |
| the ODE port's suite (`env_demo_g`) | 35 testsets pass (`logs/g-tde-f0a8c3e.log`) |
| TraitMakie's suite (`env_demo_g`) | 8 testsets pass (`logs/g-makie-f0a8c3e.log`) |
| TraitTables' suite (`env_tables_g`) | 27 pass, 3 testsets (`logs/g-tables-f0a8c3e.log`) |
| the demonstrators' methods at the box (`d-probes/demo_check.jl`) | 188 methods, 0 faults, before and after |
| the messages tool (`messages/run.sh`, its `b-messages-` logs renamed `g-messages-`) | 116 distinct messages; tuple type 0, generated name 0, compiler object 0, library internal 0; box or wrapper type 46, read (`logs/g-messages-f0a8c3e-*`) |

**Not settled.**
- The pattern's other rows (P3 to P6, P8): proposals only; nothing changed for them.
- The port keeps its assertions and has no declared result at `nl_with_problem` and `with_problem`: another tree.
- The messages tool does not count a function printed as its signature, nor Base's internals (`Base.Pairs`) in a
  chain; both were in its corpus (12 messages) and found by the probes here. The tool is not changed (not this
  work's file).

## The check's verdict and the optimizer (open issue 251), 2026-11-21

**The question.** The bounded check reads the method's optimized instance at the box, so inlining, a split and the
spelling of an error path decide some verdicts (the previous section's table, P3 to P6, P8). Which reading of the
instance makes the verdict a property of the method as written, what does each candidate change in the methods the
library's tests, the documentation's examples and the demonstrators define, and what does it cost per method (GT-12,
the check's cost at an edit)? **What would change the design:** a reading that changes no verdict there but for the
named artifacts, at about a tenth more per method, is built; otherwise the rule is proposed and nothing is built.

Julia `julia-next` d8f65ef1ea, read only; the library `wt/w158g-tw`, branch `w158h` at `w158g` f0a8c3e, **not
changed**; the ODE port TDE 3a1c4c3, TraitTables and TraitMakie as `g-probes/env_demo_g` resolves them; the depot
`agent-depots/w158h` before the shared one. One Julia job at a time, niced, one thread; load (1 min) 5 to 19 of 128.
Logs: `logs/h-*`; probes: `h-probes/`.

**How to run** (after `source $W158/h-probes/env.sh`):
```sh
cd $LIBG; $JN --project=. $W158/h-probes/artifacts.jl      # the probes P1 to P14, S1 to S5, under every reading
bash $W158/h-probes/corpus.sh <label> [library intro tutorial strict demos]   # every method at a trait, every reading
cd $TW_ROOT/TraitDifferentialEquations; [H_MEMO=1] $JN --project=$ENVG $W158/h-probes/cost.jl   # GT-12: ms per method
cd $LIBG; $JN --project=. $W158/h-probes/sidecases.jl     # an undefined global at a module's end; hasproperty at a box
```
- `readings.jl`: the module `Readings`. `R0` is the library's `check_at_box`, its body copied (`r0`); `x0` the
  reimplementation with no change, a control (its verdicts equal R0's on every method of every corpus). The candidates,
  alone and combined: **(a)** the instance before optimization (inferred, not optimized), callees read the same way;
  **(b)** a call that passes a value at the box into a callee that is not read at a box itself (not a method at a
  trait, a trait's own method, a kept form's method or a forwarder) is followed into the callee's code, at the call's
  argument types with its constants (constant propagation, as the call's own inference did); not a callee the code does
  not know (an undefined global, a value of an abstract type), not a call inference proves cannot throw (the statement's
  `IR_FLAG_NOTHROW`, or a compiled callee whose exception type admits neither `MethodError` nor `ArgumentError`);
  **(c)** a builtin with a value at the box that only throws (`Core.typeassert(t, M)`) is a fault; **(d)** a call
  that only throws is a fault only where it reaches a call that finds no method or an undeclared field; **(e)** a value
  known only by its trait is looked up, and followed, at its box; **(f)**, beside the issue's list, with (b): a value
  that holds one of those in a field (a closure that captures the box, a struct made from it) passes it on.
- `corpus.jl`: the library's `check_at_box` replaced by its own body and a record of every reading in the same world,
  so a method a test refuses (and the check deletes) is read too; at the end every method of the session's method table
  in the corpus's modules that is read at the box. `demos`: the modules of `d-probes/demo_check.jl`.

### The probes (`logs/h-artifacts-f0a8c3e.log`)

P1 to P10 are `g-probes/artifacts.jl`'s. Added: P8 at a function with a method at the trait (`gy(y::Y)`); P11 a
closure that captures the box (`map(i -> sum(t), 1:2)`); P12 an error path whose message calls `sum(t)`; P13 a callee
that throws for every argument (`fail(x) = throw(ArgumentError("no"))`); P14 a value known only by its trait asserted
to one member (`(xy(t)::Circ).r`); S1 to S5 controls (`sum(t)`, an undeclared field, an operation, `typeof`/`Ref`/
`string`/`==`/`hash` of the box, a helper that calls an operation).

| Probe | R0 | a | b | c | d | e | c+d+e | b-e | a+c+d+e | a-e | f | a-f |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1, P2 (splits) | none | none | none | none | none | none | none | none | none | none | none | none |
| P3 inlined / not | **fault** / none | none / none | fault / none | fault / none | none / none | fault / none | none / none | none / none | none / none | none / none | fault / none | none / none |
| P4 inlined / not | **fault / none** | none / none | fault / fault | fault / none | fault / none | fault / none | fault / none | fault / fault | none / none | fault / fault | fault / fault | fault / fault |
| P5 `t::M` | none | none | none | fault | none | none | fault | fault | fault | fault | none | fault |
| P6 `error` / `throw` | **fault / none** | fault / none | fault / none | fault / none | none / none | fault / none | none / none | none / none | none / none | none / none | fault / none | none / none |
| P7 inlined / not | none / none | none / none | none / none | none / none | none / none | none / none | none / none | none / none | none / none | none / none | none / none | none / none |
| P8 one / five methods | none / none | none / none | none / none | none / none | none / none | fault / fault | fault / fault | fault / fault | fault / fault | fault / fault | none / none | fault / fault |
| P8 at the trait (`gy`) | none | none | none | none | none | none | none | none | none | none | none | none |
| P9, P12, P10 | as before: none, fault, fault under every reading | | | | | | | | | | | |
| P11 closure | none | none | none | none | none | none | none | none | none | none | fault | fault |
| P13 throws for all | fault | fault | fault | fault | none | fault | none | none | none | none | fault | none |
| P14 `xy(t)::Circ` | none | none | none | none | none | none | fault | fault | fault | fault | none | fault |
| S1, S2 / S3 to S5 | fault / none under every reading | | | | | | | | | | | |

- One verdict per method as written, for every pair: (a)+(c)+(d)+(e), (b)-(e), (a)-(e), (a)-(f). (a) alone leaves P6;
  (b) alone, P3 and P6.
- **P4 separates them.** (a)+(c)+(d)+(e) gives P4 none in both forms: consistent, but it accepts a method whose helper
  calls `sum(t)` on a branch, which fails at every box when taken (the reading in force refuses it inlined). (b) reads
  the helper: fault in both forms. P7 shows why (b) reads a callee with the call's constants: read at its widened
  types, `g7n(t, 1)`'s other branch is a fault the call never takes (seen before the constants were passed).
- P11 is read by no reading of the issue's list, nor by the reading in force, optimized or not: the box reaches
  `sum` inside the closure's body, which no call passes the box to. Only (f).

### Every method at a trait in the corpora (`logs/h-corpus-<corpus>-f0a8c3e.log`, `.tsv`)

| Corpus | Methods read at the box | taken at a check while it ran | not bounded (R0) | Checks of the corpus |
|---|---|---|---|---|
| the library's tests | 179 | 88 | 29 | the suite passes (no failure in the log) |
| `intro` | 6 | 6 | 1 | 27 pass |
| `tutorial` | 35 | 34 | 1 | 96 pass |
| `strict` | 1 | 1 | 0 | 5 pass |
| the demonstrators | 142 | 0 | 0 | |

No reading raised. Verdicts that differ from R0, of the 363 methods:

| Reading | a | b | c | d | e | c+d+e | b-e | a+c+d+e | a-e | f | a-f |
|---|---|---|---|---|---|---|---|---|---|---|---|
| differ | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 1 | 1 |

- **b-e, a-e, a-f:** ODECore `lib/ODECore/src/frontend.jl:69`, the keyword body of `ODEProblem(f, u0, tspan, p;
  callback)`, marked `@unbounded`: bounded → "`_problem_of(f, ::Callable{…}, ::Vector, ::Tuple{Any, Any}, p, ::Any)`
  reaches the field `mass_matrix` of `Callable{…}` (through `_mass_matrix`)". The argument is `unwrap(f)`, the object,
  known only by its trait, read at its box (e); `_mass_matrix(x)` reads `x.mass_matrix` behind `hasproperty(x,
  :mass_matrix)`, and inference does not fold that guard at a box: `propertynames(::Dynamic{X})` infers
  `Tuple{Vararg{Symbol}}` (`logs/h-sidecases-f0a8c3e.log`), though the declared fields are fixed once `X` is declared.
  A fault no box meets (the guard is false at a box); `bounded` does not refuse the method (`@unbounded`).
- **f:** `dotg(a::Samples{T}, b::Samples{T})` (`docs-examples/tutorial.jl:355`, bounded scope): bounded → "`reduce_empty(
  ::Base.MappingRF{…closure holding the boxes…}, ::Type{Int64})` only throws", the empty reduction's error path,
  reached through the closure (f) and counted by the rule in force; with (d) none (a-f).
- **"188 methods":** `d-probes/demo_check.jl` counts a method once per name it is reached by. In the method table the
  demonstrators have 146 methods at a trait (141 reached by name, and 5 that `methods(f)` by name does not list:
  parametric constructors, `convert`), of which 142 are read at the box (4 have no box). These 142 are this section's.

### The cost per method (GT-12; `logs/h-cost-f0a8c3e-1.log`, `-2.log`, `logs/h-cost-memo-f0a8c3e.log`)

The 142 demonstrators' methods, each instance at the box inferred again (its top frame not cached, its callees
cached: an edit), then read; the second of two passes in one process; two processes. ms per method, median / mean
(total); the ratio of totals against the check in force.

| The check | run 1 | run 2 | ratio |
|---|---|---|---|
| in force: inference and optimization (0.13 / 0.43) and the reading (0.03 / 0.11) | 0.17 / 0.54 (76.7) | 0.17 / 0.55 (77.8) | 1 |
| (c)+(d)+(e) over the optimized code | 0.15 / 0.46 (65.4) | 0.15 / 0.47 (66.6) | 0.85 |
| (b)-(e) over the optimized code | 0.26 / 1.08 (154.0) | 0.26 / 1.15 (163.7) | 2.0 to 2.1 |
| (a)+(c)+(d)+(e), a second inference (0.06 / 0.23) | 0.21 / 0.68 (96.7) | 0.21 / 0.76 (107.6) | 1.26 to 1.38 |
| (a)+(c)+(d)+(e), the inferred code kept from the one inference | 0.14 / 0.45 (64.5) | 0.14 / 0.46 (65.5) | 0.84 |
| (a)-(e), a second inference | 0.35 / 1.25 (177.9) | 0.34 / 1.26 (178.8) | 2.3 |
| (a)-(e), the inferred code kept from the one inference | 0.26 / 1.03 (145.6) | 0.26 / 0.96 (136.7) | 1.76 to 1.90 |
| (a)-(f), a second inference | 0.36 / 1.20 (170.0) | 0.34 / 1.28 (181.1) | 2.2 to 2.3 |

- The reading in force spends its 0.11 ms (mean) mostly before any fault: it builds each call's line information
  (`_frames`) for every call statement. The readings here build it only for a fault, so (c)+(d)+(e) costs 0.03 ms.
  (Reasoned from the code and the two numbers; not profiled.)
- **(a)** costs a second inference of the method's own frame (0.06 / 0.23 ms; callees cached): Julia's inference
  optimizes inside `typeinf` for a cached instance, and the code before optimization is not kept
  (`convert_to_ircode` replaces the frame's code). Without it, the inferred code needs a change of Julia: the native
  interpreter's inference of the instance at the box hands the check its code before optimizing.
- **(b)** costs the inference of each callee followed: the slowest methods under (a)-(e) are the front ends (run 1:
  `SteadyStateProblem`'s keyword body 15 ms, `solve_nonlinear` 8.8 ms, `ODEProblem`'s keyword body 7.1 ms,
  `NonlinearProblem` 4.9 ms, `_sync_out!` 4.5 ms; each 0.1 to 0.3 ms under the check in force). Pruning by inference's nothrow flag halves the median; by the callee's exception
  type, nothing more. With each followed callee's result kept and found by a later check (`H_MEMO=1`, every walk
  found, an upper bound on such a cache), (a)-(e) costs 1.31 (one inference) and 1.86 (a second).
- No reading that decides P4 stays within a tenth more. (c)+(d)+(e) over the optimized code, and (a)+(c)+(d)+(e) with
  the inferred code kept, cost less than the check in force and change no verdict, but leave P4 to the inliner (c+d+e)
  or accept it (a+c+d+e).

**Not built** (the brief's condition: no verdict changed but the artifacts', and about a tenth more per method; (a)-(e)
changes one verdict, of an `@unbounded` method, and costs 1.8 to 2.3 times). The library is unchanged; the reading is
proposed (open issue 251).

### Side findings

- **A global the module never defines is no fault.** The library's test `mfvok(a::MShape, ts::MShape...) = marea(a) +
  sum(marea, ts)` (`test/messages.jl:104`, expected "nothing") runs in a module that imports `MShape` only: `marea` is
  undefined there, the call is left to run time with a callee of type `Any`, which some method covers, and the method
  is accepted at its module's end; called, it raises `UndefVarError` (`logs/h-sidecases-f0a8c3e.log`). The test passes
  for a reason it does not state; traits §7.3 says such a method "waits for those names, and at last for its module's
  end", not what the end decides.
- **Inference at a box advances the world counter:** `code_typed_by_type` of an instance at the box by 3, the reading
  in force by 1 (`cost.jl`'s walk cache, keyed by the world, never hit until keyed without it). No method of the corpus
  changes; the counter's cause is not identified here.
- `hasproperty` at a box is not folded (above): `propertynames(::Dynamic{X})` could be `:foldable` as
  `_dynamic_field_type` is; then the ODE adapter's guard is decided at compile time, and its one changed verdict goes.
  Not verified.

## Fourth part: the ODE program through a build, 2026-11-21

**The question** (E-510, continued; compiler C-155, C-152's rest, C-86; open issues 184, 247): with compiler §7.6's two
sentences of C-155 built (a type that one entry makes a member of every instance is a member by use at each; the call
of a function known only as bare `Callable` branches over its members by use), does the ODE program build with no
error, run, and print a session's output; how far does the program with callbacks it knows get; why is a method at a
`Union` of records not chosen by the member's type (open issue 247); do the session's check and the build count the
same members? What would change the design: a rule that cannot serve the program, or a build that answers otherwise
than the session.

**How to run** (after `source env.sh` of this directory; `J=$TW_ROOT/wt/w158-julia/julia`):

```sh
bash f-probes/ode_build.sh <label>                         # the ODE program trimmed, VERIFY=1, the build's report; run, compare
APP=apps/ode_cb bash f-probes/ode_build.sh <label>         # the program with callbacks it knows
(cd f-probes && [APP=<file>] [PATCH=1] $J --project=../env_demo_d ode_members.jl)    # the build's check in the session
(cd $TW_ROOT/wt/w158b-tw && [PATCH=1] $J --project=. $W158/f-probes/verify.jl)        # the library's test/verify.jl
(cd $TW_ROOT/wt/w158b-tw && $J --project=. $W158/f-probes/box_default.jl)             # C-152: a default's method at a box
(cd f-probes && [APP=<file>] SHOWCODE=<regex> $J --project=../env_demo_d ode_rounds.jl)   # the check's rounds, with code
bash f-apps.sh <label> <tree> [app ...]                    # apps/f-*.jl and the parts before: session, trimmed, run, compare
bash f-checks.sh <label> [tree] [step ...]                 # gates base library port tables makie builds small apps sessions
```

- `f-probes/patch_f.jl` lays this part's compiler change over a session of an older build (`PATCH=1`; `PATCH_NAMES`,
  `PATCH_TYPEINFER` choose the definitions), as `e-probes/patch_e.jl` did for the third part.
- `f-builds.sh` is `e-builds.sh` with its build logs here (`logs/w166c-f-<label>-<app>.*`). The project is `env_demo_d`
  (the library at `wt/w158b-tw`) throughout.

**What was built.** Julia `wt/w158-julia`, branch `w158` from `next` d8f65ef1ea (`Compiler/src`: 87 lines added, 11
removed); the library `wt/w158b-tw`, branch `w158f` from `unified` 82959cf.

| tree | commit | what |
|---|---|---|
| julia | 8d8994b5fc | a concrete entry that leaves the set's inputs free is a member by use at each instance (C-155); the call of a function known only as `Callable`, with no signature, branches over `Callable`'s members by use, its result the join of the branches' |
| julia | 6d5480e347 | a method at a `Union` of records chooses by the member's type (open issue 247): `closed_choice_bits` read a method's type only where it was a struct, a family or a kept form; a `Union` was skipped |
| julia | b22ab12a1f | an operation's results are forgotten at its declared result (a soundness hole, below); the entry's freedom read at the set's input parameters |
| julia | 2b94e4afd1 | a split by the member's type may raise past its branches: its effects are no longer nothrow (a soundness hole, below) |
| julia | dc11704ef7 | the build's report lists each split's members of the set's type, as the check does |
| library | 8d3d699, f30f5db | tests: `test/verify.jl`, five testsets (below) |
| library | 9163b9c | a default's method at a trait calls the operation on a box's object as `getfield(d, :object)` (C-152's rest) |
| library | 3c2dc6b | a box's write of a declared field folds its `@const` test at a constant name (a generated function of the name) |

**The mechanisms.**
- *A member of every instance by use* (`closed_entry_free`, `closed_candidates_in`): an entry in force whose member is a
  concrete type and whose instance has a variable at one of the set's input parameters (`@implement Callable T`, the
  instance `Callable{A, S} where {A, S}`) adds the type only where `closed_reaches` finds it forgotten at a place that
  reaches the set type, as a family's member. On the demonstrators' modules three entries are of this kind,
  TraitIndexing's getters (a walk over the modules `env_demo_d` loads, in a session; not kept).
- *Bare `Callable`'s call* (`abstract_call_unknown`, `closed_callable_split` with `S === nothing`): where the function's
  type is a `Callable` with no signature known (`callable_result` gives nothing), a closed build splits over the
  members by use; the result is the join, nothing asserted; past the branches `MethodError`.
- *Open issue 247, why:* `closed_choice_bits` tested `unwrap_unionall(p)` for a kept form or a non-abstract
  `DataType`; `Union{NonlinearFunction, ODEFunction}` is a `Union`, so the argument was not marked as one where the
  member's type chooses, and the call at the box's object (two matched methods) was left to dispatch.
  `closed_choosing_type` reads a union by its components.
- *C-152's rest:* the default's method reads `getfield(d, :object)` under `d isa Dynamic{<:X}` (`x isa Dynamic` at a
  box's own type is not folded by inference: its positive answer is read as resting on a membership). Before, the
  split at the object had a box branch that called the default's method at the box again
  (`logs/f-box-default-before-82959cf.log`); after, no box branch and no instance of the default at the box
  (`logs/f-box-default-w158f.log`).

**Two soundness holes found, both G1** (the build answered otherwise than the session, with no error):
1. *An operation's result inlined from a lone branch* (b22ab12a1f). `linfactor(ls, W)::Solvable{Float64}` at
   `ls::LinearSolver` has one member, `DenseLU`; the optimizer inlines its branch, and its `LU` goes straight on to
   `ldiv!`. No statement of the optimized code forgets it, so `Solvable{Float64}` had no member, and `ldiv!` was a
   "no method" fact. On 6d5480e347 the ODE program built with 0 errors and its binary raised `MethodError: ldiv!(…,
   ::LU, …)` at Robertson (`logs/w166c-f-ode-6d5480e.build.log`, `logs/f-ode-6d5480e.bin.out`); the build before
   (d8f65ef1ea) had the same member list (`Solvable{Float64}: 0 members` since 8b35e4b77c) but did not get that far.
   Rule: the branches' results are values forgotten at the declared result, noted where the split is inferred
   (`closed_note_result!`). Test: `closed check: an operation's results are forgotten at its declared result`;
   program `apps/f-result.jl` (julia-next: the binary raises; b22ab12a1f on: runs, equal).
2. *A split's effects* (2b94e4afd1). `closed_member_split` gave the call the effects of its branches' call, inferred
   at the union of the members, which is nothrow where each branch is: a call whose result folded to a constant was
   dropped, and a value the build did not count got another member's answer. `apps/f-gapfn.jl`: `triple` reached
   only as the 4,097th element of a constant, at `use(f::F, x)`, members `{double}`: the binary printed `gap 4.0`
   (double's), the session `gap 6.0`, on julia-next d8f65ef1ea and on b22ab12a1f alike
   (`logs/f-apps-before-d8f65ef.log`, `logs/f-apps-b22ab12.log`). The split is now not nothrow, its exception type
   includes `MethodError`: the binary raises `MethodError` (`logs/f-apps-dc11704.log`).

**C-86 and the new rule.** Members by use have C-86's gaps (a value no compiled code forgets: a foreign call,
reflection, a constant past 4,096 elements or three levels). Before C-155 a concrete callable type declared by
`@implement Callable T` was a member of every signature, so no gap reached it; now it is counted as a family's member,
so the gaps reach it as they reached a plain function. `apps/f-gap.jl` (`Get`, reached as the 4,097th element of a
constant) builds; with 2b94e4afd1 its binary raises `MethodError` where the session returns `gap 6.0` (G1: an error).

**Results.** Julia `wt/w158-julia` 6d5480e347, b22ab12a1f, dc11704ef7 (each built in 778 to 779 s); control `julia-next`
d8f65ef1ea. Library `wt/w158b-tw` `w158f` (3c2dc6b at the last two), TraitDifferentialEquations `unified` 3a1c4c3,
project `env_demo_d`, depot `agent-depots/w158`. `--trim=safe`, `VERIFY=1` for the ODE programs, one thread, one Julia
job at a time; load (1 min) 2 to 12 of 128.

| | d8f65ef1ea | 6d5480e347 | b22ab12a1f | dc11704ef7 |
|---|---|---|---|---|
| the ODE program, trimmed (`logs/w166c-f-ode-<build>.build.log`) | 12 errors in 4 statements (`port/logs/w166c-w158p-main-d8f65ef.build.log`) | 0 errors, 4,279,752 bytes; the binary raises `MethodError` at Robertson (hole 1) | 0, 4,359,416 bytes; runs, output equal to a session's | 0, 4,368,176 bytes, 4 rounds; runs, output equal (`logs/f-ode-dc11704.{bin,session}.out`) |
| the program with callbacks it knows (`apps/ode_cb`) | not built (36 on 8b35e4b77c) | 26 in 6 statements: 20 the records' constructors, 6 the box's `@const` test of a write | 20 in 4 statements (library 3c2dc6b) | 20 in 4 statements, 5 rounds (`logs/w166c-f-odecb-dc11704.build.log`) |
| the ODE program's check in the session (`f-probes/ode_members.jl`) | 6 errors, 4 rounds, 8.4 s (`logs/f-ode-members-before-d8f65ef.log`) | 0, 4 rounds; `Solvable{Float64}` no member | | 0 errors, 4 rounds, 8.9 s (`logs/f-ode-members-dc11704.log`) |
| `apps/f-free.jl`, `f-bare.jl`, `f-union.jl` | 2, 16, 6 errors (`logs/f-before-d8f65ef-*.build.log`) | | 0, 0, 0; run, equal | 0, 0, 0; run, equal (`logs/f-apps-dc11704.log`) |
| `apps/f-result.jl` | 0 errors; the binary raises `MethodError` (hole 1) | | 0; runs, equal | 0; runs, equal |
| `apps/f-gapfn.jl`, `f-gap.jl` (a value not counted) | 0, 0; `gapfn` prints double's answer (hole 2), `gap` runs (`Get` a member of every signature) | | 0, 0; both print double's answer (hole 2) | 0, 0; both raise `MethodError` (G1) |

**The ODE program's members** (the build's report and the check, dc11704ef7, the same nine set types and the same
members): the right-hand side's `Callable{Tuple{Vector{Float64} ×3, Float64}, Nothing}`: `lorenz!`, `robertson!` (2,
was 5 with the three getters); the box's intersection `All{…}`: `PartialFn{typeof(lorenz!), …}`, `PartialFn{typeof
(robertson!), …}` (2, was 8); `Solvable{Float64}`: `LU{Float64, Matrix{Float64}, Vector{Int64}}` (1, was 0);
`LinearSolver`: `DenseLU`; `StepCallback`, `StepEvent`: one each; `StepView`: the two integrators; `Callback`,
`EventCallback`: none. No split is made at bare `Callable`: C-152's "12 against 7" is gone with the getters' branch.

**The program with callbacks: the 20 errors left,** 4 statements, each reached by `solve`'s and the problem's callbacks:
- `FunctionCallback{U,T,P}(c, a, i)` (`ODECore/src/core.jl:604`, 8) and `FunctionEventCallback{U,T,P}(c, a, an, i)`
  (`:620`, 8), the records' outer constructors, called from `_enter_callback!` with the fields of SciML's records,
  `DiscreteCallback` and `ContinuousCallback`, typed bare `Callable` (open issue 159); and in their forwarders the
  box's test `hasmethod(f, A)` (`_first_unmet`, 2, and `to_tuple_type`, 2) at a value known only by a signature.
- The rule that should serve them: compiler §7.6, "With several such arguments the call branches over each: the
  branches are the product of their members, taken in order while it stays within the bound of 64 branches; an
  argument past it is left as it is." Bare `Callable` has 9 members by use here (the five callback functions,
  `lorenz!`, `PartialFn{typeof(lorenz!), …}` and two boxes): 3 arguments give 729, 4 give 6,561. The first argument
  is split (9), the others are left at bare `Callable`; the forwarder then runs at the signatures, where the box's
  test and `typeof(c)` cannot be folded (third part, "Past 64 members, or past the product's bound, the forwarder
  would run at the set instance and the test stays unresolved: not built, not met": met here).
- Not the port departing: the records keep their functions at bare `Callable` by open issue 159's choice, and the
  program gives its callbacks as a tuple (open issue 184 (a)).
- The session's check counts 10 of them (`logs/f-odecb-members-dc11704.log`: 4 at each constructor, 2 `_hasmethod`);
  the build's verifier counts the `to_tuple_type` statement too and each error per frame. Members: equal at each of
  the eleven set types (the report listed two boxes at `Callback` and `EventCallback` that are no members of their
  type; dc11704ef7 lists the members of the set's type, as the check does).

**The tests added** (library `w158f`, `test/verify.jl`; each fails without its change):

| testset | fails on | with |
|---|---|---|
| `closed check: a member of every instance is a member by use; the call of bare Callable` | julia-next: 5 of 7 (`Far11` a member at `F11`, 1 error; bare `Callable`'s call, 4 errors, no members) (`logs/f-verify-before-d8f65ef.log`) | 8d8994b5fc |
| `closed check: a method at a union of records is chosen by the member's type` | the session patched without `closed_choosing_type`: 3 errors (`logs/f-verify-patch1-no247.log`) | 6d5480e347 |
| `a default's method reads a box's object` | `unified` 82959cf: the lowered code has no `getfield(d, :object)` (`logs/f-box-default-before-82959cf.log`) | library 9163b9c |
| `closed check: an operation's results are forgotten at its declared result` | 6d5480e347: `Fact14` has no member (`logs/f-verify-6d5480e.log`) | b22ab12a1f |
| `closed check: a declared field written at a box` | the library without 3c2dc6b's `src` change: 5 errors (`logs/f-verify-write-before.log`) | library 3c2dc6b |

Hole 2 has no test in the library: the check in a session lists errors and members, not what a dropped call returns;
`apps/f-gapfn.jl` is its test (a trimmed build).

**Checks on dc11704ef7** (library 3c2dc6b; load 2 to 9 of 128; logs `logs/f-<check>-dc11704.log`; the same on
b22ab12a1f, `-b22ab12`):

| check | result |
|---|---|
| the gates (`LIB=wt/w158b-tw`) | 73 of 73, stage gates 9 of 9 |
| Base's core, subtype, Compiler/inline, Compiler/inference | SUCCESS |
| the library | 108 testsets (103 and the five above), no failure |
| TraitDifferentialEquations' suite (`env_demo_d`) | 35 testsets |
| TraitTables' (`env_tables_b`), TraitMakie's (`env_demo_d`) | 3 and 8 testsets |
| the table's, report's, plot's programs, trimmed (`f-builds.sh`) | 0 errors each; table 2,724,552 bytes, output equal; report 5,392,904 bytes, output and PNG equal; plot 4,951,832 bytes, output and PNG equal (`logs/f-builds-dc11704.log`) |
| E-384's eight small programs (`small.sh`) | build, run, output equal (`logs/f-dc11704-small.log`) |
| the parts' small programs (`f-apps.sh`) | `e-boxcall`, `e-ctor2`, `e-twochoice`, `choice`, `flow`: 0 errors, run, equal; this part's: the table above |
| the sessions (`sessions.sh`, `ENVD=env_demo_d`, a warm-up and 3 runs) | report 24 compiles, table 19; instances TraitWorld 474 and 413, TraitTables 129, TraitCSV 34, TraitMakie 323: as on 9e742cd3cd with the library `w158e` (third part) (`logs/sessions-f-dc11704.log`) |

- The library's suite is run as the parts before ran it, `-e 'using TraitWorld; include("test/runtests.jl")'`: run as
  a script, `Dynamic` is not visible in `Main` and six checks of `messages.jl` that match `Dynamic{…}` in a message see
  `Core.Dynamic{…}` (the same on `julia-next` with `unified`; not kept).

**Not done.**
- The program with callbacks' 20 errors (above): a rule as written that does not serve it. Not built: the forwarder's
  boxing per argument (each argument's test and box made per its own members: 9 + 9 + 9 branches, not 729) needs the
  forwarder's box test `isa(x, Union{Dynamic, Compiled})` to branch over the members, and the forwarder makes its box
  with `new` in its body, not by a call, so that code compiled by facts knows it (erasing.jl); a narrowing of the test
  by the members alone would be unsound for a value the build did not count.
- `x isa Dynamic` at a box's own type is not folded in inference (`positive_fold_blocked`: the answer is read as
  resting on a membership). Found, not changed; the default's method tests `Dynamic{<:X}`.

## A function kept as itself: the result's check; the owner-only pirate's messages (W-158), 2026-11-21

Two deviations the teaching's new examples met: compiler C-157 (`tutorial.jl` §14, `passes`) and traits T-160
(§16, `Meddler4`). Julia `julia-next` dc11704ef7, read only; the library `wt/w158g-tw`, branch `w158l` from `unified`
2d93199; the depot `agent-depots/w158l` before the shared one. One Julia job at a time, niced; load 1.6 to 4.9 of 128.
Logs: `logs/l-*`; probes: `l-probes/`.

**How to run** (after `source $W158/l-probes/env.sh`; from `$LIBL` where the library is used):
```sh
$JN --startup-file=no $W158/l-probes/min4.jl            # piece 1: which check raises, the loop form and `all`
$JN --project=. $W158/l-probes/tutorial14.jl            # piece 1: the same, in the tutorial's own session
[TW=1] [PATCH=1] $JN --project=. $W158/l-probes/hof_scan.jl   # piece 1: the pattern in 15 forms; exits 1 on a hole
$JN --startup-file=no $W158/l-probes/diag6.jl            # piece 1: the source the JIT is given (trace_jit.jl)
MODE=default|strict $JN --project=. $W158/l-probes/oo_messages.jl   # piece 2: every ownership message, both kinds
```
- `l-probes/patch_l.jl` lays the patch (`l-probes/patch/inlining.jl`, julia-next's file changed; the diff:
  `l-probes/patch-l.diff`) over the session's compiler with `cc_patch`, then `Compiler.activate_codegen!()`: the
  runtime infers in the latest world from there, so the code compiled after it uses the patch.
- `l-probes/trace_jit.jl` lays a copy of `add_codeinsts_to_jit!` that keeps the source handed to the JIT for the
  methods named (`TRACE_NAMES`); `diag7.jl` emits LLVM from it, `diag8.jl` disassembles the code that ran.

### 1. Compiler C-157: the check is made in every order; the hole is a call that passes the function on

**What C-157 records is Julia's printing.** `passes(Callable{Tuple{Float64}, Bool}[x -> 1], 2.0)` raises
`TypeError(:typeassert, "", Bool, 1)` in a fresh session with no library, before and after the `all` form
(`min4.jl`, `logs/l-min4.log`), in a trait module with the library (`hof_scan.jl` with `TW=1`, the loop forms), and
in the tutorial's own session after §1–§14 (`tutorial14.jl`, `logs/l-tutorial14.log`). Julia prints every `TypeError` whose expected type is `Bool` as "non-boolean (Int64) used
in boolean context", whatever its `func` (`base/errorshow.jl` 80–81, vanilla's code): plain `1::Bool` and a box's
`TypeError(:Callable, …)` print the same. The JIT is given the source with the assertion
(`Core.typeassert(%39, Bool)`, `trace_jit.jl`), its LLVM has `ijl_type_error` with the `typeassert` string
(`diag7.jl`, `logs/l-diag7.log`), and the machine code that runs tests the result's type tag against `Bool` and calls
`ijl_type_error` (`diag8.jl`, `logs/l-diag8.log`). No order
was found in which the check is not made; nothing to bisect.

**The hole the probes found instead** (`hof_scan.jl`; `logs/l-hof_scan-tw{0,1}-patch0.log`): an element passed on to a
function compiled for the function's own type. `all(t -> t(x), tests)` returns `true` for `x -> 1`, and
`map(t -> t(x), Callable{Tuple{Float64}, Float64}[x -> 1])` returns `[5.0e-324]`: the `Int` 1's bits read as a
`Float64`. 10 of 15 forms, the same with plain `Core.Callable` at `Main` and in a trait module with the library:

| form | julia-next dc11704ef7 | with the patch |
|---|---|---|
| a loop `t(x) && …`, `s += t(x)`, `v[1](x)` | checked (`typeassert`) | checked |
| `count(t -> t(x), v)` | checked (Base's own `::Bool`) | checked |
| `all`, `any`, `filter`, `findfirst` at `t -> t(x)` | **wrong answer** (`true`, `true`, the element kept, `1`) | checked |
| `map`, `sum`, a generator's `sum`, a comprehension at `t(x)`, `Float64` declared | **bits read as `Float64`** (`5.0e-324`) | checked |
| `apply1(v[1], x) ? … : …`, `apply1(v[1], x) + 0.5` (`apply1(t, x) = t(x)`) | **wrong answer** (`"yes"`, `0.5`) | checked |
| `foldl((a, t) -> a + t(x), v; init = 0.0)` | the function's own result (`1.0`): no type trusted | the same |

- **The cause** (`diag9.jl`, `diag10.jl`). The closure's call `f(t)` in `Base._all` has `t` typed
  `Callable{Tuple{Float64}, Bool}`; inference infers the closure at that type, where `t(x)` is asserted to `Bool`
  (compiler §7.4), and takes `Bool`. The inliner leaves the call to dispatch, as plain Julia does for an argument of
  an abstract type (vanilla v1.13.2 the same at `Vector{Function}`). Dispatch runs the closure compiled for the
  function's own type, `typeof(x -> 1)`, where `t(x)` is the function's own call and returns `1`; the caller's code
  reads it as the `Bool` it inferred.
- **The pattern:** inference is not monotone at a declared result whose members' own code is not checked against
  it. Plain Julia's inference at an abstract argument bounds every instance dispatch may run; with `Callable`'s `S`
  it does not, since a function joins every `Callable{A, S}` without a check of its results (traits §9). For a set
  with checked members a member's own method infers within the declared result (traits §5.10), so the same call is
  sound there; for `IO` the declared results are `Any`. The same rule as compiler §7.1's "a const result taken for
  its effects joins its type": compiled code never takes a value its call's type excludes.
- **The fix at the rule** (`l-probes/patch-l.diff`, `Compiler/src/ssair/inlining.jl`, 63 lines added, 1 removed):
  a call the inliner leaves to dispatch, with an argument whose type is, or holds as a union's component or a
  tuple's element, a `Callable{A, S}` (or an intersection of such) that declares `S`, is asserted to its inferred
  type where it returns (`handle_dispatched_result!`, by `handle_declared_result!`), at both places a call stays
  dynamic (`handle_call!` with no case, `handle_cases!` with none). Not covered: a union split's fallback, and a call
  whose inferred type is a constant used by inference before the inliner.
- **The test, before and after** (`hof_scan.jl` exits 1 on a hole): 10 holes, exit 1, without the patch; 0 holes,
  exit 0, with it, at `Main` and in a trait module (`logs/l-hof_scan-tw{0,1}-patch{0,1}.log`). Under the patch the
  library's suite passes, 111 testsets (`logs/l-library-3ba84fc-patch.log`), and the three documentation scripts as
  without it (`logs/l-docs-*-3ba84fc-patch.log`). Not run under the patch: the gates (each runs its own process).

**The message.** The box raises `TypeError(:Callable, ctx, S, r)` (`src/callable.jl` 36, 54), "in Callable, expected
Float64, got a value of type Int64", and for `S === Nothing` the context "end the function with `nothing`"
(traits §9). The compiler's check at a function kept as itself is `Core.typeassert` (inlining.jl
`handle_callable_call!`, `handle_declared_result!`): "in typeassert, expected Float64, …", and no `nothing` hint.
The same message needs the inserted check to raise the box's error: a test `Core.isa(r, S)` and, on its failing
branch, a call of a function in `Core` that throws `TypeError(:Callable, ctx, S, r)`, then `π(r, S)`. A plain call
of such a function in place of `typeassert` would be a dynamic call per call of the function; the branch needs the
inliner to split the block, as its union split does. Not built. For `S === Bool` no form names `Bool`: Julia's
printing (above).

### 2. Traits T-160: the owner-only pirate's messages (TraitWorld 3ba84fc)

Every message of ownership and strict mode, for the two kinds of pirate (`oo_messages.jl`; before
`logs/l-oo_messages-before-{default,strict}.log` on 2d93199, after `logs/l-oo_messages-after-*.log` on 3ba84fc):

| message | kind | 2d93199 | 3ba84fc |
|---|---|---|---|
| `OwnershipError` (`no_pirates`, `_check_pirate`) | owner-only (by default, by `@owner_only`, a trait's unexported operation) | wrong: "owns neither the function nor a type in each of its signatures" | the function, why it is owner-only, its owner, only the owner adds methods; what the owner writes (`public` or export; not `@owner_only`; a joint owner), or a function of your own |
| `OwnershipError` (`no_pirates`) | classic | right, without the owners | names the owners of the function and of the types, and who defines it |
| `PirateError` (strict mode) | owner-only | half: "does not own the function, an owner-only function of …", then "Define it where a type it is for is owned" (wrong); the method printed `weight(Heavy)` | the same text as `OwnershipError`'s; `weight(::Heavy)` |
| `PirateError` (strict mode) | classic | right; `abs2(Float64)` | right; `abs2(::Float64)` |
| the pirate's report (a warning) | owner-only | half: the reason right, "Define it where a type it is for is owned" (wrong) | the reason with why it is owner-only; the owner's text |
| the pirate's report | classic | right | unchanged |
| membership messages (`OwnershipError`, `PirateError`, the report, `delete_membership`) | classic only: a trait is no owner-only function | right | unchanged |

- **Side finding:** a trait module's trait whose operation it does not export is closed to other modules' members:
  `@implement OShape Sq begin oarea(q) = … end` in another trait module is refused as a pirate (the operation is
  owner-only). The message now says what the owner writes.
- The library's test `test/owner_only.jl`, testset "the messages at an owner-only function's pirate": 20 checks;
  on 2d93199's `src` 14 fail (`logs/l-owner_only-test-before-2d93199.log`).
- The messages' tool (`messages/cases.jl`, seven cases added: owner-only in a trait module, by `@owner_only`, a
  trait's unexported operation in a block, the classic one, at the prompt reported, and in strict mode for both
  owner-only forms): 143 distinct messages, every form 0 (`logs/l-messages-after-scan.txt`). The scan does not
  catch a signature printed without `::` (`weight(Heavy)`, found by reading).
- `docs-examples/tutorial.jl` §16: the deviation T-160 is a check.

### The checks, TraitWorld 3ba84fc

| check | result |
|---|---|
| the library (`-e 'using TraitWorld; include("test/runtests.jl")'`) | 111 testsets, no failure, 28 s (`logs/l-library-3ba84fc.log`) |
| the documentation's examples | intro 33 pass; tutorial 123 pass, 1 deviation (compiler C-157); strict 10 pass (`logs/l-docs-*-3ba84fc.log`) |
| the gates (`LIB=wt/w158g-tw run_all.sh julia-next`) | 73 of 73, stage gates 9 of 9 (`logs/l-gates-3ba84fc.log`) |
| the messages' tool | 143 distinct messages; tuple type, generated name, compiler object, library internal: 0 (`logs/l-messages-after-*`) |

## Fifth part: a program with callbacks, 2026-11-21

**The question** (E-510, continued; compiler C-156; open issues 184, 159, 245): compiler §7.6's sentence "Where the
product is past the bound and the method the members reach is a forwarder (§6.3), each argument is boxed apart, a
branch over its own members that makes its box, and the method as written is called once at the boxes", built, so
that the ODE program with callbacks it knows (`port/apps/ode_cb.jl`: 20 errors in 4 statements on dc11704ef7) builds,
runs and prints a session's output; and in a form that keeps the forwarder's body as §6.3 writes it for code compiled
by facts, and costs a session nothing. What would change the design: a form that a session pays for, a value the
build did not count that gets an answer, or a case the rule cannot serve.

**How to run** (after `source env.sh` of this directory; `J=$TW_ROOT/wt/w158-julia/julia`):

```sh
[APP=apps/ode_cb] bash i-probes/ode_build.sh <label>           # the ODE program (or the one with callbacks) trimmed, run, compared
(cd i-probes && APP=<file> [PATCH=1] $J --project=../env_demo_d members.jl)        # the build's check in a session
(cd $TW_ROOT/wt/w158b-tw && APP=<file> [PATCH=1] FN=<f> $J --project=. $W158/i-probes/instances.jl)   # a function's instances after the check
(cd $TW_ROOT/wt/w158b-tw && $J --project=. $W158/i-probes/undefined.jl)            # the bounded check at a name never defined
bash i-apps.sh <label> <tree> [app ...]      # apps/i-*.jl and the parts' programs: session, trimmed, run, compare
bash i-checks.sh <label> [tree] [step ...]   # f-checks.sh's steps, logs logs/i-<step>-<label>.log
```

- `i-probes/patch_i.jl` lays this part's compiler change over a session of dc11704ef7 (`PATCH=1`). It reaches a
  session's check (`closed_check`), not a trimmed build's own inference: a build of the program with the patch
  included first gave the same members and code as without it (a line printed where the change is taken printed
  nothing), so every build number below is of a built Julia.

**What was built.** Julia `wt/w158-julia`, branch `w158`: f1d6e51efa on dc11704ef7 (`Compiler/src`: 93 lines added,
4 removed). The library `wt/w158b-tw`, branch `w158i` from `unified` 2d93199 (`src/erasing.jl`: 25 added, 6 removed):

| tree | commit | what |
|---|---|---|
| library | 8ebfc7a | a forwarder with several arguments that erase boxes each by its own call, `_forward_box(D, x, self, args)`: a method at the kept forms passes one as it is, the other tests a function's signature (`_callable_box_check`) and makes the box by `new`; inlined where the forwarder is compiled per member type. The forwarder of one such argument (compiled once at the set) keeps `new` in its body |
| julia | f1d6e51efa | past the product's bound, where a matched method carries the forwarder's mark (`Expr(:meta, :erasing_forwarder)`) and every other matched method is at kept forms wherever the forwarder's type names a set (`closed_forwarder`), the call is the forwarder's instance at the call's types met with its signature (`closed_forwarder_call`): a closed split with one case, so the inliner tests each argument against the forwarder's type, invokes the forwarder, and past it raises `MethodError` |
| library | 074feba | tests: `test/verify.jl` "closed check: past the product's bound, the forwarder boxes each argument apart"; `test/bytype.jl`: the forwarder of two arguments makes both boxes by `new` at members' types, no call left |
| library | 1545423 | `test/messages.jl`: the bounded check's module imports `marea` (below) |

**The mechanism.** In the forwarder at the signatures each `_forward_box` call is a call where the member's type
chooses the method (a method at the kept forms beside one at any value), so a closed build branches there over that
argument's members, each branch the call at the member's type, where the box's test `hasmethod(f, A)` folds; past
them `MethodError`. The call at the boxes (`#self#(b2, b3, b4)`) is then at concrete boxes: the method as written,
once. In a session the forwarder is compiled per member type, `_forward_box` is inlined, and the code is the one the
body made before (`%new(Dynamic{Shape}, a)`, `bytype.jl`); a value outside the forwarder's type fails the test
before the forwarder and raises `MethodError`, as dispatch does.

**The program with callbacks** (`logs/w166c-i-<label>.build.log`, `logs/i-<label>.kinds.txt`; `--trim=safe`,
`VERIFY=1`, project `env_demo_d`, depot `agent-depots/w158`, one thread; load 2 to 5 of 128):

| Julia | library | errors | binary |
|---|---|---|---|
| dc11704ef7 | 3c2dc6b (fourth part) | 20 in 4 statements (`logs/w166c-f-odecb-dc11704.build.log`) | none |
| dc11704ef7 | 2d93199 with 8ebfc7a's `src` (uncommitted then; the log names 2d93199) | 0 (`odecb-libonly-dc11704`) | 4,497,120 bytes; output equal to a session's |
| f1d6e51efa | 2d93199 | 4 in 2 statements: the box's test `hasmethod` and `to_tuple_type` in the forwarder at the signatures (`odecb-f1d6e51-lib2d93199`) | none |
| f1d6e51efa | w158i 1545423 | 0, 5 rounds, `verify_main` 5.6 s (`odecb-f1d6e51`) | 4,139,104 bytes; runs, `lorenz with callbacks 12.5265`, equal to a session's |

- The library's change alone serves the program by the product rule as it stood: the first argument split over its
  7 members, the forwarder compiled per member of it, and in each the other arguments boxed apart (7 forwarder
  instances). With both, the forwarder runs once, at the signatures: 358,016 bytes less.
- Bare `Callable` has 7 members by use (9 on dc11704ef7: the two boxes were forgotten at the forwarder's join of its
  kept and boxed branch, which `_forward_box` no longer makes).
- The session's check of the program (`i-probes/members.jl`): 0 errors, 5 rounds, 9.3 s (`logs/i-odecb-members-f1d6e51.log`;
  10 on dc11704ef7). The ODE program without callbacks: 0 errors, 4,360,272 bytes, output equal
  (`logs/w166c-i-ode-f1d6e51.build.log`); its check 0 errors, 4 rounds (`logs/i-ode-members-f1d6e51.log`).

**The small programs** (`apps/i-*.jl`; `logs/i-apps-f1d6e51.log`, build logs `logs/i-f1d6e51-<app>.build.log`):

| program | dc11704ef7 | f1d6e51efa, w158i |
|---|---|---|
| `i-ctor3`: a constructor at three `Callable` signatures, values known only by bare `Callable`, 15 members each | 15 errors (`logs/i-before-dc11704-ctor3.build.log`, library 2d93199); 0 with 8ebfc7a's `src`, 2,285,120 bytes (`i-libonly-ctor3`) | 0, 2,206,824 bytes; runs, equal; one forwarder instance, at the signatures (`i-probes/instances.jl`) |
| `i-gap3`: a fourth function at the first argument reached only as the 4,097th element of a constant | (8ebfc7a's `src`) 0 errors; the binary raises `MethodError` | 0; the binary prints `gap MethodError`, the session `gap 6.0` (G1: an error, never another member's answer) |
| `i-mixed3`: boxes given beside plain functions, a box of another signature | 4 errors with 8ebfc7a's `src` (`i-libonly-mixed3`) | 0, 2,218,936 bytes; runs, equal (the box of another signature: `MethodError`, as in a session) |
| `i-wrap3`: a wrapper (`compiled_for`) given through the field typed bare `Callable` | | 4 errors: the wrapper is a member by use of every signature, so the call at the boxes has 2 × 2 × 2 combinations of kept forms, past Julia's union split of 4, left to dispatch; so is the call at its result |
| `i-param3`: the record parametric in its functions' types (traits §8.2's form) | | 0, 2,164,832 bytes; runs, equal: no split at bare `Callable` is made |

The parts' programs (`f-*`, `e-*`, `choice`, `flow`): 0 errors each, run, equal; `f-gap` and `f-gapfn` raise
`MethodError` where the session answers, as in the fourth part.

**The port's form** (traits §8.2: "A record made before a signature is known keeps each value in the form given …
The constructor that knows the signature boxes `f` and keeps `j`"; its example, `ODEFunction{F, TJ, TMM}`, keeps each
function's type as a parameter). ODECore's `DiscreteCallback` and `ContinuousCallback` keep their functions in fields
typed bare `Callable`, read back as values known only by bare `Callable` (§8.1's row "a field `::X`": "a call on it
dispatches by its type"). A record parametric in its functions' types, `DiscreteCallback{C, A, I}` (upstream's
`DiscreteCallback{F1, F2, F3, F4}`), keeps the form given and its type: `_enter_callback!` is compiled per record
type and calls the constructor's forwarder at the functions' own types. That removes all 20 errors with no compiler
rule (`i-param3`), at a compile of `_enter_callback!` per record type in a session. The port does not depart from a
reference: §8.2 states the form given, not where the type is kept. Both hold: the compiler's rule serves records typed
by a trait (and a vector of mixed records, open issue 245), the parametric record serves a program that makes its
callbacks where their functions are known.

**Is the product's bound the right rule?** Where the method the members reach is no forwarder, the call's meaning is
the product: a call with three arguments of 9 members each may take another method at each of the 729 combinations,
so the bound stands and the verifier refuses past it. The forwarder's call separates because each argument's box
depends on that argument alone and the call at the boxes is one call; the build finds that structure by the
forwarder's mark and the shape of the other methods, not by a name. No other call past the bound is met in the
ports' programs: the table's, report's, plot's and both ODE programs build with 0 errors.

**The bounded check at a name never defined** (`test/messages.jl`'s `mfvok`; `i-probes/undefined.jl`,
`logs/i-undefined-f1d6e51.log`). The testset's module imported `MShape` only, so `mvaok`, `mfv` and `mfvok` called
`marea`, a name it never defines; the check read the call as left to run time and accepted `mfvok` without reading
the operation's call at a box. Fixed by importing `marea` (1545423). Traits §7.3's "When": a method that names a
global not yet defined waits for it, "and at last for its module's end". The code (`_decide_bounded(m; final =
true)`) then reads the method once more; a name still undefined is a global whose value is unknown, the call is left
to run time, and the method is accepted (`f(a::UShape) = nothere(a)`: accepted). The reference does not say what
such a call is at the module's end; under §7.3's fault "finds no method at the types the code knows … or left to run
time" it is a fault (no value, so no method), and the code does not follow that reading. A name defined later with
no method at the box is refused at its definition; with one, accepted.

**Checks on f1d6e51efa** (library w158i 1545423; logs `logs/i-<check>-f1d6e51.log`; load 3 to 5 of 128):

| check | result |
|---|---|
| the gates (`LIB=wt/w158b-tw`) | 73 of 73, stage gates 9 of 9 |
| Base's core, subtype, Compiler/inline, Compiler/inference | SUCCESS |
| the library | 111 testsets (110 and the new one), no failure; the new testset fails on dc11704ef7 (2 of 5: no instance at the signatures, 15 per member of the first argument; `logs/i-verify-before-dc11704.log`) |
| TraitDifferentialEquations, TraitTables, TraitMakie | 35, 3, 8 testsets |
| the table's, report's, plot's programs (`i-builds.sh`) | 0 errors each; table 2,724,688 bytes, output equal; report 5,394,176 bytes, output and PNG equal; plot 4,952,200 bytes, output and PNG equal (`logs/i-builds-f1d6e51.log`) |
| E-384's eight small programs | build, run, output equal (`logs/i-f1d6e51-small.log`) |
| the parts' programs and this part's (`i-apps.sh`) | the table above (`logs/i-apps-f1d6e51.log`) |
| the sessions (`sessions.sh`, a warm-up and 3 runs) | report 24 compiles, table 19; instances TraitWorld 468 and 407, TraitTables 129, TraitCSV 34, TraitMakie 323; the same on dc11704ef7 and on f1d6e51efa with the library 2d93199 (`logs/sessions-i-f1d6e51.log`, `-i-f1d6e51-lib2d93199.log`, `-i-dc11704-lib2d93199.log`); TraitWorld has 803 methods against 801 (`_forward_box`'s two) |

**Not built, not verified.**
- A wrapper among an argument's members (`i-wrap3`): the call at the kept forms is past Julia's union split. A split
  of a union of kept forms up to 64 in a closed build was tried in a session and dropped: the 8 results join to
  `Trip`, and the call at that is left to dispatch again (a wrapper is compiled per object type, as in plain Julia).
- The forwarder is found by its mark in the method's code, read by `closed_is_forwarder`; a method whose source an
  image strips (`--strip-ir`) is no forwarder to the build (the product rule then applies).
- The method lookup the forwarder's case records spans all worlds (a closed build invalidates nothing); a session's
  check takes the same path.

## Sixth part: a declared result across dispatch (compiler C-157), 2026-11-22

**The question** (compiler §7.4, C-157; open issue 253): the rule "compiled code never takes a value that its call's
type excludes", built completely. An element of a `Vector{Callable{A, S}}` is a function kept as itself, known only by
the signature. Inference reads code that takes it at the signature, where its call is asserted to `S`; dispatch runs
that code compiled for the function's own type, where the call is the function's own. So a callee's result at the
signature can be narrower than what the instance that runs returns: inference is not monotone at a declared result
whose members' own code is not checked against it. What would change the design: a place the rule cannot reach, a
cost to plain code, or a mechanism that needs a test of the argument types' shape.

Julia `wt/w158-julia`, branch `w158`: f1d6e51efa, then 3211d10d60, 42657e9dbd (built), 85bd884a57 (built). The
library `wt/w158b-tw`, branch `w158m` from `unified` 7c3b07d (tests only: e65c29b, 15070de). The depot
`agent-depots/w158` before the shared one. One Julia job at a time, niced; load 2 to 15 of 128. Logs `logs/m6-*`
(and the scripts' own names `logs/i-*-m6*`, `logs/w166c-i-m6*`, `logs/sessions-m6-*`); probes `m-probes/`.

**How to run** (after `source env.sh`; `J=$TW_ROOT/wt/w158-julia/julia`):
```sh
$J --startup-file=no m-probes/forms.jl                                    # 29 forms at Main; exits 1 on a hole
(cd $TW_ROOT/wt/w158b-tw && TW=1 $J --project=. $W158/m-probes/forms.jl)  # 71: in a trait module, boxes, wrappers, an operation
(cd $TW_ROOT/wt/w158b-tw && $J --project=. -e 'include(ARGS[1]); include(ARGS[2])' $W158/m-probes/mutant.jl <gate>)  # the rule's checks taken out
$J --project=env_demo_d m-probes/count.jl ../w135/apps/report.jl <csv> <png>   # what a session's code holds of the rule
bash m-checks.sh <label> [tree] [step ...]                                # i-checks.sh's steps (and Compiler/effects), logs m6-
bash i-apps.sh <label> wt/w158-julia m-trusted                            # apps/m-trusted.jl: session and trimmed, compared
```

### 1. The invariant, and every place that can break it

**The invariant.** Where inference gives a call a type that rests on a declared result its members' own code is not
checked against, and the code that runs may be another instance than the one inferred, the call's result is checked
against that type. Such declared results: a `Callable{A, S}`'s `S` (every function is a member, none is checked);
an operation's result at an argument the members' check does not infer at (traits §5.10: a further argument declared
at a type that is not concrete). Not: an operation's result at checked argument types (a member's own method infers
within it, §5.10, so its instance is monotone), a declared field (checked at the membership), `IO`'s results and a
closed type's contract (`Any`: nothing narrower is trusted), a method's own `f(…)::RT` (its body asserts it in every
instance).

The scan (`m-probes/forms.jl`; a function `x -> 1` where `Bool` or `Float64` is declared; at Main with plain
`Core.Callable`, and in a trait module with the library). f1d6e51efa: observed in this part's first runs, before the
build replaced that binary; the logs were not kept. The mutant (`m-probes/mutant.jl`, the inliner's checks taken out
of the session's compiler on the built head) gives the same holes and is kept: `logs/m6-gate-n35-mutant-85bd884.log`.

| form | f1d6e51efa | 85bd884a57 | the place, and what closes it |
|---|---|---|---|
| `t(x)` in a loop, `v[1](x)` | checked, `typeassert`'s message | checked, the box's | the call itself (§7.4): `Core._callable_result` |
| `all`, `any`, `filter`, `findfirst` at `t -> t(x)` | **wrong answer** | checked | a call left to dispatch, no case: the check after it |
| `map`, `sum`, a generator, a comprehension (`Float64`) | **`5.0e-324`** | checked | the same (the element type `map` gives is the first value's type, read from the call) |
| `apply1(v[1], x) ? … : …`, `+ 0.5` | **wrong answer** | checked | the same |
| a union split's fallback (`Nothing \| Callable`) | **wrong answer** | checked | the fallback's check (`ir_inline_unionsplit!`) |
| a split's case at a method that does not specialize | not run | checked (on 42657e9dbd: **wrong answer**) | the case's check where its instance's types are wider than the case's |
| a constant result (`t(x) isa Bool`) | **wrong answer** (`"yes"`) | own (`"no"`) | a marked call's result is its type alone: no constant taken |
| a result `Union{}` | **stops at `unreachable`** | checked | the check after the call (it raises) |
| two levels up (`lvl2(t, x) = apply1(t, x)`) | **wrong answer** | checked | the mark carried to the caller, through a call at argument types that are not concrete |
| a struct's field (`Holder{<:Callable}`), a tuple | **wrong answer** at Main | checked | the same: no test of the argument types' shape |
| a closure's capture, a splat (`_apply_iterate`), `invokelatest` | own | own | nothing trusted: the closure and the splat are inferred at their own types; the latest world is `Any` |
| `Core.invoke` at the signature | **wrong answer** | checked | a builtin's call that stays one: the check after it |
| `@nospecialize` (an invoke of the instance at `Any`) | **wrong answer** | checked | an invoke at wider types than the call's: the check after it |
| an invoke of the instance at the call's types, an inlined body | sound | sound, no check | the code that runs is the code inferred |
| two methods take the call (`t::Function`, `t`) | own | own | inference joins both: nothing narrower |
| `Base.promote_op(f, eltype(v))` | `Float64` | `Float64` | a value computed by inference (facts §7); not a hole: a call filled by it is checked |
| an operation's result at a further argument declared abstract, passed on | **wrong answer** | checked (`typeassert`) | the same mark, `TRUSTED_OPERATION` |
| the box | checked | checked | its call method |
| the wrapper, an element of a `Vector{Callable{A, S}}` | **holes as the function** | checked or own as the function | it is known only by the signature there |

(85bd884a57: `logs/m6-forms-tw0-85bd884.log` 0 holes in 29 forms, `logs/m6-forms-tw1-85bd884.log` 0 in 71.)

### 2. The mechanism: the trusted effect and the check where another instance runs

- **A mark carried as effects are.** `Effects` gains `trusted::UInt8` (`TRUSTED_CALLABLE`, `TRUSTED_OPERATION`; stored
  in the encoded effects' bits 16 and 17, zero meaning nothing trusted). A `Callable{A, S}`'s call (`S` not `Any`) and
  an operation's call whose entry has a second argument that is not concrete set it; it merges into the frame's
  effects and the instance's, and a caller's call takes the callee's. At a call whose argument types are concrete the
  instance inferred is the one that runs: the mark stops there (`abstract_call_gf_by_type`). A marked call's result
  is its type alone (`widenconst`). A closed build marks nothing: no call is left to dispatch (§7.6).
- **The statement carries the mark** as two IR flags (`IR_FLAG_TRUSTED_CALLABLE`, `_OPERATION`, bits 21 and 22), set
  and cleared with the effect flags by inference's own mask. The inliner, after it has handled a marked call
  (`check_trusted_result!`), checks the result against the call's type where the code that runs may be another
  instance: a `:call` left (no case, no method found, a builtin such as `_apply_iterate` or `Core.invoke` that stays a
  call), an `:invoke` of an instance whose types are wider than the call's, a split's fallback, a split's case at such
  an instance. An inlined body and an invoke of the instance at the call's types are not checked.
- **The check:** for a `Callable`, `invoke Core._callable_result(r, T)::T` (base/boot.jl; compiled into the system
  image by a `precompile` in base/loading.jl): the box's `TypeError(:Callable, ctx, T, r)`, with "end the function
  with `nothing`" where `T` is `Nothing`. The same function checks the direct call of a function known only by its
  signature (it was `typeassert`) and a closed build's split of such a call (each branch). An operation's result keeps
  `typeassert`'s, as the operation's own call asserts.

**Against the other candidates.**
- (a) as the patch of the fifth part made it (`l-probes/patch-l.diff`), a test of the argument types' shape (a
  `Callable` argument, a union's component, a tuple's element): it misses a function in a field (`Holder{<:Callable}`
  was a hole at Main), a widened invoke, `Core.invoke`, the constant and `Union{}` results, two levels up, and an
  operation. The mark is decided by inference where the trust is taken, and reaches every caller whose instance can
  differ: there is no place to forget but the sinks, and those are the inliner's few outcomes.
- (b) inference not trusting the declared result across a call dispatch may re-specialize: inference does not know
  whether the inliner will inline, invoke or leave the call, so the result would be `Any` for every marked call at
  argument types that are not concrete, inlined ones included. That loses types where the code inferred runs. Built
  as stated it is (a) with the check made by the caller; the part of it that is right is built: a marked call's result
  is its type alone, never a constant, a field's type or a condition read from the instance at the signature (the
  constant form: (a) without it would need a check of equality).
- (c) the function never passed on as itself (boxed at a call left to dispatch): it reaches the direct argument only,
  not a field, a capture or a tuple, and changes what `t === iszero` sees downstream. Not built.

### 3. What a session pays, counted

| session (85bd884a57) | instances | trusted | checks at a direct call | after a call that passes one on | flagged calls |
|---|---|---|---|---|---|
| the report (TraitCSV, TraitTables, TraitMakie) | 84,927 | 2 (`TRUSTED_OPERATION`: TraitMakie's `setcolor!`, `recolor!`) | 0 | 0 | 1 |
| the table (TraitCSV, TraitTables) | 76,390 | 0 | 0 | 0 | 0 |
| the ODE program with callbacks | 83,359 | 12 (TraitNonlinearSolve 9, TraitRodas 2, ODECore 1; all `TRUSTED_OPERATION`) | 0 | 0 | 15 |

(`m-probes/count.jl`, `logs/m6-count-85bd884.log`: every instance's effects, complete; the checks and flagged calls
are read from the optimized code an instance keeps, which Julia keeps only for code it may inline: an undercount.
The checks the compiler makes while a session infers, with every package inferred in it (`m-probes/count_checks.jl`,
`--compiled-modules=no`, `logs/m6-count-checks-85bd884.log`): the table, 10, all an operation's split's own
`typeassert` (made as before, now through the same function), none of a `Callable`'s and none after a call that
passes a value on; the ODE program does not load from source (`_contracts_of` not defined, the library's), so it is
not counted that way.)

- **Plain code pays nothing:** nothing in it declares such a result, so nothing is marked; `Effects()` and every
  builtin's effects carry no mark.
- **The sessions' compiles are unchanged:** report 24 compiles, table 19 (`logs/sessions-m6-85bd884.log`, a warm-up
  and 3 runs, as on f1d6e51efa). The instances: TraitWorld 473 and 412, TraitTables 129, TraitCSV 34, TraitMakie 323;
  against 468 and 407 on f1d6e51efa with the library w158i 1545423. The library differs (807 methods against 803:
  3ba84fc, T-160's messages, merged into `unified` after the fifth part's measure); no control with 7c3b07d on
  f1d6e51efa was run (that binary was rebuilt). The rule marks two instances there and checks none.
- **Trait code pays** an `isa` test and an invoke of a compiled function at each check, only where a value known by
  an unchecked declared result is passed to code left to dispatch; and a constant, a field's type or a condition of a
  marked call's result at argument types that are not concrete.
- **Code size:** `_callable_result` is one function in the system image; a check is one statement.

### 4. The wrapper, the box, and a closed build

- **The box** checks its result in its call method, however it is called: every form checked, "in Callable".
- **The wrapper** (`compiled_for(x -> 1)`) is the function (GT-24). Passed as itself, its calls are the function's own
  and a caller trusts nothing but what inference reads at the wrapper's own type: `apply1(compiled_for(x -> 1), 2.0)`
  is `1`. Kept in a `Vector{Callable{A, S}}` it is an element known only by the signature, and had the function's holes
  (the same 9 forms on f1d6e51efa); with the rule it is checked as the function is. The entry check (a result inferred
  at `A` that can be an `S`) does not make its result an `S`; nothing trusts it to be one.
- **A closed build** branches over the signature's members at each call of such a function (§7.6), each branch's
  result checked: no call is left to dispatch, so nothing is trusted and nothing is marked. `apps/m-trusted.jl`
  (17 forms, the operation's included) builds with 0 errors, 2,416,808 bytes, and prints what the session prints,
  the check's name included: "in Callable" at each branch (a closed split's check is now the box's), "in typeassert"
  at the operation (`logs/i-apps-m6-85bd884.log`, `logs/m6-m-trusted-session-42657e9.out`). The forms with the
  function in a struct's field or a closure's capture are not in it: a closed build joins those records at their
  bare type and leaves the call unresolved (60 errors with them, `logs/i-m6-42657e9-m-trusted.build.log`, most of
  them the program's own printing of an `Any`). A constant read at the signature is the function's own answer in a
  session where the call is left to dispatch and raises where the body runs at the signature (inlined, or a closed
  build): both are G1's "identical or error", the program does not print it.

### 5. What was built

| tree | commit | what |
|---|---|---|
| julia `w158` | 3211d10d60 | the `trusted` effect (two bits), its IR flags, the marks at a `Callable`'s call and at an operation's call its members' check does not reach, the mark stopped at concrete argument types and a marked call's result its type alone, the inliner's check after a call left to dispatch, a builtin's call, an invoke at wider types and a split's fallback; `Core._callable_result` (the box's `TypeError`) at those and at a direct call; precompiled into the system image |
| julia `w158` | 42657e9dbd | a closed build's split of a `Callable`'s call checks each branch with the box's `TypeError` |
| julia `w158` | 85bd884a57 | a split's case at an instance of wider types checked (a hole on 42657e9dbd); the trusted flags apart from `IR_FLAGS_EFFECTS` (a removed statement got them) |
| library `w158m` | e65c29b, 15070de | `test/trusted.jl`: three testsets (the forms, the controls, the operation) |
| experiments | this commit | `gates/n35_trusted_result.jl` and its entry; `m-probes/` (`forms.jl`, `mutant.jl`, `count.jl`, `count_checks.jl`); `apps/m-trusted.jl`; `m-checks.sh`; logs |

`Compiler/src`: 223 lines added (168 not comments or blank), 32 removed; `base/`: `_callable_result` (5 lines with its
comment), its `precompile` (4).

### 6. The checks, 85bd884a57 (library w158m 15070de)

| check | result |
|---|---|
| the gates (`LIB=wt/w158b-tw`) | 74 of 74 (73 and `n35_trusted_result`), stage gates 9 of 9 (`logs/m6-gates-85bd884.log`) |
| `n35_trusted_result` without the rule's checks (`m-probes/mutant.jl`) | fails: 47 forms, then the stop at `unreachable` (`logs/m6-gate-n35-mutant-85bd884.log`) |
| Base's core, subtype, Compiler/inline, Compiler/inference, Compiler/effects | SUCCESS each (`logs/m6-base-85bd884.log`) |
| the library | 115 testsets (112 on `unified` 7c3b07d and `trusted.jl`'s 3), no failure (`logs/m6-library-85bd884.log`); `trusted.jl` without the rule's checks stops at `unreachable` (`logs/m6-library-trusted-mutant-42657e9.log`) |
| TraitDifferentialEquations, TraitTables, TraitMakie | 35, 3, 8 testsets (`logs/m6-{port,tables,makie}-85bd884.log`) |
| NetworkDynamics' subset (`w161/suites.sh`'s command, this binary) | 6 files; the two known failures (diffusion 1 fail 1 error, inhomogeneous 1 error), as before (`logs/m6-nd-85bd884.log`) |
| the table's, report's, plot's programs | 0 errors each; table 2,724,880 bytes, report 5,394,008, plot 4,942,968; output and PNGs equal (`logs/i-builds-m6-85bd884.log`) |
| the ODE program, with callbacks | 0 errors each; 4,359,264 and 4,141,008 bytes; outputs equal to a session's (`logs/i-m6-ode-85bd884.kinds.txt`, `logs/i-m6-odecb-85bd884.kinds.txt`) |
| E-384's eight small programs | build, run, equal (`logs/m6-85bd884-small.log`) |
| the parts' programs and `m-trusted` | as on f1d6e51efa: 0 errors but `i-wrap3`'s 4; `i-gap3`, `f-gap`, `f-gapfn` raise where the session answers (`logs/i-apps-m6-85bd884.log`) |
| the sessions | report 24 compiles, table 19; instances above (`logs/sessions-m6-85bd884.log`) |

### 7. Not built, not verified

- **An operation's result its members' check does not reach** is read from the entry: a second argument that is not
  concrete at the call's types. The other cases traits §7.9 names (a method already in the session when an image's
  membership loads, inference's own limits) are not marked.
- **A constant** from `Core.invoke` or a splat is not widened (only the call through `abstract_call_gf_by_type` is);
  their result is checked against its type, not the constant.
- **Within a recursion cycle** a statement takes the cycle's effects, the mark included, without the stop at concrete
  argument types: a check more, never fewer.
- **The before-state on f1d6e51efa** is from this part's runs whose logs were not kept; the mutant is the kept control.
- **The ODE session's checks** were not counted by the in-session counter (the program does not load from source).

## A name never defined; a trait's operation and its members (traits T-161, T-162), 2026-11-22

Two rows of traits' Deviations: T-161 (§7.3, "When": "At its module's end a call of a name the module never defines is
a fault") and T-162 (§12.2: a trait's operation is not owner-only by the default). Julia `julia-next` 85bd884a57
(the binary built 2026-11-22 01:53), read only; the library `wt/w158g-tw`, branch `w158o` from `unified` 15070de; the
depot `agent-depots/w158n2` before the shared one. One Julia job at a time, niced; load 3.3 to 7.7 of 128. Logs:
`logs/o-*` (and the messages' tool's `logs/b-messages-o-46687cb*`); probes: `o-probes/`.

**How to run** (after `source o-probes/env.sh`; `$LIBO` is the library's worktree):
```sh
(cd $LIBO && $JN --project=. $W158/o-probes/undefined.jl)         # piece 1: the bounded check at a name never defined, 20 cases
(cd $LIBO && $JN --project=. $W158/o-probes/undef_ir.jl)          # piece 1: the box instance's code at such a call
(cd $LIBO && $JN --project=. $W158/o-probes/operation_cases.jl)   # piece 2: the cases of the operation's rule
$JN --project=g-probes/env_demo_g o-probes/operations.jl           # piece 2: every operation of the demonstrators' traits
bash o-probes/sessions.sh <tag> [N]                                # sessions.sh with this part's depot and env_demo_g
```

### 1. Traits T-161: a call of a name the module never defines (TraitWorld 114a933)

**What the check read.** The method's instance at the box holds the call as the load of the global and a call left
to dispatch (`%1 = M.nothere::Any`, `dynamic (%1)(a)::Any`; `undef_ir.jl`). The check found methods of `Any` at
`(::Any)(::Dynamic{X})` and read it as Julia's barrier.

**Built** (`src/atbox.jl`, `src/classify.jl`): a call whose callee, or a function it passes on (`sum(uarea, ts)`), is
the load of a global of the method's own module that is not defined, with a value at the box, is a fault of its own
kind (`:undefined`). Before the module's end the method waits for the name (as for a name its own code names, now also
where an inlined callee of the module names it); at the module's end the fault refuses the method in a `bounded` scope,
and `check_definitions` lists it anywhere. The message (§11.3's form):

```
TraitUseError: `f(a::Main.UL.UShape, ts::Main.UL.UShape...)` is declared bounded, and is not bounded: read with `a` in a box, …:
  uarea(a): `uarea` is not defined in Main.U2; `uarea` is an operation of Main.UL.UShape: `using Main.UL: uarea` imports it, at line 5
  sum(uarea, ts): `uarea` is not defined in Main.U2; `uarea` is an operation of Main.UL.UShape: `using Main.UL: uarea` imports it, at line 5
```
A callee that is a global's load prints by the global's name: `K(a) has no method`, not `%1(a)` or `Main.U3.K(a)`.

The cases (`logs/o-undefined-46687cb.log`):

| case | the check |
|---|---|
| a name no module defines, `nothere(a)`; in a branch; through a local; `global nothere` never assigned | refused at the module's end: "`nothere` is not defined in M" |
| the trait's operation not imported (the old form of `mfvok`) | refused; the hint names the import |
| defined later in the module: no method at the box / a method | waits, then refused ("`later(a)` has no method") / accepted |
| defined at the module's end by `@eval`, or by a macro | accepted (the hook runs after the module's last statement) |
| defined by `eval` in `__init__` | refused: the module's end comes before `__init__` |
| a `const` global that is not a function; a typed global `K::Int` | refused, "`K(a)` has no method" (a `MethodError` at the known type, as before) |
| an untyped global `K = 3` | accepted: a global whose value the code does not know; the call is Julia's barrier |
| a call of a name never defined with no value at the box, `nothere(1) + uarea(a)` | accepted: not the check's (a fault is a call with a value at the box) |
| another module's name, `UL.nothere(a)` | accepted: the end of the method's module does not decide another module's names |
| a helper of the module that calls the name, `h(x) = nothere(x)`, not inlined | accepted: the instance reads `h(a)` as returning `Any`; a callee's own calls are read only below a call that only throws |
| a scope with `bounded = false` | accepted; `check_definitions` lists the fault |

Tests: `test/messages.jl`, testset "the bounded check at a name its module never defines", 16 checks; on 15070de's
`src` 7 fail (`logs/o-messages-test-before-15070de.log`).

### 2. Traits T-162: a trait's operation is not owner-only by the default (TraitWorld 46687cb)

**What the mark gives the compiler.** `Compiler.is_owner_only(F)` (`Compiler/src/facts.jl`) is true for a function
declared `@owner_only` (the binding's flag, `jl_set_owner_only`), or for a function of a module whose `owner_only`
option is on that the module neither exports nor declares `public`. `is_fact_sig` then takes a call of it at any
signature as a fact: inferred as plain inference infers it, with Julia's dispatch edge. The library's ownership reads
the same predicate (`_owner_only_ftype`). So an operation that members extend must not carry it: a member's method
would end code compiled by facts at `op(::Any)`, a fact no non-pirate may change. At a value known by the trait the
call is typed by the contract (compiler §7.1) whether the operation is owner-only or not; at a concrete type it is a
dispatch tuple. Taking the mark off changes only a call at a value of a type the code does not know (`op(v[1])`,
`v::Vector{Any}`): a fact before, a run-time site after.

**What the demonstrators had** (`o-probes/operations.jl`, `logs/o-operations-114a933.log`, `-46687cb.log`): 74
operations of the demonstrators' traits whose functions are their modules' own (TraitWorld.BaseTraits, TableCore,
CSVCore, PlotCore, TraitIndexing, TraitArrayTools, ODECore, TraitNonlinearSolve); 67 exported or `public`.

| module | trait | operations not exported, not `public` | methods from other packages | the calls |
|---|---|---|---|---|
| ODECore | `StepCallback` | `step_condition`, `step_affect!`, `step_initialize!` | none | at an element of a `Vector{StepCallback{U, T}}` (ODECore, TraitRodas): typed by the contract |
| ODECore | `StepEvent` | `step_event_condition`, `step_event_affect!`, `step_event_affect_neg!`, `step_event_initialize!` | none | at an element of a `Vector{StepEvent{U, T}}`, and `event_affect_dir!(cb, …)` called with one: typed by the contract |
| every other trait module | | none | | |

After: 0 owner-only, the 7 `public`, read from ODECore's image. No call of the 7 is at a value of a type the code
does not know, so nothing relied on the mark. The suites pass (below); the sessions compile the same and hold the
same instances but the library's own (`logs/o-sessions-p1-114a933.log`, `logs/o-sessions-p2-46687cb.log`, 3 runs
after a warm-up):

| | report: compiles | table: compiles | instances TraitTables, TraitCSV, TraitMakie | TraitWorld (report, table; methods) |
|---|---|---|---|---|
| 114a933 (T-161 only) | 24 | 19 | 129, 34, 323 | 474, 413; 810 |
| 46687cb | 24 | 19 | 129, 34, 323 | 475, 414; 813 (`_open_operations!`, `_declared_owner_only`, `_operation_of`) |

**Built** (`src/ownership.jl`, `src/implement.jl`, `src/trait.jl`, docstrings in `src/scope.jl`). Julia is read only,
so the library cannot change `is_owner_only`; it takes the mark off the way Julia reads it. At the module's end (the
module-end hook), each operation of a trait the module declares whose function is its owner's, owner-only and not
declared `@owner_only`, is declared `public` (`Core.eval(M, Expr(:public, name))`); at the prompt (`Main`, which has
no end) at the declaration. Not at the declaration in a module: Julia refuses `export f` after `public f` ("cannot
declare M.f exported; it is already declared public"), and a module may export an operation after its `@trait` (the
case "exported after its `@trait`" is accepted). `@owner_only op` closes an operation (the flag wins in both readers).
The message at a closed operation's pirate: "`carea` is an operation of Main.OOTr.CShape that Main.OOTr declares
`@owner_only`: only Main.OOTr adds methods to it, whatever types they are for. To let other modules add methods,
Main.OOTr does not declare it `@owner_only`, …". The text of "declared `@owner_only`" reads the flag, not
`Base.ispublic`.

The cases (`o-probes/operation_cases.jl`, `logs/o-operation_cases-46687cb.log`):

| case | the library |
|---|---|
| a member's module adds the operation's method for its own type, in a block or beside it | accepted (in a `no_pirates` scope, and under strict mode) |
| a module adds the operation's method for its own type that is no member | accepted: the classic rule, own type |
| a third module: the operation's method for a type it does not own (`oa(::Int)`) | classic pirate: `OwnershipError`, "owns neither the function (owned by Main.OL) nor a type …" |
| a third module: a membership for a type it does not own | a pirate's membership: `OwnershipError` |
| a third module: the operation's method at the trait itself, `oa(::OS, ::Int)` | classic pirate (a trait it does not own) |
| an operation closed by `@owner_only` | the member's method is a pirate's: `OwnershipError`, the operation's message |
| another module's trait names a trait module's internal function as its operation (`IA.helper(s::BX)::Int`) | refused at the `@trait`: its kept forms' methods of `IA.helper` are a pirate's; `IA.helper` stays owner-only |
| a call of the operation at `Any`, compiled in the module's body before its end | inferred as a fact, `(Float64, deep)`; a member's method later ends it, with no pirate report |

Tests: `test/owner_only.jl`, testset "a trait's operation is not owner-only by the default", 18 checks; on 114a933's
`src` 3 fail and 1 errors of the 7 reached (`logs/o-owner_only-test-before-114a933.log`). The documentation's
example: `docs-examples/tutorial.jl` §16 (`Plates`, `Steel`), 2 checks. The messages' tool: three cases replace the
old "a trait's unexported operation, in a block" (now no error; a closed operation; a classic pirate at the
operation) and two cases of T-161.

### 3. The checks, TraitWorld 46687cb

| check | result |
|---|---|
| the library (`-e 'using TraitWorld; include("test/runtests.jl")'`) | 117 testsets (115 and the two new), no failure, 30 s (`logs/o-library-46687cb.log`; 116 on 114a933, `logs/o-library-114a933.log`) |
| the documentation's examples | intro 33 pass; tutorial 126 pass (124 and §16's two; compiler C-157's check passes); strict 10 pass (`logs/o-docs-*-46687cb.log`) |
| the gates (`LIB=wt/w158g-tw run_all.sh julia-next`) | 73 of 74, stage gates 9 of 9 (`logs/o-gates-46687cb.log`). `n35_trusted_result` fails, 8 forms ("Ops declared result" 7 holes, `Core.invoke`'s constant): the same output with the library at `unified` 15070de and at 114a933 on this binary (`logs/o-gate-n35-15070de.log`, `-46687cb.log`); the gate passed on `wt/w158-julia`'s binary of 85bd884a57 (`logs/m6-gates-85bd884.log`). Not this work's; the binary `julia-next/julia` (`85bd884a57*`) is the difference |
| TraitDifferentialEquations, TraitTables, TraitMakie (`g-probes/env_demo_g`, `env_tables_g`) | 35, 3, 8 testsets, no failure (`logs/o-{port,tables,makie}-46687cb.log`) |
| the messages' tool (`messages/run.sh o-46687cb`) | 157 distinct messages; tuple type, generated name, compiler object, library internal: 0 (`logs/b-messages-o-46687cb-scan.txt`) |
| the sessions | the table above |

### 4. Not built, not verified

- **T-161 below a callee:** a helper of the module that calls a name never defined is not read (its instance returns
  `Any`); a callee inlined into the instance is read.
- **T-162 in the module's body:** until the module's end an operation is owner-only to the compiler. Code compiled in
  the body (a top-level call, a workload, an instance the bounded check keeps) that calls it at a value of a type the
  code does not know is a fact of an owner-only function, and stays valid after the module's end: compiler C-130 (a
  later `public` ends nothing). A member's method ends it through its edge (G1), with no pirate report.
- **`Base.ispublic` is true for an open operation** the module did not declare `public`, and `names(M)` lists it. No
  demonstrator reads `names` without `all = true`.
- **A `@trait` evaluated into a module after its end** (not `Main`) leaves its operations owner-only.
- **The principled form** is Julia's: `is_owner_only` would leave out a function the library marks as an operation
  (a binding flag set by `@trait`, beside `@owner_only`'s), with no `public` and no gap in the module's body. Not built
  (Julia read only).
