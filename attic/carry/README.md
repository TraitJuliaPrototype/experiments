# W-18: values carry their attribute through storage

E-149 ([the registry](../../writeup/record/experiments.md)): what keeping values as `Kept{X}` costs against `Dynamic{X}`.

**How to run:** `julia --project=../../TraitWorld e149.jl` (one Julia job at a time, niced). A few minutes.

## Results (2026-10-21; julia-1.13 6d480d0753, TraitWorld 1d09112 plus the session's follow-up, uncommitted at the run; product setting; one session, minimum of 20 runs per row; machine otherwise idle)

Log: `e149.log`.

| Row | 4 types | 8 types |
|---|---|---|
| sum of one operation over `Vector{Dynamic{Shape}}` | 0.96 ns/elt, 0 B | 4.19 ns/elt, 0 B |
| sum of one operation over `Vector{Kept{Shape}}` | 1.25 ns/elt, 0 B | 4.39 ns/elt, 0 B |
| `total(::Vector{Any})` through the view (items read as `Kept{Shape}`) | 3.04 ns/elt, 80 B per call | 9.58 ns/elt, 80 B per call |
| `total(::Vector{Dynamic{Shape}})`, met as it is | 1.23 ns/elt, 64 B per call | 4.64 ns/elt, 64 B per call |
| `total(::Vector{Kept{Shape}})`, met as it is | 1.15 ns/elt, 64 B per call | 4.44 ns/elt, 64 B per call |
| `push!` from untyped plain code, `Dynamic{Shape}(x)` | 109 ns/elt, 32 B/elt | 110 ns/elt, 32 B/elt |
| `push!` from untyped plain code, `Kept{Shape}(x)` | 109 ns/elt, 48 B/elt | 111 ns/elt, 48 B/elt |

- Reading a `Kept{X}` allocates nothing, from a container of them or through the view over a `Vector{Any}`. While W-18 was built, the first form, a union of `Compiled{X}` and `Dynamic{X}`, allocated 16 bytes per item read through the view (3,248 against 48 bytes for 200 items).
- An operation on a `Kept{X}` costs 0.2–0.3 ns more than on a `Dynamic{X}`.
- The `push!` rows measure mostly a constructor called at run time from untyped code (the value's box is the call's result); they are not a measure of storing a value in typed code, where a `Kept{X}` is stored inline.

## E-197: one varargs wrapper behind an erased function's pointer (T-51), 2026-10-28

`e197/e197.jl` copies TraitWorld's `Erased` with one wrapper `(::W{S})(o, args::Vararg{Any,N}) where {S,N}` and no arity limit, and measures it against TraitWorld's fixed arities (up to six) and a direct call: a loop of 10^6 erased calls, best of five; and the wrapper's code at the `cfunction`'s signature. julia-1.13 41d199c557 with W-22's edits built, TraitWorld 5589f4c; one session (`e197/e197.log`).

| Arguments | `Float64`, varargs | `Float64`, fixed | non-bits, varargs | non-bits, fixed |
|---|---|---|---|---|
| 1 | 4.01 ns | 4.01 ns | 8.68 ns | 9.02 ns |
| 3 | 4.13 ns | 4.02 ns | 18.32 ns | 18.76 ns |
| 6 | 4.73 ns | 4.72 ns | 32.5 ns | 33.29 ns |
| 8 | 4.9 ns | — | 41.28 ns | — |
| 12 | 6.93 ns | — | 62.31 ns | — |

- The non-bits argument (an immutable struct holding a vector) allocates 16 bytes per argument per call in both forms: the caller boxes it for the `Any` slot.
- The wrapper's code calls no generic function at any arity: `getfield` and the callee's own operations.
- So TraitWorld's `_CallWrap` is one varargs method, and the six-argument limit is gone (TraitWorld 6928b93; T-51 retired).
