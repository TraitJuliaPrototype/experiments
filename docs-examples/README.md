# The documentation's examples

Runnable forms of the examples in [`writeup/intro/traits-by-example.md`](../../writeup/intro/traits-by-example.md) and [`writeup/reference/traits.md`](../../writeup/reference/traits.md). Each script checks the results the pages state and prints one `PASS` or `FAIL` line per check, then a tally. It exits with 1 if a check fails.

| Script | What it runs |
|---|---|
| `tutorial.jl` | the tutorial's §2–§17, in the page's order: the libraries `Geometry`, `Signals`, `Weights` and the user's code |
| `strict.jl` | the tutorial's §18, strict mode, in its own process (it changes Base's methods) |
| `reference.jl` | the reference's examples the tutorial does not run, and its Deviations (checks named `T-n`) |
| `common.jl` | `check`, `thrown` (a statement that must fail, evaluated at top level), `summary` |

The tutorial's §19 (a package's layout) and §20 (planned syntax) are not run; `reference.jl` checks that the planned forms do not work yet.

**Running.** One Julia process at a time; the machine is shared. From `TraitWorld/`:

```sh
cd TraitWorld
for s in tutorial strict reference; do
  JULIA_PKG_OFFLINE=true nice -n 19 ../julia-1.13/julia --project=. --startup-file=no ../experiments/docs-examples/$s.jl
done
```

They need the patched Julia (`julia-1.13/`); TraitWorld does not run on stock Julia.
