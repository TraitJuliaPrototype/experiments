# W-81: open issues 82 (a) and 83 built

Traits reference §6.5 (a kept value is seen at a bound through every trait its object conforms to; a kept function at another signature is checked there) and §5.8 (a `Callable`'s argument types may follow the other arguments). TraitWorld dc10167; tests `TraitWorld/test/capabilities.jl`, `test/wherevars.jl`.

How to run: `julia --project=../../TraitWorld <script>.jl` with the patched Julia.

| Script | What | Result (2026-10-28, julia-1.13 a4e9ad5da9) |
|---|---|---|
| `capabilities.jl` | a `Vector{Dynamic{Col}}` with a plain and a pooled column; `kind(c::Col)` and `kind(c::(Col, Pooled))` | `[:plain, :pooled]`; a `Dynamic{Shape}` there: `TraitBoundError`; a kept function at a signature with a method: called; without one whose result can be the declared type: `TraitBoundError` |
| `callable_follows.jl` | `count_if(f::Callable{Tuple{T}, Bool}, xs::Iterable{T}) where {T}`; `T` fixed by a plain argument too | correct for `Int` and `Float64` items; a variable no other argument fixes refused at the definition |
| `alloc_compare.jl` | a typed call, the following form against a fixed signature | the same allocation (96 bytes, from the `Iterable` entry, not the new form) and time: 145.7 against 145.2 ns per call, then 145.9 against 146.5 (minimum of five rounds of 10^5 calls, inside a function) |

Every suite passes (`experiments/checks/logs/w81/`); TraitDifferentialEquations' two tests that expected the old errors now expect `TraitBoundError` at the bound (TDE ef12c54).

## E-210: SciML's X1, one right-hand side seen at the duals (2026-10-28)

TraitDifferentialEquations 59571a2 (branch `w34`) against ef12c54: the problem keeps one function; the Jacobian by duals passes it to `_ad_jacobian!(f::Callable{CoreDualSig{N}, Nothing}, …, ::Val{N}) where {N}`, and Rodas5's chunk at `init` sees it the same way; the second kept function at the duals (`fd`, parameter `D`) is gone. julia-1.13 a4e9ad5da9, TraitWorld dc10167; `x1/measure.jl` (two fresh processes per version; a Jacobian call the best of five rounds of 10^5), `x1/session-*.log`.

| | two functions (ef12c54) | one function (59571a2) |
|---|---|---|
| the session's `RESULT` lines | 9 | the same 9; the plain session's 9 the same |
| Rodas5's first solve, timed whole | 51.4, 53.5 ms | 51.6, 51.2 ms |
| `Rodas5(chunk_size = 0)` | 20.4, 19.5 ms | 19.1, 19.1 ms |
| a Jacobian call, `Dynamic` / compiled | 4.46–4.50 / 0.84–0.85 µs | 4.32–4.40 / 0.81–0.83 µs |

The suite passes. One change on the way: a function the user made `Dynamic` at another signature is now partially evaluated as the user's function itself with the kept attribute, so that the one function is seen at the duals too (`_partial`).
