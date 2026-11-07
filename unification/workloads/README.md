# The first slice's workloads (W-106)

Two programs written with the library on the unified build (TraitWorld, branch `unified`), each beside the same program in plain Julia, where the traits are abstract types and the members their declared subtypes. W-106's gate: equal results; and the stopgap's volume at each membership.

## How to run

```sh
source env.sh
julia-unified/julia --startup-file=no --project=TraitWorld-unified experiments/unification/workloads/columns.jl
julia-unified/julia --startup-file=no --project=TraitWorld-unified experiments/unification/workloads/ode.jl
JULIA_MEMBERSHIP_LOG=1 julia-unified/julia … columns.jl     # the stopgap's volume per membership
```

- `columns.jl`, shaped like a column store: `Column{T}` with `T = eltype(Self)`, a default (`csum`), a family member by its own methods (`Stored{T}`), a member by forwarding (`Named by col`), a member by its own methods (`Ramp`), functions at the trait (`colmean`, `spread`), a `Vector{Any}` of members and `Dynamic{Column{Float64}}` values.
- `ode.jl`, shaped like ODE algorithms: `ODEAlgorithm` with a value fixed per member (`alg_order`), an operation that mutates (`step!`), a default (`name`) one member overrides, three members by their own methods, `solve` at the trait, and `Dynamic{ODEAlgorithm}` values.

## Results (2026-11-07; `unified` at the member hook's commit, TraitWorld e7ff8e2; one run each)

- **Equal results:** both programs give the plain programs' results exactly (`==`, including the floating-point states).
- **The stopgap's volume** (`logs/*-volume.log`; the counters are cumulative over a session):

| Membership | replays | methods visited | cache entries lowered |
|---|---|---|---|
| `Dynamic{Z} where Z <: Column{T}` in `Column{T}` (at `@trait`) | 3 | 0 | 2,905 |
| `Stored{T} where T` in `Column{T}` | 3 | 0 | 77 |
| `Named` in `Column{Float64}` | 3 | 0 | 38 |
| `Ramp` in `Column{Float64}` | 3 | 0 | 34 |
| `Dynamic{Z} where Z <: ODEAlgorithm` in `ODEAlgorithm` | 3 | 0 | 0 |
| `Euler`, `Midpoint`, `RK4` in `ODEAlgorithm` | 3 each | 2 to 3 each | 0 |

  The parametric trait's first membership, `Dynamic`'s pattern, lowers 2,905 method-cache entries: the walk's conservative path for a pattern member. The other memberships lower tens or none. No CodeInstance in a loop is invalidated here; E-268 measures the ports' sessions.
- **A finding the ODE program made:** a member's own `step!(::Euler, u, f, t, dt)`, with untyped further arguments, was ambiguous with the trait's method, which typed them as declared. The trait's method now types only the receiver and the arguments that bind a parameter (lowering §2), so the member's own method wins as traits §4.2 says.
