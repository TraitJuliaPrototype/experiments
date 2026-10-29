# U8 (E-254): the REPL case under "never fold a negative"

Exploration `writeup/explorations/abstract-types-as-traits.md` §13.4 (candidate (c), item 1: a membership registry whose entries carry a `min_world`) and §13.6 (U8). Registry row E-254.

**Question.** A `Main` function that tests `conforms(typeof(x), X)` is compiled at a `Main` type `S`; then `@implement X S` at the prompt; then the call again. (1) Does the second call answer `true` with no new CodeInstance? (2) Does the call in the earlier world answer `false`?

## How to run

From the design repository's root (one job per slot; the `all` run uses the facts system image and a depot of its own):

```bash
experiments/tools/jl --name w83u8    env JULIA_PKG_OFFLINE=true julia-1.13/julia --startup-file=no --project=experiments/w83/u8 experiments/w83/u8/u8.jl
experiments/tools/jl --name w83u8all env JULIA_PKG_OFFLINE=true julia-1.13/julia -J julia-1.13/usr/lib/julia/facts/sys.so --startup-file=no --project=experiments/w83/u8 experiments/w83/u8/u8.jl
```

`u8.jl` runs as a script; each top-level statement runs in the newest world, as at the prompt.

- **Part A**, TraitWorld as it is. A trait module `Lib` with `Shape` (`area(s::Shape)::Float64`), a `Main` struct `S` with `Lib.area(::S)` but no implementation, `isx(x) = conforms(typeof(x), Shape)`. Call `isx(S(1.0))`, note the world `W0`, `@implement Shape S` (invalidations logged with `jl_debug_method_invalidation`), call again. Then `Base.invoke_in_world(W0, isx, S(1.0))`, and the result of a task created before the `@implement`.
- **Part B**, the registry of §13.4 item 1 in plain Julia, no TraitWorld. A `Vector` of entries `(type, set, min_world)`. `member(T, X)` reads it in the caller's world (`Base.tls_world_age()`), `@noinline`, with no edge. A declaration pushes an entry with `min_world = world + 1` and opens the next world with a method redefinition. The same three questions.

CodeInstances are counted from `Base.specializations` of `isx`'s method at `S`, following `mi.cache` and `ci.next`, with owner and world range.

## Results

Build: julia-1.13 `00dcc9994c`, TraitWorld `33dd55e`. Strict mode off. One run per setting, 2026-10-29, load average about 2.5 (other agents' jobs in other slots). Logs: `logs/product.log`, `logs/all.log`.

| | product setting | test bed `all` |
|---|---|---|
| A: `isx(S)` before | `false` | `false` |
| A: invalidated by `@implement Shape S` | 11 MethodInstances (`jl_method_table_insert`, `invalidate_mt_cache`), among them `isx(::S)`, `conforms(::Type{S}, ::Type{Shape})`, `TraitWorld.proj_lookup(::Type{Shape}, ::Type{S})`, `TraitWorld.implementation(::Type{Shape}, ::Type{S})` | 1 (`invalidate_mt_cache`) |
| A: `isx(S)` after | `true` | `true` |
| A: CodeInstances of `isx` at `S` | 1 → 2: the old one's `max_world` capped (39506–39527), a new one from 39528: **a recompile** | 1 → 1 (owner `:facts`, still valid): **no recompile** |
| A: `invoke_in_world(W0, isx, S)` | **`true`** (the earlier world sees the membership) | **`true`** |
| A: task created before `@implement` | `true` | `true` |
| B: `isb(SB)` before / after | `false` / `true` | `false` / `true` |
| B: CodeInstances of `isb` at `SB` | 1 → 1, no new one | 1 → 1, no new one |
| B: old world, and the task created before | `false`, `false` | `false`, `false` |

What explains part A:

- `conforms` (`TraitWorld/src/entry.jl`) reads TraitWorld's registry through `proj_lookup` (`src/implement.jl`). The registry is methods (`@implement Shape S` adds a method of `implementation`) behind caches (the witness dictionaries, flushed when the world changes).
- TraitWorld takes these decisions in its decision world (`_in_decision_world`, `_decision_world`, `src/compiler.jl:106`). Outside a compile-time decision that is the newest world (`Base.invokelatest`), whatever the caller's world.
- In the product setting, `isx` at `S` was inferred through `conforms` at constant types, so it holds edges to `proj_lookup` and `implementation` at `(Shape, S)`. The new `implementation` method invalidates it. The new answer comes by a recompile.
- Under `all`, `isx` at `S` calls `conforms(::Type, ::Type)` as a run-time site with no edge (result `Any`), so nothing of `isx` is invalidated.
- In both settings the earlier world answers `true`, because the decision is taken in the newest world. That is §13.4's inconsistency, not its rule.

## Answer

Against the row's criterion ("a recompile or a wrong world: the registry of P1 needs edges or a different world rule"):

- **TraitWorld as it is fails both questions.** In the product setting the new answer comes by a recompile: method edges into the registry, the mechanism of §13.3's candidate (b) by accident. Under `all` there is no recompile. In both settings the earlier world answers `true` (the decision runs in the newest world): the wrong world.
- **The rule of §13.4 item 1 works in today's Julia with no Julia change.** A registry whose entries carry a `min_world`, read in the caller's world with no edge, gives the new answer with no new CodeInstance in both settings. The earlier world and a task created before both answer `false` (part B).
- So the plan's registry for P1 must be built as in part B: entries with a `min_world`, read with `tls_world_age()`, never through a method lookup that inference can see through. TraitWorld's current `conforms` is not that registry and cannot be used as the evidence for it.
