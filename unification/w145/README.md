# W-145: the measurement round (phase 5)

The round's plan, with the frozen build and the parts: [`writeup/plans/2026-11-14-measurement-round.md`](../../../writeup/plans/2026-11-14-measurement-round.md). Parts that have scripts of their own are here; the others run the scripts of `../w134/`, `../w135/`, `../w136/`, `../w139/`, `../w140/`, `../w120/`. Current numbers: [the evidence](../../../writeup/design/evidence.md).

## Part 1: calls (`calls/`, E-374)

```
source ../../../env.sh
cd calls && ../../../../julia-unified/julia --startup-file=no --project=../../../../TraitWorld-unified calls.jl [N]
```

A trait module (`T`), a user's module with a member (`U`) and a plain module with the same functions (`P`). Each row is a loop of N calls (10^7), the minimum of 7 runs, in ns a call. Idiomatic trait code, product setting, strict mode off.

| Date, build | Row | Trait form | Plain |
|---|---|---|---|
| 2026-11-14, `unified` 86deee2f98, TraitWorld baadf9f; two processes, load 4 of 128 (`calls/logs/calls-1.log`, `calls-2.log`) | 1 an operation at a known type | 0.79 | 0.79 |
| | 2 a method at the trait, at a known type | 0.79 | 0.79 |
| | 3 a trait with a `Dynamic` default | as it is (compiled once) 8.26–8.29; `compiled_for` 2.38 | 2.38 |
| | 4 an element of a vector of two types | `Vector{Shape}` 2.86–2.87 | abstract 2.69–2.70; union 3.18–3.19; one type 2.28 |
| | 5 a field | `::Dynamic{Shape}` 5.55–5.56 | abstract, two subtypes (split) 0.79 |
| | 6 a function argument, cast at each call | `compiled_for(f)` 1.34; `with_dynamic(f)` 344–352 | 0.79 |

Reading:
- Rows 1, 2 and row 3 with the cast: a plain call's cost.
- Row 6, `compiled_for(f)`: the call is an `invoke` of `apply` at the function's type, where the plain call is inlined: 0.55 ns a call.
- Row 6, `with_dynamic(f)`: the call is `Core.attributed_call(bits, apply, f, x)`, a run-time call whose result is `Any`, so the loop's value is boxed. The same code reached by a trait's default (row 3) is resolved when compiled, and with the cast outside the loop it costs 23.9 ns (E-371).
- Row 5: plain Julia splits a field of an abstract type with two subtypes; the `Dynamic{Shape}` call goes through the firewall.

## Part 2: what a cache across sessions would hold (`cache/`, E-375)

```
source ../../../env.sh
cd cache && bash run.sh [tag] [N] [cases…]      # generates pkgs/ on the first run; logs/cache[-tag].log
python3 summarize.py logs/cache.log logs/cache-glue.log
```

