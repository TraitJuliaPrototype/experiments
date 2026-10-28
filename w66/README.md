# E-193: the facts-keyed cache's identity and index, by construction (W-66)

[W-66's note](../../writeup/plans/2026-10-27-facts-keyed-cache.md), revision 2, §4. Six toy cases. In each, a trait package `P<i>`'s facts code (`P<i>.Impl.go`) depends on something that changes between two sessions, while `P<i>`'s own source and version stay the same.

**How to run:**
- `python3 gen.py` makes the packages in `pkgs/`. The variants `a` and `b` of a changed dependency share its name, UUID and version.
- `env_a` and `env_b` develop them.
- `probe.jl` with `X_MODE=record` in `env_a` keeps each `go`'s facts CodeInstance: its fact signatures, its dependency closure (from the manifest) and the closure's build ids.
- `X_MODE=check` in another session compares that recorded entry with a fresh compile there. It checks whether the closure's build ids still match and whether a candidate index (the methods of the facts' functions that no image in the closure or the system image defined) intersects a recorded fact.
- `X_PRELOAD` loads a package first.

## Results, 2026-10-27

julia-1.13 41d199c557, TraitWorld 5589f4c; logs in `logs/`.

| Case | The change | Fresh compile | Direct origins by version | By source hash | Closure's build ids | Candidate index |
|---|---|---|---|---|---|---|
| 1 | a dependency's macro expands to another value (`env_b`) | 1 → 2 | same: miss | same: miss | differ: **caught** | no hit |
| 2 | a dependency's struct gains a field (`sizeof`) | 8 → 16 | same: miss | differ | differ: **caught** | no hit |
| 3 | a supertype's owner adds `f3(::AbsT)` | 1 → 2 | same: miss | differ | differ: **caught** | no hit |
| 4 | a callee two levels down (`R4.k`, behind `Q4.h`) | 1 → 2 | same: miss | same: miss | differ: **caught** | no hit |
| 5 | the parent's extension, activated by loading `Y5` | 1 → 2 (`X5Ext`) | same: miss | same: miss | same | hit (`X5Ext`'s `g5`): **caught** |
| 6 | `SparseArrays` loaded first | `vcat`'s target `Base` → `SparseArrays` | same: miss | same: miss | same | hit (`SparseArrays`' `vcat`): **caught** |

In an unchanged session, and for the cases a change does not touch, nothing is caught: there are no false positives in these 24 checks.

The system image's standard libraries count as part of every closure. Without that, `LinearAlgebra`'s `vcat` hits in every session.

**What it says:** the note's revision 2 holds on all six cases, as predicted. The closure's build ids catch the four content cases, which a version-level identity misses entirely; a source hash of the direct origins misses two of them. The candidate index catches the two cases where no identity changes.

# E-195: entries identified by fingerprints scoped by the facts rule (W-66)

[The note](../../writeup/plans/2026-10-27-facts-keyed-cache.md) §5b, decided by the user ("let's build this now"). `Fingerprints.jl` computes an entry's identity from the session's method table and CodeInstances, with no Julia change:
- **F1:** its method's signature and lowered code, uncompressed and printed with global references by name. The compressed bytes differ between builds of the same source.
- **F2:** for each fact (each edge), the stakeholders' methods of its function, with their lowered code; and for a callee CodeInstance, its inferred result.
- **F3:** the layouts of the types in its signature, result and inferred code.

The candidate index takes the methods from outside each fact's stakeholders and the system image. `fp_probe.jl` records the six cases' entries in one session and checks them in another. The witness is the code as the compiler types and optimizes it there.

## Parts 1 and 2: the toy cases, 2026-10-27

E-193's six cases (variants `a`, `b`), and variants `c`, where each dependency changes something the entry does not use:
- `M1` gains a macro;
- `L2` gains a struct;
- `A3` gains a method of another function;
- `R4` gains a function.

Recorded in `env_a`; logs `logs/fp-*.log`.

