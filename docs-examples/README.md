# The documentation's examples

Runnable forms of the examples in [`writeup/intro/`](../../writeup/intro/). Each script checks the results the pages state and prints one `PASS` or `FAIL` line per check, then a tally. It exits with 1 if a check fails. Some print the messages of the errors they provoke, as `MESSAGE` lines, so a page can quote them.

The pages state the design ([`writeup/reference/traits.md`](../../writeup/reference/traits.md)). Where the implementation is known to differ for an example, the script checks the design's outcome with `deviation(name, id, f)`: it prints `PASS` where the design's outcome holds, and otherwise `DEVIATION <id> <name>`, naming the reference's deviation row (or `no row`). Deviations are counted apart from pass and fail, and do not fail the script.

| Script | What it runs |
|---|---|
| `intro.jl` | the worked example of `traits-for-julia.md`: the library `Columns` and its user |
| `tutorial.jl` | `traits-by-example.md` §2–§17, in the page's order: the libraries `Geometry`, `Signals`, `Dots`, `Seqs`, `Weights`, `Strictly` and the user's code |
| `strict.jl` | `traits-by-example.md` §18, strict mode, in its own process (it changes Base's methods) |
| `keep_at_prompt.jl` | uses `keep`, which neither the design nor the library has; not run |
| `common.jl` | `check`, `deviation`, `thrown` (a statement that must fail, evaluated at top level), `outcome`, `msg`, `summary` |
| `reference.jl` | the examples of the references as they stood in October 2026, for the library of that month; not run |

The tutorial's §19 (a package's layout) and §20 (planned) are not run.

**Running.** One Julia process at a time; the machine is shared. On Julia with the design's changes (`julia-next/`), from `TraitWorld/` (branch `unified`):

```sh
cd /p/projects/coen/julia-trait-bound && source env.sh
cd TraitWorld
for s in intro tutorial strict; do
  JULIA_PKG_OFFLINE=true nice -n 19 ../julia-next/julia --project=. --startup-file=no ../experiments/docs-examples/$s.jl
done
```

TraitWorld does not run on stock Julia. The pages and the scripts write `compiled_for` as the library's export, the wrapper's function (`intro.jl` checks it).

## Results

| Date | Build | intro | tutorial | strict |
|---|---|---|---|---|
| 2026-11-09 | `unified` 6767b03893, TraitWorld `unified` c9f701e | 18 pass | 83 pass | 5 pass |
| 2026-11-11 | `unified` binary 36b653bb3b with local changes (the branch at 564a2288e2), TraitWorld `unified` 05991fc | 18 pass | 85 pass (two checks added for §12's kept item) | 5 pass |
| 2026-11-11 | `unified` dd3f6d839b, TraitWorld `unified` 158d000 (the messages' form, E-362) | 18 pass | 85 pass | 5 pass |
| 2026-11-12 | `unified` 22db66e23c, TraitWorld `unified` 4a1dc03 (W-149: §12 stores without `keep`, and shows `Kept`) | 18 pass | 86 pass | 5 pass |
| 2026-11-14 | `unified` 381cc8b953, TraitWorld `unified` 78a78af (`@unbounded`; `fully_typed` as the build's check; errors at the user's line) | 18 pass | 86 pass | 5 pass |
| 2026-11-14 | `unified` add2f921c9, TraitWorld `unified` 12b8b31 (a `Callable`'s check in every instance; its absence edge narrowed) | 18 pass | 86 pass | 5 pass |
| 2026-11-18 | `next` 32a2235abd, TraitWorld `unified` d1febca (the pages and scripts on the box and the wrapper) | 24 pass, 3 deviations (T-126, T-127, no row) | 94 pass, 1 deviation (T-127) | 5 pass |
| 2026-11-18 | `next` 02139b2168, TraitWorld `w156` ea72682 (the attribute's surface removed: the exported `compiled_for` is the wrapper's function, no module option decides how an argument is compiled) | 26 pass, 1 deviation (no row) | 95 pass | 5 pass |
| 2026-11-21 | `next` f5328f94c5, TraitWorld `w158b` e32d443 (`withfields` on a kept form, so §11's `nudged` is bounded; the bounded check's message names the method as written, open issue 235) | 27 pass | 96 pass | 5 pass |

On the row of 2026-11-18, `tutorial.jl` ended twice in six runs with a segmentation fault while `@trait Named` (its line 36) was expanded: a lookup in a method table's cache (`jl_mt_find_cache_entry`, `jl_object_id`) from the library's `_parse_body` (`logs/tutorial-next-32a2235abd-b-segfault.log`). The other runs, and every run of `intro.jl` and `strict.jl`, ended normally.

`keep_at_prompt.jl` on the build of the second row of 2026-11-11 (`logs/keep_at_prompt-05991fc.log`): at the prompt the item is a `Dynamic{Shape}`, not a `Scalable`, not `==` the circle, and the scene counts 0 scalable items; from a function it is the `Circle`, a `Scalable`, `==`, and the count is 1.

Each row's output, with the messages the pages quote: `logs/<script>-<TraitWorld commit>.log`; on `next`, `logs/<script>-next-<julia commit>.log`, and for the row of 2026-11-18 `logs/<script>-next-32a2235abd-b.log`.