- `gen.jl` writes two independent packages and an environment per form and case, in `pkgs/` (not committed; the generator is). `SeriesA`: a trait `Series` (`len`, `at`) with eight generic algorithms at it, a member of its own, and a workload over them. `RingB`: a type `Ring` with its own functions. The session's `main` runs A's algorithms on a `Ring`.
- **Cases,** by who declares the membership of `Ring` in `Series`: `byB` (RingB, which then depends on SeriesA), `byBw` (the same, and RingB's workload runs A's algorithms on a `Ring`), `ext` and `extw` (an extension of RingB triggered by SeriesA, without and with the workload), `glue` (a third package that owns neither: a pirate's membership, in a plain module, since a trait module refuses to declare it), `session` (in `Main`).
- **Forms:** `tc` (the trait, Julia's default: a method at the trait is compiled for the member's type), `td` (the trait with `@default_dynamic`: compiled once), `p` (plain Julia: generic functions; the "membership" is the two methods).
- `session.jl` is one session: the loads, the session's own definitions, the first run of `main`, a second run. It lists every CodeInstance made after the loads by the root module of its method, with its own inference time (`time_infer_self`) and code generation time (`time_compile`). Inference is given to the method inferred, wherever its root is; code generation to the instance compiled, with what is inlined into it. The harness's own code is compiled before the count. The classes' sums match the first run's compile time within 5 %.
- Each run after the warm-up is the second session of an unchanged script: the images exist.
- The wall time of a process is not reported: the harness walks every instance three times.

### Results, 2026-11-14

The frozen build (`unified` 86deee2f98, TraitWorld baadf9f). Product setting, strict mode off, one thread, a warm-up and 3 fresh processes per case, load 3 to 5 of 128. `logs/cache.log`; the trait forms' `glue` again with the glue package as a plain module (`logs/cache-glue.log`).

| Case | Load, ms | Session's definitions, ms | First run, ms | Second run, ms | A's method at B's type | A's method, other | B's method | the glue's method | the session's own | TraitWorld's | Julia's method at B's type | Julia's own |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| p-byB | 9 | 1 | 277–279 | 0.1 | 8: 36 + 94 | — | 2: 0 + 0 | — | 1: 34 + 29 | — | — | 55: 67 + 26 |
| p-byBw | 9 | 1 | 148–150 | 0.1 | — | — | — | — | 1: 47 + 31 | — | — | 55: 47 + 28 |
| p-ext | 10 | 1 | 285–286 | 0.1 | 8: 36 + 96 | — | — | 2: 0 + 0 | 1: 34 + 32 | — | — | 55: 70 + 26 |
| p-extw | 10 | 1 | 149–150 | 0.1 | — | — | — | — | 1: 47 + 33 | — | — | 55: 46 + 26 |
| p-glue | 11 | 1 | 286–290 | 0.1 | 8: 36 + 99 | — | — | 2: 0 + 0 | 1: 34 + 29 | — | — | 55: 71 + 26 |
| p-session | 10 | 2 | 284–287 | 0.1 | 8: 36 + 98 | — | — | — | 3: 34 + 30 | — | — | 55: 70 + 27 |
| tc-byB | 121–124 | 2 | 155–157 | 0.1 | — | — | — | — | 1: 52 + 31 | — | — | 58: 50 + 28 |
| tc-byBw | 122–126 | 2 | 151–162 | 0.1 | — | — | — | — | 1: 51 + 29 | — | — | 58: 49 + 27 |
| tc-ext | 123–123 | 2 | 151–152 | 0.1 | — | — | — | — | 1: 52 + 29 | — | — | 58: 49 + 27 |
| tc-extw | 120–123 | 2 | 150–152 | 0.1 | — | — | — | — | 1: 52 + 31 | — | — | 58: 49 + 25 |
| tc-session | 135–148 | 139 | 307–309 | 0.1 | 8: 58 + 94 | — | — | — | 3: 105 + 28 | 1: 1 + 7 | — | 96: 77 + 106 |
| td-byB | 141–155 | 2–4 | 186–187 | 0.7 | — | — | — | — | 1: 52 + 29 | — | 4: 2 + 16 | 60: 50 + 32 |
| td-byBw | 139–161 | 2 | 167–171 | 0.6 | — | — | — | — | 1: 53 + 30 | — | — | 60: 50 + 34 |
| td-ext | 121–123 | 2 | 186–189 | 0.6 | — | — | — | — | 1: 52 + 29 | — | 4: 2 + 16 | 60: 51 + 32 |
| td-extw | 124–133 | 2–3 | 167–176 | 0.6 | — | — | — | — | 1: 53 + 30 | — | — | 60: 51 + 31 |
| td-session | 121–124 | 139–144 | 186–189 | 0.6 | — | — | — | — | 3: 37 + 33 | 1: 1 + 8 | 4: 2 + 17 | 98: 91 + 114 |
| tc-glue | 124–126 | 1 | 151–154 | 0.1 | — | — | — | — | 1: 51 + 30 | — | — | 58: 49 + 29 |
| td-glue | 123–124 | 2 | 183–186 | 0.6 | — | — | — | — | 1: 50 + 31 | — | 4: 2 + 16 | 60: 49 + 30 |

A class's cell: instances made after the loads: their own inference ms + their code generation ms (the last run).

Reading:
- **Plain Julia compiles A's algorithms at B's type in every session** (8 instances, 130 to 135 ms of a first run of 277 to 290 ms), whoever defines the two methods, unless a workload names the combination (`byBw`, `extw`: none, 148 to 150 ms).
- **The trait form, compiled for the type (`tc`): the membership's declaration is the workload.** Declared in a package (RingB, its extension, a pirate's glue), the declaring image holds A's algorithms at `Ring` (traits §16), and the session compiles none: 150 to 157 ms, with or without a workload. Declared in the session, they are compiled there (8 instances, 152 ms), as in plain Julia.
- **The trait form, compiled once (`td`): no case compiles A's algorithms,** the session's membership included: A's image holds the one instance. What a session makes is the pointer to each of `Ring`'s two operations (4 instances, 18 ms: `Base._split_pointer`, `Base._SplitTarget`; GT-7), unless a workload ran them (`byBw`, `extw`). The second run costs 0.6 ms against 0.1 ms.
- **What is left in every form** is the session's own `main` (about 80 ms) and Julia's own methods at signatures the session names first (about 77 ms: printing, `round`, `join`, the sort). Plain Julia has the same.
- **A membership declared in the session costs 139 to 144 ms before the first run** in the trait forms: its check and the pirate's warning run code no image holds (38 instances of Julia's own: logging, the check's inference).
- **The trait forms' loads take 121 to 126 ms against 9 to 11 ms:** TraitWorld's load.

What a cache across sessions would serve here: the session's own code and Julia's own methods at the session's signatures, about 155 ms of a first run, the same in plain Julia; A's algorithms at B's type only where the membership is declared in the session and compiled for the type (152 ms); the pointers of the form compiled once (18 ms); the session's membership check (139 ms).
