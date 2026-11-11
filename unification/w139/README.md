# E-364: a small trait program as a trimmed binary, typed and with values known only by their trait (W-139, G-6)

**The question:** does a trait program build under `juliac --trim=safe` and run, where its calls are at concrete members, and where a value is known only by its trait. And what does the closed-build rule (compiler §7.6: a build has every member, so an operation on such a value is a split over all of them) change. Registry row: `writeup/record/experiments.md` E-364. Current numbers: `writeup/design/evidence.md` §4.

## The programs

`apps/geometry_trait.jl`: a trait module with `Shape` (`area`, `perimeter`, a default `label`), `ratio` and `report` over it, and two members, `Circle` and `Rect`. `apps/geometry_plain.jl`: the same with an abstract type.

| App | `main` |
|---|---|
| `typed_*` | `report(Circle(1.0))`, `report(Rect(2.0, 3.0))`: every call at a concrete member |
| `vector_*` | a loop over a `Vector{Shape}` of three items: each item is known only by its trait |
| `dynamic_trait` | a struct with a field `Dynamic{Shape}`, filled with a `Circle` or a `Rect` by the arguments |
| `barrier_trait` | `report(compiled_for(s))` in a loop over a `Vector{Shape}`: a cast to `Compiled` on a value known only by its trait |
| `family_trait` | a family of members, `@implement Shape Scaled{T} where {T}`, at `Scaled{Rect}`, `Scaled{Circle}` and `Scaled{Scaled{Rect}}`, in a `Vector{Shape}` |

## How to run

```
source ../../../env.sh
bash run.sh            # each app in a session, built with --trim=safe, run; the outputs compared -> logs/run.log
julia --project=../../../TraitWorld-unified make.jl > logs/make.log    # make_executable and make_library
julia --project=../../../TraitWorld-unified dbg_closed.jl    # the closed split's typed code, from a session
```

- `build.sh <app> [project]`: one build with `julia-unified/test/trimming/juliac-buildscript.jl` (as E-361's).
- `dbg_closed.jl` sets the trim option in a running session and loads the compiler as a package from `julia-unified/Compiler`'s sources. A change to the compiler is seen without rebuilding Julia. It shows what inference and the inliner do, not what the build's own compile does: the stale world below was not visible in it.

## Results, 2026-11-11

`julia-vanilla` v1.13.2 45b6d15e34, TraitWorld 99c4934. One build each, load 6 to 13 of 128 cores. Under `--trim=safe`: the verifier's errors, the binary's bytes, and whether it runs with the session's output.

| Program | Before (`unified` dd3f6d839b) | With the closed build (`unified` 97861c6b31) | Plain twin, unified | Plain twin, vanilla |
|---|---|---|---|---|
| typed | 0 errors; 2,480,504; runs, equal | 0; 2,479,552; runs, equal | 0; 1,942,688; runs, equal | 0; 1,845,008; runs, equal |
| a loop over `Vector{Shape}` | 8 errors; no binary | **0; 2,550,896; runs, equal** | 2 errors; no binary | 2 errors; no binary |
| a `Dynamic{Shape}` field | 0 errors; 2,538,336; **fails when run** (`MethodError`) | **0; 2,540,800; runs, equal** | — | — |

- **A family of members** (`unified` b5c6ac2967): 0 errors; 2,558,496 bytes; runs, equal. Before the build listed a family's instantiations, the set was not listed and its calls were refused.
- The binaries link `libjulia` and `libjulia-internal`. None links `libjulia-codegen` or `libLLVM`.
- The first row is the first trait program that ran trimmed: fully typed trait code needed nothing.

## Reading

- **Fully typed trait code builds and runs as plain code does.** The binary is 0.5 MB larger than the plain twin's (the library's runtime).
- **With the closed build, a value known only by its trait builds too, where plain Julia's abstract type is refused.** The loop over `Vector{Shape}` is two errors in plain Julia, on both builds: `report(s::Shape)` is a dynamic call. In the trait form each operation branches over `Circle`, `Rect` and the box, each branch a direct call, and raises past them.
- **Before, the `Dynamic` program built with 0 errors and failed when run.** Its calls were `Core.attributed_call`, a builtin that dispatches when it runs, which the verifier did not look at. The verifier now refuses it.

## What had to change, in the order found

1. **The split over every member, raising past them** (inference and the inliner), with the box `Dynamic{X}` as a member. Seen working from a session (`dbg_closed.jl`), and without effect in a build.
2. **The verifier refuses `Core.attributed_call`.**
3. **Code inferred before every member was declared is inferred again** when the build compiles. A method at a trait is inferred at its definition, by the definition check, when the trait has no member.
4. **The cause of "without effect in a build": memberships were asked in the wrong world.** The build's compile runs in the compiler's own world, an old one, and asked memberships there, where none of the program's exists. So `Circle <: Shape` was false, no call was split, and every operation on a value known by its trait stayed a dynamic call. `jl_type_infer` sets the world for a session's inference; the build's driver did not. This reaches further than this experiment: it is part of why E-361's demonstrators were refused.

