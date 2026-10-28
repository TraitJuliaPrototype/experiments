# W-81: open issues 82 (a) and 83 built

Traits reference §6.5 (a kept value is seen at a bound through every trait its object conforms to; a kept function at another signature is checked there) and §5.8 (a `Callable`'s argument types may follow the other arguments). TraitWorld dc10167; tests `TraitWorld/test/capabilities.jl`, `test/wherevars.jl`.

How to run: `julia --project=../../TraitWorld <script>.jl` with the patched Julia.

| Script | What | Result (2026-10-28, julia-1.13 a4e9ad5da9) |
|---|---|---|
| `capabilities.jl` | a `Vector{Dynamic{Col}}` with a plain and a pooled column; `kind(c::Col)` and `kind(c::(Col, Pooled))` | `[:plain, :pooled]`; a `Dynamic{Shape}` there: `TraitBoundError`; a kept function at a signature with a method: called; without one whose result can be the declared type: `TraitBoundError` |
| `callable_follows.jl` | `count_if(f::Callable{Tuple{T}, Bool}, xs::Iterable{T}) where {T}`; `T` fixed by a plain argument too | correct for `Int` and `Float64` items; a variable no other argument fixes refused at the definition |
| `alloc_compare.jl` | a typed call, the following form against a fixed signature | the same allocation (96 bytes, from the `Iterable` entry, not the new form); no slower |

Every suite passes (`experiments/checks/logs/w81/`); TraitDifferentialEquations' two tests that expected the old errors now expect `TraitBoundError` at the bound (TDE ef12c54).