| Check | Cases | Result |
|---|---|---|
| `env_b` (the changes) | 1–4 | code differs; fingerprints differ (1: F1; 2, 3, 4: F2): caught |
| `env_b` | 5, 6 | code and fingerprints the same: kept |
| `env_c` (unused changes) | 1–6 | code and fingerprints the same: **kept**, where the closure's build ids would invalidate all four changed dependencies' dependents |
| `env_a` with `Y5` | 5 | code differs; F2 differs and the index hits (`X5Ext`): caught |
| `env_a` with `SparseArrays` | 6 | the index hits: caught. The printed code shows no change, while the dispatch target changed (E-193): conservative |
| `env_a` again | 1–6 | all kept |

No case is kept where its code differs (30 checks). The one conservative call is SparseArrays, where the witness misses the changed target.

Two faults found in the first run and fixed: the code witness read facts CodeInstances' inferred code, which is not kept; and F1 hashed the compressed source, which differs between builds.

## Part 3: at scale, 2026-10-27

C (`experiments/ttfx/env_core`: upstream SciML compiled by facts as trait modules, with CairoMakie; the product setting) runs the perturbed workload. Every facts CodeInstance the session made that names no session type is an entry. Recorded in `env_core`; checked in `env_core_fw`, the same environment with FunctionWrappers dev'd from `pkgs/FunctionWrappers_fw`, which adds an unused function `unused_by_e195` (45 dependents rebuilt), and in `env_core` again. julia-1.13 41d199c557, TraitWorld 5589f4c, one session each.

```
X_MODE=record X_FILE=../w66/logs/fp-scale-C.jls WL_SHAPE=perturbed OPENBLAS_NUM_THREADS=1 \
  julia --startup-file=no --compiled-modules=existing --pkgimages=existing --project=env_core \
  ../w66/fp_scale.jl workload.jl out/png            # from experiments/ttfx; X_MODE=check for the checks
```

| Run | Entries | Fingerprints equal | Index hits | Kept | Code differs | Unsound |
|---|---|---|---|---|---|---|
| 1 (`logs/run1-*`): F3 threw on abstract and vararg types, so only 185 entries | 185 | 185 | 0 | 100% | 0 | 0 |
| 2 (`logs/run2-fp-scale-summary.log`, `logs/fp-scale-C.jls`), against `env_core_fw` | 2,143 | 2,143 | 35 | 2,108 (98.4%) | 0 | 0 |
| 2, against `env_core` again | 2,143 | 2,143 | 35 | 2,108 (98.4%) | 0 | 0 |

- Under the closure's build ids the same update loses 86–90% of C's entries (E-194). The fingerprints keep all of them.
- The 35 index hits are the same in both checks: candidates the entries already saw when they were recorded. The index of revision 2 flags any method from outside a fact's stakeholders that intersects it. Part 4 compares against the candidates seen at record.
- The witness is weak here: nothing the entries use changed, so no code differs. Soundness rests on parts 1 and 2.
- Run 2's per-session logs were overwritten by run 3, which failed at load: a cache file of the shared depot was replaced in between (`logs/run3-failed-*`). The summary lines are kept from the task's output.

## Part 4: the index against the candidates seen at record, 2026-10-28

