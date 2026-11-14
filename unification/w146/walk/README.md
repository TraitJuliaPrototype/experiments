# W-146, item 4: the membership walk's conservative path (compiler C-88 (c))

`disabled.jl <packages>`: which methods the walk replays conservatively at a load, and how often. Logs in `logs/`.

## Results, 2026-11-14 (E-390)

`unified` 8fccf1e182 against 9c6c9270f3; TraitWorld 2072e75, forks 439bae7; product setting, strict mode off; load 2 to 3 of 128. Current numbers: [the evidence](../../../../writeup/design/evidence.md).

- **Before:** eight methods took the conservative path at the load of the forks' CSV and DataFrames, 116 replays. Five are DataFrames' methods at `CellVector`, a struct whose parameter is bounded by the trait `Column` (`size`, `getindex`, `IndexStyle(::Type{<:CellVector})`, two constructors); two name an intersection `All{…}`; one names `Dynamic{Z}` with `Z` bounded by `Callable`. (The list came from a recorder in the runtime, not committed.)
- **The fix:** the walk substitutes the member under a union, in a tuple's component, in an intersection, and in the bound a type declares for its own parameter ([compiler §5.5](../../../../writeup/reference/compiler.md#55-a-membership-invalidates-as-a-method-does)). Gate `../gates/n32_nested_set.jl`.
- **After** (`logs/forks.log`, `logs/load-forks.log`, `logs/walk_work.log`): no method takes the path. The load's log holds 1,228 instances (2,289; the control without the walk 1,220).

| `../w145/loads/walk_work.jl`, 3 processes a mode | the walk invalidating | the control |
|---|---|---|
| the first `describe`, before | 800–804 ms | 137–141 ms |
| the first `describe`, after | 121–126 ms | 116–124 ms |

- The forks' REPL session: 2.61–2.62 s (4.00–4.06 s on the round's freeze; `../e289/logs/forks-unified-w146c.log`).
