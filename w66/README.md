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
