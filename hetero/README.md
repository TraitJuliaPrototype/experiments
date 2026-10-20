# Heterogeneous collections in the facts mode (2026-10-20)

The experiments behind `writeup/reviews/2026-10-20-heterogeneous-collections.md`: `filter!` and `Dict` iteration on containers of `Any` from trait code (hc1, hc4, hc7, the product setting), union splitting at one and at two union arguments (hc2, hc6), `Dynamic` beyond four implementations (hc3), the dispatch profiler on the tails (hc5). Logs `e*.log`, `explore2.log`.

Run one at a time, from the repository root, e.g. `julia-1.13/julia --project=TraitWorld --startup-file=no experiments/hetero/hc1_filter.jl`; the test bed: add `-J julia-1.13/usr/lib/julia/facts/sys.so` with `JULIA_DEPOT_PATH=$TMPDIR/depot-facts:$HOME/.julia:`.
