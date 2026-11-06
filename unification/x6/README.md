# E-267 (X6): `Callable` by a memoized method-table query inside subtyping

The work plan's §8, X6 (the user, 2026-11-06: "Adopt, keys as optional is approved. Run the X now"). Registry
row: `writeup/record/experiments.md` E-267. The draft's mechanism ([compiler §7.4](../../../writeup/reference/compiler.md#74-callables-call)):
`F <: Callable{A, S}` holds where `F` has a method at `A` (`hasmethod`); the answer is a query of `F`'s method
table, memoized per (`F`, `A`) with its world range; a query that reaches itself again answers no.

## How to run

```sh
source env.sh
JULIA_NUM_THREADS=1 nice -n 19 $J --startup-file=no experiments/unification/x6/x6.jl   # out/x6.txt
```

Parts (1) and (2) emulate the mechanism in plain Julia on julia-1.13 00dcc9994c (no build of the draft exists).
Part (3) is read in the runtime's source at the same commit.

## Results (2026-11-06; one thread, machine load 5 of 128 cores)

**(1) Cost** (`out/x6.txt`). 1,000 closure types, `A = Tuple{Int}`; per call, medians of five rounds:

| | ns |
|---|---|
| the query (`jl_gf_invoke_lookup_worlds`), the first call per closure type | 1,372 (90th percentile 1,813) |
| the query repeated (a memo miss on a type seen before) | 75 |
| a memo hit (an `IdDict`, the world range checked) | 18 |
| `typeof(f) <: Function` | 18 |
| `f isa Function` | 0.4 |
| E-256's entry today (the registry row) | 80–96 |

The memo goes stale without help: a memo entry for `gtest` at `Tuple{Int}` (no method, valid from world 0 to
∞) still claims the old answer after `gtest(::Int)` is defined. The lookup's own range is open-ended at the
latest world, so method insertion must lower the memo, as the draft says.

**(2) A query that reaches itself.** In Julia's terms:

```julia
function p end; function q end
p(x::Callable{Tuple{typeof(p)}}) = 1      # m1
p(x::Function) = 2                       # m2
q(y::Callable{Tuple{typeof(q)}}) = 3
```

- `a`: is `p` callable at `q`? m1 needs `b`; m2 holds.
- `b`: is `q` callable at `p`? Its one method needs `a`.
- The least fixed point is `a = b = true`, so `q(p)` has a method.

| Rule | `a` asked first | `b` asked first |
|---|---|---|
| the draft's: memoized, a query that reaches itself answers no | `a` true, **`b` false** | `b` true, `a` true |
| a provisional cache: no result kept that read an assumption until its cycle's head is final (as Rust's trait solver does) | both true | both true |

Under the draft's rule, whether `q(p)` has a method depends on which question the session asked first.

**(3) Where the runtime runs subtyping that a method-table query would run inside** (julia-1.13 00dcc9994c):

| Context | Where | What a query there would mean |
|---|---|---|
| Method insertion: `jl_method_table_insert` holds `world_counter_lock` while `jl_method_table_activate` runs | `src/gf.c:3474–3481`; inside it specificity (`:3338`), intersection (`:3384`), `_invalidate_dispatch_backedges` (`:3396`), and under the method cache's `writelock` the cache walk (`:3430`, `:3442`) | A `Callable` membership changes exactly here: defining `f(::Int)` makes `typeof(f)` a member at `Tuple{Int}`. The walk must find what relied on the old answer, so it must ask the query in the world being made, whose method has `primary_world` set but not yet published (`:3477–3480`), for every memoized `A` of `F`, under the lock. |
| Package images: `jl_activate_methods` under `world_counter_lock` | `src/staticdata.c:4463–4474` | The same, batched over an image's methods. |
| The dispatch slow path: `jl_mt_assoc_by_type` holds the method cache's `writelock` and calls `ml_matches` | `src/gf.c:2164`, `:1903` | A query nested in a query, under the same recursive lock: possible, already the case for dispatch. |
| The type cache: `inst_datatype_inner` holds `typecache_lock` while it computes field types, which normalize unions through `simple_subtype` → `jl_subtype` | `src/jltypes.c:2308–2460`, `:2445`, `:578` | A method-table lookup under the type cache's lock. Closed by P-21 (normal forms read declared supertypes only), which keeps memberships out of normalization. |

## What it means

- **The registered criterion is met: M4 before N8.**
  - The first query per closure type (1.4 µs) costs more than an entry today (80–96 ns). A repeated query (75 ns) does not.
  - More decisive: the draft's rule for a query that reaches itself gives answers that depend on the order of queries (2).
  - The membership changes inside method insertion, under its lock, in a world not yet published (3).
- **The form M4 can take (mine, for the draft's §7.4).** The method table already holds what a stored membership would:
  - each method `f(x::T₁, …)` of `F` stands as `F`'s membership in `Callable{A, S}` for every `A <: Tuple{T₁, …}` and every `S`, with the method's world range;
  - subtyping reads `F`'s methods as it reads entries, through the method table's index by the function's type, checking `A <: Tuple{T₁, …}` in the same subtyping environment.
  - There is no memo of its own, so no stale answer and no order: a cycle is subtyping's own assumption within one query, recomputed at each top-level query, which gives the least fixed point in (2).
  - Method insertion adds the membership by adding the method. What relied on the old answer is then found as for any membership (the stopgap, or guards).
  - `hasmethod`'s rule is the same: one method must cover `A`.
- **Not measured:** the cost of reading `F`'s methods inside subtyping at a real call. It is a typemap scan of one function's methods with a subtype check per method, bounded by the function's method count.
