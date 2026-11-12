# W-142: fully typed is exactly what compiles ahead. Where the two differ today

The decision (the user, 2026-11-11): "fully typed should equal AOT compilable exactly". Reference: `writeup/reference/traits.md` §14, §16; deviation T-109. This directory holds the comparison that says where the session's check and the closed build differ, on small programs.

## How to run

```
bash experiments/unification/w142/agree.sh [tag] [apps…]
```

For each program of `../w139/apps/` it asks `fully_typed(main, (Vector{String},))` in a session and builds the program under `--trim=safe`. The table goes to `logs/agree[-tag].log`; the builds' logs to `../w139/logs/w142-<app>.build.log`. About ten seconds a program.

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
