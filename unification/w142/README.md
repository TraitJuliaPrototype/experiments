# W-142: fully typed is exactly what compiles ahead. Where the two differ today

The decision (the user, 2026-11-11): "fully typed should equal AOT compilable exactly". Reference: `writeup/reference/traits.md` §14, §16; deviation T-109. This directory holds the comparison that says where the session's check and the closed build differ, on small programs.

## How to run

```
bash experiments/unification/w142/agree.sh [tag] [apps…]
```

For each program of `../w139/apps/` it asks `fully_typed(main, (Vector{String},))` in a session and builds the program under `--trim=safe`. The table goes to `logs/agree[-tag].log`; the builds' logs to `../w139/logs/w142-<app>.build.log`. About ten seconds a program.

- `ft_app.jl <app.jl>`: the session's check of one program, with its report; for a demonstrator's program, with `--project=../w134/env_demo`.
- `ft_app_sites.jl <app.jl>`: the check's raw sites, each with the instance that holds it and the first instance of the user's code above it.
- The apps `bb_*` exercise what a build replaces in Base (below).

Current numbers: `writeup/design/evidence.md` §4. Registry row: E-369.

## Results, 2026-11-12 (`unified` f6ad3008b4, TraitWorld `unified` 4a1dc03; one run; load 2 to 5 of 128; `logs/agree.log`)

| Program | The session's check | The build | Agree |
|---|---|---|---|
| `typed_trait`, `typed_plain`: every type known | fully typed | builds | yes |
| `dynamic_trait`: a `Dynamic{Shape}` field | fully typed | builds | yes |
| `ft_union`: a call at a union of two types | fully typed | builds | yes |
| `ft_abstract_result`: an abstract result nobody calls on | fully typed | builds | yes |
| `ft_abstract_member`: a member at an abstract type | fully typed | builds | yes |
| `vector_plain`: a loop over a vector typed by a plain abstract type | not: 2 sites | refused: 2 errors | yes |
| `vector_trait`: a loop over a `Vector{Shape}`, each item passed to a method at the trait | not: 2 sites | builds | **no** |
| `family_trait`: the same with a family's members | not: 2 sites | builds | **no** |
| `barrier_trait`: `compiled_for` on a value known by its trait | not: 1 site | builds | **no** |
| `ft_any_call`: a value typed `Any` passed to a method at the trait | not: 2 sites | builds | **no** |
| `ft_plain_hole`: Base's `repeat(::Char, ::Int)` | fully typed | refused: 2 errors | **no** |
| `ft_many_members`: a trait with 70 members, a value known by the trait | fully typed | refused: 2 errors | **no** |

Six of thirteen differ, in three patterns:

1. **The build resolves, the session does not (four programs).** A value known only by its trait, or typed `Any`, is passed to a method at the trait. A session leaves the call to run time: it does not know the members to come. The closed build has every member and branches over them. The session's check applies the session's rule.
2. **A hole in plain code (one).** The check takes Base's `repeat(::Char, ::Int)` as resolved; the build finds a hole below it (traits T-107).
3. **A limit of the build (one).** More than 64 members are not split (compiler C-87), so the build refuses code the check accepts.

## The fix, by pattern

1. The check infers with the closed build's rules: a call at a method at the trait on a value known by the trait, or wider, is resolved by the members. It needs inference to run "as closed" inside a session, with a cache of its own: the session's code must not hold the build's splits. The build's rounds (members by use) are part of the rule.
2. The check walks plain callees to their holes, as the build's verifier does (T-100, T-107).
3. The build's limit goes (a table past the branches, as in a session), or is a fault of both.

## Results, 2026-11-14: the check is the build's own, run in the session

`unified` 381cc8b953, TraitWorld `unified` 78a78af; one run; load 1 to 3 of 128; `logs/agree-closed.log`, `logs/agree-base.log`. The logs' headers name the work-in-progress commits 9e6baf6fc1 and 662b183: the trees were those with the changes that the two commits above record.

| Programs | Agree |
|---|---|
| The thirteen of 2026-11-12 | 13 of 13 |
| `bb_show_type`, `bb_sprint`, `bb_print_many`: Base as the build replaces it | 3 of 3 |
| `bb_invokelatest`: `Base.invokelatest`, which the build binds to a direct call | **no**: the check reports the call, the build builds |
| TraitTables' table program (`../w135/apps/table.jl`) | yes: fully typed (4.2 s); builds with 0 errors, 3,110,440 bytes, runs, output equal to the session's |
| The ODE port's program (`../w135/apps/ode.jl`) | yes: not fully typed (57 calls, 10.9 s); refused, 118 lines of errors |

What was built:

1. **The check is the build's code.** `Compiler.closed_check(mis, world, overlay)` runs the build's rounds and its verifier in the session, under an owner of its own, with every method inferred plainly. The rule sites that asked the trim option ask the interpreter. 2 to 5 s for a small program.
2. **`ft_plain_hole` was no hole.** The build refused Base's `repeat(::Char, ::Int)` because a body inlined from the system image names its `:invoke` target as a method instance, which the build's queue did not compile and the verifier refused. Both take it now.
3. **A second rule site, found by the table program:** a split's last branch through a table of pointers is a session's; the inliner asked the trim option, not the interpreter. The check then reported 22 `cfunction`s the build never makes.
4. **The build's Base is not the session's.** `juliac`'s build script replaces 28 methods of Base and the standard libraries before it compiles (`juliac-trim-base.jl`, `juliac-trim-stdlib.jl`: printing a type, `sprint`, logging off, deprecation warnings off, some `__init__`s) and changes 12 things that are no method (the binding `invokelatest`, eleven functions' `max_args`). The table program prints a type's name; the session's check reported 25 calls inside Base's `show`, the build none.
   - *The pattern:* the check and the build compile the same program against two Bases.
   - *The fix at the rule:* one list of replacements read by both. TraitWorld reads the build script's files once a session into an overlay method table (`TraitWorld.build_base_report()` lists what was laid over and what was left out); the check infers and verifies with it laid over the session's methods. The session's methods are untouched. Three functions the files add (`show_typeish`, `invokelatest_trimmed`, `unwrap_val`) are defined in Base as written.
   - *Left:* what is no method cannot be laid over. `Base.invokelatest` (a binding) differs: `bb_invokelatest`. The `max_args` settings did not differ on `bb_print_many`.
5. **A build's process that loads a package from source runs its workload under the closed rules,** and failed there (TraitNonlinearSolve's, a member of a family the build had not yet counted). With the package images written first (a session), the build loads them. Not fixed: recorded with the deviation.

The verdicts agree on 17 of 18 programs. The lists of calls are not compared one by one: the report names a call in the user's code where the session's walk has a root cause for it, and the build names the call it stopped at.
