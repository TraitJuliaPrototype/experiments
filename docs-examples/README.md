# The documentation's examples

Runnable forms of the examples in [`writeup/intro/`](../../writeup/intro/). Each script checks the results the pages state and prints one `PASS` or `FAIL` line per check, then a tally. It exits with 1 if a check fails. Some print the messages of the errors they provoke, as `MESSAGE` lines, so a page can quote them.

| Script | What it runs |
|---|---|
| `intro.jl` | the worked example of `traits-for-julia.md`: the library `Columns` and its user |
| `tutorial.jl` | `traits-by-example.md` §2–§17, in the page's order: the libraries `Geometry`, `Signals`, `Dots`, `Seqs`, `Weights`, `Strictly` and the user's code |
| `strict.jl` | `traits-by-example.md` §18, strict mode, in its own process (it changes Base's methods) |
| `common.jl` | `check`, `thrown` (a statement that must fail, evaluated at top level), `outcome`, `msg`, `summary` |
| `reference.jl` | the examples of the earlier references, on `julia-1.13/` with TraitWorld `main`; not run on the unified build |

The tutorial's §19 (a package's layout) and §20 (planned) are not run.

**Running.** One Julia process at a time; the machine is shared. On the unified build, from `TraitWorld-unified/` (branch `unified`):

```sh
source ../env.sh
cd TraitWorld-unified
for s in intro tutorial strict; do
  JULIA_PKG_OFFLINE=true nice -n 19 ../julia-unified/julia --project=. --startup-file=no ../experiments/docs-examples/$s.jl
done
```

They need the unified build (`julia-unified/`); TraitWorld does not run on stock Julia.

## Results

| Date | Build | intro | tutorial | strict |
|---|---|---|---|---|
| 2026-11-09 | `unified` 6767b03893, TraitWorld `unified` c9f701e | 18 pass | 83 pass | 5 pass |

Each row's output, with the messages the pages quote: `logs/<script>-<TraitWorld commit>.log`.
