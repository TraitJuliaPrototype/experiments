# W-149: kept values. What storage holds, and `Kept{X}`

The decision (the user, 2026-11-11): what is stored is decided by the storage's type, never by the caller's attribute, with `Kept{X}` for storage that carries the attribute. Reference: `writeup/reference/traits.md` §7.8, §8.1. The case that led to it: open issue 175 (closed), `../../docs-examples/keep_at_prompt.jl`.

## How to run

From `TraitWorld-unified/`, after `source ../env.sh`:

```
../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w149/keep_or_not.jl
../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w149/convert_probe.jl
../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w149/kept.jl
../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w140/load_invalidations.jl
```

## Results, 2026-11-12 (one run each; `unified` 22db66e23c, the baseline b1c0b50f4c for the first two; load 1 to 5 of 128)

| Question | Result |
|---|---|
| What does storage typed by the trait hold, with `keep` and without? (`keep_or_not.jl`) | With `keep`: the object from typed code, a `Dynamic{Shape}` from untyped code. **Without `keep`: the object from both** |
| Can assignment unwrap a `Dynamic{X}`? (`convert_probe.jl`) | No. `push!`, a field and a declared result call no `convert` for a value that is of the slot's type, and a `Dynamic{X}` is a member. One method `convert(::Type{T}, ::Dynamic{<:T})` is never reached, and logs 7,005 invalidation entries at its definition |
| `Kept{X}` (`kept.jl`, `kept.log`) | One stored type from typed and untyped code; the attribute beside the object; `kept_call` runs the code compiled once for the item kept `Dynamic` and the code compiled for `Circle` for the one kept `Compiled` (the method's two instances) |
| What do `Kept{X}`'s conversions cost at the library's load? (`load_invalidations.jl`) | `convert(::Type{Kept{X}}, x)`: nothing, 65 log entries as before. A method `convert(::Type{T}, ::Kept{<:T})`, so that storage typed by the trait would take a `Kept`: **6,863 log entries**. Not kept: `unwrap(k)` is assigned there |
| The ports' `keep` sites | TraitDifferentialEquations: 8 sites; 6 of them keep a callback into a `Vector` typed by the trait (`lib/ODECore/src/core.jl`), which the rule excludes. To change when the ports are brought to the head |
