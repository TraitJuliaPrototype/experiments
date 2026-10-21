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
