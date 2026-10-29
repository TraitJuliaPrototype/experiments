# U6 (E-252): is an extension loaded before a dependent's code compiles?

Exploration `writeup/explorations/abstract-types-as-traits.md` §11.1, §11.2 (C3, C4: Lemma M), §11.5 (U6). Registry row E-252.

**The premise tested** (§11.1): "a definition is visible to `P` when `P` compiles iff it lives in a package in `P`'s dependency tree, or in an extension whose triggers are all in that tree." Lemma M (C4) and the coherence rule (C3) rest on it.

## The model

Today's Julia has no late subtyping. A plain method stands in for the membership. What is measured is *when* the definition becomes visible, relative to the compile of the probing code.

- `Xs` owns the set's registry: `ismember(x) = false`.
- `Fo` owns `f` and depends on `Xs`: `f(x) = Xs.ismember(x) ? :won : :fallback` (the bounded method in its function's owner's package).
- `Sp` owns the type `Ty`.
- The membership `Ty ∈ X` is the method `Xs.ismember(::Sp.Ty) = true`. Each arrangement puts it in a different place.
- R9 models the combination §11.1 excludes: `Xs.Members = Union{Sp.Ty}` (members declared by the set's owner) and `Fo.f(::Xs.Members) = :won` in `Fo`'s extension triggered by `Xs`.

Each probing module (`P`, or the one the arrangement names) runs `g() = Fo.f(<a Ty>)` in its body and keeps three constants. In precompilation these are evaluated in the child process that writes its image:

- `SEEN`: what `g()` returned then (`:won` iff the membership was visible);
- `AT_COMPILE`: which of the arrangement's modules were loaded then (`Base.loaded_modules_order`);
- `GENERATING`: whether that was while writing an image.

A session then loads the packages and prints `SEEN`, what `g()` answers now, and the invalidations of each step. Two logs are read: the method-insertion log (`jl_debug_method_invalidation`) and the load-time verification log (`Base.Compiler.ReinferUtils.debug_method_invalidation`).

## How to run

```bash
cd experiments/w83/u6
python3 gen.py                        # writes arr/<R>/pkgs/* and arr/<R>/meta.toml
./all.sh parallel                     # every arrangement; also: serial, require, compilecache, none
./r12.sh > logs/R12.log 2>&1          # R12: the extension added after P's image was written
./summary.sh                          # the table below, from logs/
```

- Each run goes through `experiments/tools/jl --name w83u6`. `run.jl` creates the arrangement's environment (`Pkg.develop` of every package, offline) and empties the arrangement's own depot (`<agent depot>/u6-arr/<R>`, first on `DEPOT_PATH`). Then it precompiles in the given mode and runs one fresh session per step list (`session.jl`).
- Modes:
  - `parallel`: `Pkg.precompile()`;
  - `serial`: the same with `JULIA_NUM_PRECOMPILE_TASKS=1`;
  - `require`: no explicit precompile, the first `using` precompiles;
  - `compilecache`: `Base.compilecache` of the top package, no Pkg;
  - `none`: `--compiled-modules=no`, so every body runs in the session itself.

## The arrangements

| ID | Where the membership is | The probing code | Its tree contains every trigger? |
|---|---|---|---|
| R1 | `Xs`'s extension `XsSpExt`, triggered by `Sp` (the set's owner, foreign member) | `P`, deps `Fo`, `Sp` | yes |
| R2 | `Sp`'s extension `SpXsExt`, triggered by `Xs` (the member's owner) | `P`, deps `Fo`, `Sp` | yes |
| R3 | `Sp`'s extension `SpXsFoExt`, two triggers `Xs`, `Fo` | `P`, deps `Fo`, `Sp` | yes |
| R4 | as R1 | `P`, deps `Fo`, `Q`; `Q` deps `Sp` (`Sp` only indirectly) | yes |
| R5 | as R1 | a third package `Z`, deps `P` only | yes |
| R6 | as R1 (`Xs`'s extension triggered by `Sp`) | **`Sp` itself** (deps `Fo`), a workload at `Ty` | yes, but `Sp` is a trigger |
| R7 | **`Sp`'s own extension** triggered by `Xs`; `Xs` is in `Sp`'s tree through `Fo` | **`Sp` itself** | yes, but `Sp` is the parent |
| R8 | `Sp`'s extension `SpXsExt`, triggered by `Xs` | **an extension**: `Fo`'s `FoSpExt`, triggered by `Sp` (`Xs` in its tree through `Fo`) | yes |
| R8b | as R8 | as R8, but `FoSpExt` lists `Xs` among its triggers too | yes |
| R9 | the excluded combination (above) | `P`, deps `Fo`, `Sp`, not `Xs` | no (control) |
| R9b | as R9 | `P`, deps `Fo`, `Sp`, `Xs` | yes |
| R10 | as R2, but `Xs` is a regular dependency of `Sp` (a trigger in `[deps]`) | `P`, deps `Fo`, `Sp` | yes |
| R12 | as R1, but `XsSpExt` is added to `Xs` (Project.toml, ext file, `Pkg.resolve`) after `P`'s image was written | `P` | yes |

## Results

Build: julia-1.13 `00dcc9994c`, TraitWorld not used. Product setting, strict mode off (plain Julia only). One run per arrangement and mode, 2026-10-29, load average about 2.5 (other agents' jobs in other slots). Logs: `logs/<R>-<mode>.log`, `logs/R12.log`.

**What the probing code saw when it was compiled** (`won`: the membership was visible; `-`: not run):

```
R     probe    parallel     serial       require      compilecache none        
R1    P        won          won          won          won          won         
R2    P        won          won          won          won          won         
R3    P        won          won          won          won          won         
R4    P        won          won          won          won          won         
R5    Z        won          won          won          won          won         
R6    Sp       fallback     fallback     fallback     fallback     fallback    
R7    Sp       fallback     fallback     fallback     fallback     fallback    
R8    FoSpExt  fallback     fallback     fallback     fallback     fallback    
R8    Pt       won          won          won          won          won         
R8b   FoSpExt  won          won          won          won          won         
R8b   Pt       won          won          won          won          won         
R9    P        fallback     fallback     fallback     fallback     fallback    
R9b   P        won          won          won          won          won         
R10   P        won          won          won          won          won         
```

**Sessions** (`parallel` images; the other modes give the same answers; `now` is `won` in every session after the last step):

| Arrangement, steps | Load order in the session | `SEEN` (compile) | Invalidated at the step that brings the membership |
|---|---|---|---|
| R1–R5, R9b, R10: `using P` (or `Z`) | the extension before `P` (e.g. R1 `Xs>Fo>Sp>XsSpExt>P`) | `won` | none |
| R6: `using Sp` | `Xs>Fo>Sp>XsSpExt` | `fallback` | 3 MethodInstances (`Sp.g()`, `Fo.f(::Sp.Ty)`, `Xs.ismember(::Sp.Ty)`), at method insertion |
| R7: `using Sp` | `Xs>Fo>Sp>SpXsExt` | `fallback` | 3 (`Sp.g()`, `Fo.f(::Sp.Ty)`, `Xs.ismember(::Sp.Ty)`) |
| R8: `using Pt`, or `using Fo` then `Sp` | `…>Sp>FoSpExt>SpXsExt` | `fallback` (FoSpExt) | 3 (`FoSpExt.g()`, …), at method insertion |
| R8: `using Sp` then `Fo` | `Sp>Xs>Fo>SpXsExt>FoSpExt` | `fallback` (FoSpExt's image) | at load: `verify_methods` 2, `insert_backedges_callee` 1 (FoSpExt's image code rejected) |
| R8, no images (`none`): `using Pt` / `Fo,Sp` / `Sp,Fo` | as above | `fallback` / `fallback` / **`won`**: depends on the load order | — |
| R8b: every order, with and without images | `SpXsExt` before `FoSpExt` | `won` | none |
| R9: `using P`, then `using Xs` | `Fo>Sp>P>Xs>FoXsExt` | `fallback` | 2 (`P.g()`, `Fo.f(::Sp.Ty)`) |
| R9, the row's case (3): `main` (compile `h()` at `Ty` in `Main`), then `using Xs` | `Fo>Sp`, then `Xs>FoXsExt` | `fallback` | 2 (`h()`, `Fo.f(::Sp.Ty)`): Main's code once |
| R12: image of `P` written without `XsSpExt`; `XsSpExt` added; `using P` (with or without a later `Pkg.precompile`) | `Xs>Fo>Sp>P>XsSpExt`: **after `P`** | `fallback` (image reused: `isprecompiled` true, nothing rebuilt) | 3 (`P.g()`, `Fo.f(::Sp.Ty)`, `Xs.ismember(::Sp.Ty)`) |

## Why: Julia's loader (julia-1.13 `00dcc9994c`)

- **A package's own load triggers extensions only after the package is loaded.** `_require_prelocked` inserts the package's extension triggers and runs the extension callbacks after `end_loading` (`base/loading.jl:2615-2631`). An extension loads when its last trigger (the parent counts as one, `loading.jl:1613-1616`) has loaded (`run_extension_callbacks`, `loading.jl:1660-1681`). So code that runs in the body of one of an extension's triggers, or of its parent, runs before the extension (R6, R7).
- **In the precompile child the package's own triggers are never inserted.** `include_package_for_output` leaves `insert_extension_triggers(pkg)` and `run_package_callbacks(pkg)` commented out (`loading.jl:3226-3229`). The image of `Sp` never contains an extension that `Sp` triggers (R6, R7).
- **An extension's precompile loads only extensions with a strictly smaller trigger set.** The child sets `Base.loadable_extensions` (`loading.jl:3306-3308`), and `run_extension_callbacks` loads only those (`loading.jl:1669`). The list is the extensions whose triggers are a strict subset of the extension's own: `Pkg.precompile` (`base/precompilation.jl:843-846`, `1268`) and the require-time path (`loading.jl:2815-2822`). `FoSpExt` has `{Fo, Sp}`, `SpXsExt` has `{Sp, Xs}`. `Xs` is loaded in `FoSpExt`'s child as `Fo`'s dependency, yet `SpXsExt` is not loaded there (R8). With `Xs` listed as a trigger, `{Fo, Sp, Xs} ⊋ {Sp, Xs}`, and it is (R8b).
- **For a package (not an extension) every extension whose triggers are all loaded loads in its child.** `loadable_extensions === nothing` there. `Pkg.precompile` makes the package depend on such an extension (`precompilation.jl:870-893`; the rule `!is_extension && has_triggers && !is_trigger` at line 880 excludes the extension's own triggers and other extensions).
- **In a session with images, "before" comes from the image's module list, not from trigger timing.** An image records every top-level module loaded while it was written (`src/staticdata.c:3400`, `jl_get_loaded_modules`; written by `write_mod_list`, `src/staticdata_utils.c:642`), extensions included. Loading the image loads those first (`loading.jl:2150-2200`). Extension callbacks of dependencies loaded this way run in a `finally` after the image itself (`loading.jl:2207-2209`, `2225-2229`). So an extension that was not loaded when the image was written loads *after* the package in a session (R12: `Xs>Fo>Sp>P>XsSpExt`).
- **Nothing makes an image stale when an extension becomes applicable.** R12: after `Xs` gains `XsSpExt`, `P`'s image is still accepted (`isprecompiled` true, `Pkg.precompile` rebuilds nothing). Its code at `Ty` stays correct only because the plain method invalidates it when the extension loads.
- **Not run, from reading:** a precompile child empties `EXT_DORMITORY` (`loading.jl:3306`). `_require_prelocked` inserts triggers only for a module it loads itself, and a module in the system image is already loaded. So an extension of a package in a custom system image never loads in a dependent's precompile child, though it loads in sessions. This is the R12 situation by construction.

## Answer

**The premise holds for a package strictly downstream of an extension, and fails in three allowed arrangements.**

- **Holds:** R1–R5, R9b, R10. The probing code is a package (not an extension). It is not the extension's parent or one of its triggers. Every trigger is in its tree, directly or indirectly (R4), or through a third package (R5). This held in every precompile mode, `Pkg.precompile` in parallel or serial, at `using`, by `compilecache`, and without images. The extension was loaded in the package's precompile child, so its image lists the extension, and in a session the extension loads before the package.
- **R9, the control:** the combination §11.1 excludes arrives after `P` compiled, as §11.1 says. In the row's case (3), `Main` compiled `h()` at `Ty`, then `using Xs` loaded `Fo`'s extension. That invalidated 2 MethodInstances, `h()` and `Fo.f(::Sp.Ty)`, both by `jl_method_table_insert`.
- **Fails, R6 (self-trigger):** the member's own package `Sp` compiles at `Ty` before `Xs`'s extension triggered by `Sp` can load. In every mode `Sp`'s image holds `:fallback`. Loading the extension invalidates 3 MethodInstances. The membership is the set owner's: a pirate under C4, so strict mode would refuse it. C3's static check does not refuse it, because the bounded method is in `f`'s owner's package.
- **Fails, R7 (self-parent):** the member's own package compiles before its own extension. This holds even though the trigger `Xs` is already in its tree (through `Fo`). The membership is the member's owner's, a stakeholder's. Lemma M says such a definition never wins at a compiled fact, and here it does.
- **Fails, R8 (an extension as the dependent):** `Fo`'s extension for `Sp` (`FoSpExt`) compiles `f` at `Ty` without `Sp`'s extension triggered by `Xs` (`SpXsExt`). This holds although `Xs` is loaded in its child (as `Fo`'s dependency). Julia loads into an extension's precompile only the extensions with a strictly smaller trigger set. Without images, which one runs first depends on the load order: `using Pt` or `using Fo, Sp` gives `:fallback`; `using Sp, Fo` gives `:won`. Both definitions are their owners' and allowed by C3 and C4. Listing `Xs` as a trigger of `FoSpExt` makes it work (R8b).
- **Fails, R12 (an extension added after the image was written):** `P`'s image is reused, `Pkg.precompile` does not rebuild it, and the extension loads after `P`.

**Against the row's criterion.** There are orders in which the extension loads after code compiled at `(T,)`. So Lemma M's premise, as §11.1 states it, is wrong, and the coherence rule's cut does not exclude every late winner. But the row's fallback, C2, does not repair R6–R8: in all three the bounded method is `f`'s owner's, in its package, which C2 allows. With plain methods, Julia repairs every case by invalidation, at the method's insertion or at load (verification). A membership read by static dispatch with no edge would leave the code stale. What holds instead, from the runs and the loader:

- An extension `E` is loaded before code of `P` compiles when `P` is a package, `P` is neither `E`'s parent nor one of its triggers, and every trigger of `E` is in `P`'s tree.
- When `P` is an extension, `E` is loaded only if `E`'s triggers are a strict subset of `P`'s.
- For an image, that holds only as of the environment in which the image was written.

So a membership declared in an extension can always arrive after some code at `(S,)`: the member's own package (R6, R7), an extension (R8), or an older image (R12). The options this leaves, for the main session to weigh:

- (a) Memberships declared in extensions are late: either a membership edge (§13.3, candidate (b)), or dispatch never folds "`S` is not a member" for a set that has such members. That is §13.4's rule applied to dispatch, the narrow form of C5.
- (b) Memberships only in a package proper (the member's or the set's), never in an extension: C1 for extensions. It costs TraitCSV's extension and the "trait owner's extension for a foreign type".
- (c) The design's current two tiers (an entry at `Any`, membership decided at run time), which none of this touches.
