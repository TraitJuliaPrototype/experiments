# Keys prototype: conformances as methods, a lean entry, one layout per key (session 22)

A standalone prototype (no TraitWorld) of how the keys design can be implemented simply. Stock Julia 1.13.2, run alone at `nice -n 19`.

- **`p.jl`**:
  - a trait object `TO{X, K}` holds the implementing value (typed by the key) and the user's object when it is mutable (`nothing` otherwise), plus the forwarding field's offset;
  - reads of a mutable object's parts go through the object, with Julia's alias metadata;
  - the conformance is a method, `view(::Type{ColTable}, u::Meas) = TO{…}(…)`, with constants;
  - the entry is an ordinary method that calls the worker on `view(X, t)`;
  - the worker is compiled once per key.
- **`n.jl`:** the entry declared `@inline` with `@nospecialize` on the trait argument.
- **`c.jl`:** compile cost of entries specialized per user type.

ns per call of `total(t, 16)` (4 columns × 16 elements), against plain Julia 25–29 ns:

| | own type | forwarding, immutable | forwarding, mutable |
|---|---|---|---|
| specialized entry, typed caller | 25.8–26.5 | 25.9 | 27.9–29.3 |
| specialized entry, untyped caller | 29.1–31.3 | 28.0–30.5 | 30.2–33.5 |
| `@nospecialize @inline` entry, typed caller | 26.5 | 26.4 | 29.5 |
| `@nospecialize @inline` entry, untyped caller | 28.6 | 29.4 | 33.6 |

Notes:
- **At 4096 elements every case matches plain Julia;** there is no allocation per call, and one worker serves all three user types.
- **An immutable user type is held, not referenced.** In a version that put every user object in an `Any` field, an immutable type was boxed: 32 bytes per call and 40 ns. Holding its parts is semantically identical, because none of its fields can be rebound.
- **Specialized entries compile per function and user type.** That costs about 4 ms each: 34 ms for the first, then 42 ms for 10 more.
- **`@nospecialize @inline` entries compile once per function** (51 ms for 10 entries, the first type). A second new type through the same 10 entries costs 16 ms in all, mostly its conformance method. Typed callers inline the entry and get the static path, with that small compile charged to the caller.
- **For comparison, TraitWorld at a750ecd** (the reference layout in the existing entry machinery: entry caches, builders, `checked_call` reached by dispatch) costs 209–230 ns (own) and 424–460 ns (forwarding) for the same call. Before phase 3, at ca9b8a9, it cost 252 / 396 ns. The fixed path around the call dominates.
