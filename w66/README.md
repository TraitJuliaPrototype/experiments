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