5. **The split is closed only where a set's members can be listed.** At first that meant every membership entry names a concrete type: a member of a family (`@implement X S{T} where T`), of an abstract type or of a subtrait joins a session's candidates at its first use, which a build cannot wait for. With the split closed at such a set, TraitDifferentialEquations' own load failed in the build's process with a `MethodError` from the raising branch. At such a set the call stays dynamic, and the verifier refuses it.
6. **A call that does not know its argument's member runs the instance compiled once,** in place of an attributed call left to run time (`unified` ddc328b343).
7. **A family's members are the instantiations the build has made,** read from the type's cache; the build compiles in rounds while a round adds one (`unified` b5c6ac2967). A first version read the cache from the compiler's side and failed inside inference; the runtime lists it now. An abstract type's subtypes are still not listed (compiler C-86).

## The demonstrators on the closed build

E-361's programs again (`../w135/logs/closed/`; the same packages): none builds under `--trim=safe` yet.

| Program | E-361 (`unified` 564a2288e2) | The closed build |
|---|---|---|
| table | 8 errors (9 with entry points) | 10 (10) |
| ODE; with a gradient | 122; 160 | 120; 158 |
| plot | 34 (48) | 46 (47) |

- The counts moved because the verifier now sees the attributed calls, which it passed over before: the table's two more are `attributed_call(floats, ::Any, …)` and `attributed_call(summarize, ::Any, …)`.
- What refuses them now is not the trait: a value typed `Any` passed to a method at a trait, Base's `repeat(::Char, ::Int)`, a JLL's `__init__`, and sets with pattern members. The demonstrators are not fully typed.

### A cast on a value known by its trait, and the table again (2026-11-11, `unified` 5d8da002fa)

`logs/run-w139b.log`; `../w135/logs/closed/table-a19d937eaa.build.log` (before), `table-5d8da002fa.build.log` (after); `dbg_table.jl` (the rule seen from a session). One build each, load 2 to 5 of 128.

- **`barrier_trait` builds and runs:** 0 errors, 2,546,984 bytes, output equal to the session's. Before, the call was `Core.attributed_call(…, ::Any)`, which the verifier refuses.
- **The table's three trait errors named one shape:** `f(compiled_for(x), …)` with `x` known by its trait (`fillcolumn`, `summarize`, `floats`). Two causes, both in the compiler:
  - the cast's result was `Any`: `Core._cast_compiled` passes a `Dynamic`'s object, typed `Any`. It is of the trait now.
  - a session leaves such a call to dispatch when it runs. A closed build now branches over the trait's members.
- **`readtable`'s call is split over `CSVColumn`'s five members.** 9 invokes become 18; no call is left to run time there.
- **`Column`'s members cannot be listed, and the table's count rises from 10 to 50.** `Column{T}` has the family `Vector{T} where T`: the build lists every `Vector` instance of the process, 250 in a session, past the limit of 64. `summarize` and `floats` at `Column` are compiled once, and each of their operations (`nrows`, `cell`) is left to run time: 44 errors in `TableCore`, 6 in Base (`repeat`). The trait's members are four types in this program. The tension: `writeup/open-issues.md` §1, GT-15.

## `make_executable` and `make_library` (TraitWorld 19862aa)

`make.jl` (`logs/make.log`), from a session, on `apps/program.jl`, whose functions loop over a `Vector{Shape}`:

| Call | Result |
|---|---|
| `make_executable(shapes_main, "out/made")` | 2,543,792 bytes; runs, prints the three reports |
| `make_library([total_area => (Cdouble, (Cint,))], "out/libmade.so")` | 2,392,456 bytes; a C program linked against it prints `total_area(2) = 9.1416` |
| `make_executable(untyped_main, …)`, a call on a value typed `Any` | `BuildError: the build refuses 6 calls it cannot resolve; the program is not fully typed there`, with the build's report |
| `make_executable(args -> 0, …)` | `ArgumentError`: a build takes a function its process can name |

- The build's process loads the file the function is written in. The first version took an anonymous function written in `make.jl` itself: the build loaded `make.jl`, which called `make_executable` again, and so on, a chain of twenty processes. Now such a function is refused, and inside a build's own process the two functions do nothing.
- The check before the build is the build's own verifier. `verify_main` in a session reports the loop's `report(::Shape)` as a run-time site, which the closed build resolves (traits T-107).

## A `main` written at the prompt (TraitWorld 633d6c0)

- `make_prompt.jl` (`logs/make_prompt.log`): ten inputs evaluated as the prompt evaluates them, then `make_executable(main, …; session = inputs)`.
- `make_repl_inputs.txt` (`logs/make_repl.log`): the same entered at a real prompt, through a pseudo-terminal (`script -qfc "julia …" /dev/null < make_repl_inputs.txt`), with `make_executable(main, "out/made_repl")` as one of the inputs. The inputs come from the prompt's history.

Both: "the build replays the 8 definitions of the session that main depends on; 2 other statements are not replayed"; 2,525,384 and 2,526,016 bytes; `total area 7.927`, the session's value.

- The 8: the import, the trait, two types, their two memberships, `total`, `main`. The 2 left out: an assignment to a global, and a call.
- The selection is by name over the inputs' text. The prompt's history is the only source of a type entered there.
- Found on the way: Julia 1.13's history holds entries with a mode and a text, where earlier versions held texts with the modes beside; and two helpers of the first version had names the library already used, which made the library fail to precompile until they were renamed.

## Observed, not diagnosed

- A build takes 15 minutes on this host when the compiler changes (the system image is rebuilt). Twelve builds were needed.
