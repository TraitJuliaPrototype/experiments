# W-145: the measurement round (phase 5)

The round's plan, with the frozen build and the parts: [`writeup/plans/2026-11-14-measurement-round.md`](../../../writeup/plans/2026-11-14-measurement-round.md). Parts that have scripts of their own are here; the others run the scripts of `../w134/`, `../w135/`, `../w136/`, `../w139/`, `../w140/`, `../w120/`. Current numbers: [the evidence](../../../writeup/design/evidence.md).

## Part 1: calls (`calls/`, E-374)

```
source ../../../env.sh
cd calls && ../../../../julia-unified/julia --startup-file=no --project=../../../../TraitWorld-unified calls.jl [N]
```

A trait module (`T`), a user's module with a member (`U`) and a plain module with the same functions (`P`). Each row is a loop of N calls (10^7), the minimum of 7 runs, in ns a call. Idiomatic trait code, product setting, strict mode off.

| Date, build | Row | Trait form | Plain |
|---|---|---|---|
| 2026-11-14, `unified` 86deee2f98, TraitWorld baadf9f; two processes, load 4 of 128 (`calls/logs/calls-1.log`, `calls-2.log`) | 1 an operation at a known type | 0.79 | 0.79 |
| | 2 a method at the trait, at a known type | 0.79 | 0.79 |
| | 3 a trait with a `Dynamic` default | as it is (compiled once) 8.26–8.29; `compiled_for` 2.38 | 2.38 |
| | 4 an element of a vector of two types | `Vector{Shape}` 2.86–2.87 | abstract 2.69–2.70; union 3.18–3.19; one type 2.28 |
| | 5 a field | `::Dynamic{Shape}` 5.55–5.56 | abstract, two subtypes (split) 0.79 |
| | 6 a function argument, cast at each call | `compiled_for(f)` 1.34; `with_dynamic(f)` 344–352 | 0.79 |

Reading:
- Rows 1, 2 and row 3 with the cast: a plain call's cost.
- Row 6, `compiled_for(f)`: the call is an `invoke` of `apply` at the function's type, where the plain call is inlined: 0.55 ns a call.
- Row 6, `with_dynamic(f)`: the call is `Core.attributed_call(bits, apply, f, x)`, a run-time call whose result is `Any`, so the loop's value is boxed. The same code reached by a trait's default (row 3) is resolved when compiled, and with the cast outside the loop it costs 23.9 ns (E-371).
- Row 5: plain Julia splits a field of an abstract type with two subtypes; the `Dynamic{Shape}` call goes through the firewall.