`fp_scale.jl` records, per entry, its candidates (methods from outside a fact's stakeholders and the system image that intersect the fact) by fingerprint and name; a check flags an entry only if its candidates now differ. julia-1.13 41d199c557 with W-22's edits built, TraitWorld 5589f4c with W-22's edit, `depot-C` precompiled again (`env_core_fw` 132.6 s); one session each (`logs/part4-*.log`, `logs/part4-C.jls`).

| Check | Entries | Fingerprints equal | Any candidate (revision 2's index) | A candidate not seen at record | Kept | Code differs |
|---|---|---|---|---|---|---|
| `env_core_fw` (FunctionWrappers update) | 2,143 | 2,143 | 35 | 0 | 2,143 (100%) | 0 |
| `env_core` again | 2,143 | 2,143 | 35 | 0 | 2,143 (100%) | 0 |

- The 35 entries' candidates are the same in every session. Most are methods of one SciML package's function at its own types, defined by another package of the same split family (`OrdinaryDiffEqDifferentiation` on `OrdinaryDiffEqCore.alg_autodiff`; `NonlinearSolveBase` on `solve`), or `Base.deepcopy_internal` methods of packages the facts' signatures do not name.
- So the index compares against the candidates the entry saw at record: a candidate is new, or gone, or changed. With it nothing is lost to imprecision here.

# E-199: which owners' code package images carry (the facts-first review §2.3, check (a)), 2026-10-28

`image_owners.jl` loads an environment's packages and counts the CodeInstances that came from package images, by owner, and those with machine code (an entry point set at load). julia-1.13 41d199c557 with W-22's edits built; product setting; one session each (`logs/e199-D.log`, `logs/e199-C.log`).

| Owner | D: from images | D: machine code | C: from images | C: machine code |
|---|---|---|---|---|
| `nothing` | 17,619 | 6,857 | 280,441 | 86,618 |
| `:facts` | 14,723 | 14,556 | 33,769 | 33,397 |
| TraitWorld's check owner | 4,401 | 4,391 | 550 | 545 |
| `:facts_plain_return_type` | 309 | 286 | 473 | 439 |

- The check owner's results and `return_type`'s answers never run, but get machine code (`add_foreign_codeinfos!`, compiler C-12). In D they are 4,677 CodeInstances with machine code beside 14,556 of the facts owner.
- So removing their machine code (§2.3) is worth a build: its image sizes and load times are check (b).

# E-201: machine code only for the owners whose code runs (the facts-first review §2.3, check (b)), 2026-10-28

julia-1.13 5071b67894 (images give machine code to `nothing` and `:facts` only; keep-compiled keeps only code of the facts owner), TraitWorld 0976025; the facts image and every depot rebuilt (C 301 s, D 38 s with four tasks; U 261 s, A 434 s with three; every package, since the system image changed). Logs `logs/e201/`, sessions `../ttfx/logs/e201/`, suites `../checks/logs/e201/`.

| | before (E-199, 8ceda6f9d6) | after |
|---|---|---|
| D: check owner, with machine code | 4,391 of 4,401 | 752 of 4,387 |
| D: `return_type`'s answers, with machine code | 286 of 309 | 48 of 309 |
| D: `nothing`, with machine code | 6,857 | 6,386 |
| C: check owner / answers, with machine code | 545 / 439 | 122 / 65 |
| C: `nothing`, with machine code | 86,618 | 84,084 |
| image of TraitWorld / TraitDifferentialEquations / TraitMakie | 52.0 / 21.3 / 22.3 MB | 48.6 / 18.4 / 19.6 MB |
| D session | 0.95–0.96 s | 0.94–0.96 s |
| C session (first solve) | 10.62–10.64 s (4.55) | 10.76–10.91 s (4.86–4.89) |
| U session | 9.10–9.32 s | 9.32–9.37 s |
| A session | 10.76–10.91 s | 10.92–10.94 s |

- The check owner's and the answers' CodeInstances that keep machine code are reached as callees of code that gets machine code; not diagnosed further.
- C's first solve is 0.3 s slower (7%) without the plain code keep-compiled kept: under the 20% that would have kept it. Its load is 0.1–0.2 s faster.
- Every suite passes; under `all` TraitWorld's standing failure only.

# E-202: the first-call checks' records (the facts-first review §2.4, check), 2026-10-28

julia-1.13 5071b67894, TraitWorld 0976025; perturbed shapes; one session each (`e202/D.log`, `e202/C.log`, `e202/edit_case.log`).
- `_note_checked_ahead!`, the walk over every name of every loaded package's modules after each load: 33 ms over D's 68 packages, 51 ms over C's 398 (timed again at the load mark).
- D's session runs 9 first-call checks. All 9 are for workers whose facts code came from an image: the image keeps the code but not that it passed. Running their rule checks again takes 62 ms. C runs the same 9.
- So about a tenth of D's 0.95 s session goes to work the image already did: the checked-record of §2.4 is worth building.
- The edit case (`e202/edit_case.jl`): `Core.eval(M, :(sq(v::Values) = …))` in a finished trait module is accepted but defines another method; the entry keeps calling the generated worker, and the call gives the old result. What a redefinition should do is open issue 79.
