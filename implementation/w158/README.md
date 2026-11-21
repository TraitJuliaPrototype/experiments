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
