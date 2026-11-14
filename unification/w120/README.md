# E-372: what a session still compiles that no image holds (W-120, phase 3's first step; G-3, G-1)

**The question:** before a cache across sessions is proposed, what would it hold? For a session of a demonstrator's program, each piece of code the session compiles is put in one class: the session's own (no image can hold it), code an image held and the session ended, code a package's own image could hold, a composition of several packages, Julia's own. Registry row: `writeup/record/experiments.md` E-372. Current numbers: `writeup/design/evidence.md` §3.

## How to run

```
source ../../../env.sh
bash sessions.sh [tag] [N]        # the table and the ODE sessions: a warm-up and N runs each -> logs/sessions[-tag].log
python3 classify_trace.py -v logs/ode-after.trace      # the classes, with the largest compiles of each
julia --project=../w134/env_demo image_has.jl TraitDifferentialEquations ODECore.solve_core    # what the images hold after the load
julia --project=../w134/env_demo g2_why.jl ../w135/apps/ode.jl ODECore.solve_core              # why an instance fails G2, down to the edge
julia --project=../w134/env_demo load_invalidations.jl TraitDifferentialEquations [pattern]    # what a load ends, by event
```

- `sessions.sh` runs `session_marks.jl` on `../w135/apps/table.jl` (TraitCSV's read, TraitTables' summary and a column's sum, 500 rows) and `../w135/apps/ode.jl` (Lorenz with Tsit5, Robertson with Rodas5), each a fresh process with one thread, niced. The marks: the load, the first run of `main`, a second run. `--trace-compile` with timing gives the compiles.
- `classify_trace.py` reads the trace. The classes are in its header. A signature's packages are read from its qualified names.
- Only TraitTables, TraitCSV and the ODE port run on the head (the other ports are phase 4).

## Results, 2026-11-14

`unified` a0602148ca (before) and add2f921c9 (after), TraitWorld 12b8b31, TraitTables c339175, TraitCSV 92c46d0, TraitDifferentialEquations cecf2c3. Product setting, strict mode off, one thread. Load 1 to 3 of 128. Before: one run after a warm-up, with a plain driver (`-e 'include(app); exit(main(args))'`; `logs/*-before.trace`). After: a warm-up and 3 runs (`logs/sessions-after.log`, `logs/*-after.trace`); the harness's own code is about 60 ms of the "after" compiles.

| | The table session | The ODE session |
|---|---|---|
| Wall, before | 0.70 s | 2.75 s |
| Wall, after | 0.76 s (with the harness) | **1.25–1.26 s** |
| Load, after | 0.43 s | 0.57–0.58 s (before the last fix: 1.32 s) |
| First run of `main`, after | 0.063 s, all of it compiling | 0.40 s, all of it compiling (before the last fix: 1.11 s) |
| Second run | 0.2 ms | 1.8 ms |

What the ODE session compiled, by class:

| Class | Before: compiles, ms | After: compiles, ms |
|---|---|---|
| the session's own (`main`, the user's functions wrapped) | 7, 332 | 9, 360 |
| a composition: the solver compiled once, `solve_core` at Tsit5 and `_rodas5_run`, which name no session type | 3, 538 | 0, 0 |
| a package's own image could hold it | 7, 86 | 3, 42 |
| compiled again | 0, 0 | 2, 30 |
| Julia's own (of it the compiler's own closures: 8, 138 before; none after) | 60, 333 | 51, 261 |
| **all** | **77, 1,288** | **65, 692** |

The table session compiles 16 pieces in 126 ms: `main` (63 ms) and Julia's own small methods. Nothing of TraitCSV or TraitTables.

## What it found

1. **The solver was compiled in every session though the port's workload compiles it.** 538 ms of 1,288. `image_has.jl`: after the load the images hold `solve_core` at Rodas5 and at the gradient's duals, not at Tsit5 with a `Float64` state. `g2_why.jl`: its record failed G2 through an inlined `core_solution`, which calls `CoreSolution{T}(ts, us, retcode, …)`. That call held four dispatch edges of the form `Tuple{Vector{Float64}, Vararg{Any}}`: edges to every call of a `Vector`, a `Symbol`, an `Int`.
   - *The rule that produced them:* a call that does not match a method at `Callable{A, S}` rests on the absence of the argument's methods at `A` (compiler §7.4). Where `A` named the method's variables the edge was to every call of the argument (compiler C-88 (b)). And the methods asked were all those of the function's table at a `Callable`: for a constructor, every other type's constructor too (`ODEProblem(f::Callable…, …)`, `Getter(f::Callable)`).
   - *The pattern:* an edge wider than the question fails G2, the image drops the instance, and every session compiles it again. Nothing reports it: the workload ran, the session is slow.
   - *The fix at the rule* (`unified` add2f921c9): the method's signature and the call are intersected with the `Callable` position left open. Where they do not meet, the method cannot take the call whatever the argument's methods: no edge. Where they meet, the variables have the values the other arguments give, and the edge is at that `A`, a fact signature. Gate `n26_callable_late_method`.
   - *The effect:* the ODE session 2.75 s to 1.25 s. The load fell too, 1.32 s to 0.57 s.
2. **The compiler compiled its own closures in each session:** 138 ms. Two `Future` closures captured a type (a split's declared result, a cast's set), so each was a closure type per captured type, compiled at its first use in every session. The type is held in a box now. The same pattern as the library's closures over untyped values (E-322).
3. **What is left is the session's own code and Julia's.** Of the ODE session's 692 ms: 360 ms the session's own (`main` 244 ms; the user's right-hand sides at the solver's signatures 91 ms), 261 ms Julia's own methods at signatures no image holds (`print` and `println` of a `Float64`, `round` with `sigdigits`, a range's `TwicePrecision`), 42 ms a package's own image could hold, 30 ms compiled again.

## Reading, for the cache's proposal

- **No library code is left for a cache to hold.** After the fix, neither session compiles a method of a trait library at a signature that names no session type. The images hold it, and the loads keep it.
- **A cache across sessions would hold two things:** the session's own code, which is the same only while the script is unchanged, and Julia's own methods, which a workload in Julia's images would hold for every user.
- **Its bound, on these sessions:** at most 0.19 s of the table session's 0.76 s, and 0.69 s of the ODE session's 1.25 s, if it held everything and cost nothing to load and validate.
- **The larger part is the load:** 0.43 s and 0.57 s, which no cache of compiled code touches.

## Limits

- Two sessions, the two ports that run on the head. The other ports are phase 4; their sessions are the measurement round's (W-145).
- The "before" numbers are one run with another driver. The classes do not depend on the driver; the wall times differ by the harness (0.06 s).
- The classes are read from names: a type printed without its module (an alias) is counted as Julia's.
