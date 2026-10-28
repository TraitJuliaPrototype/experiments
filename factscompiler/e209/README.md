# E-209: the first run-time `return_type` of a session

E-190 moved run-time `return_type` to its own interpreter, `PlainRTInterp`, in both settings. The product system image held no code of the compiler for that interpreter, so the first run-time `return_type` of a session compiled it.

How to run (the patched Julia, from the design repository's root):

    julia --startup-file=no experiments/factscompiler/e209/first_rt.jl                       # plain session
    julia --startup-file=no --project=TraitWorld experiments/factscompiler/e209/first_rt_tw.jl # TraitWorld loaded
    julia -J julia-1.13/usr/lib/julia/facts/sys.so --startup-file=no experiments/factscompiler/e209/first_rt.jl   # all
    julia --startup-file=no experiments/factscompiler/e209/entry_compiled.jl                 # is the entry compiled?

## Results (2026-10-28, two runs where two are given)

| Build | Plain session | TraitWorld loaded | `all` |
|---|---|---|---|
| julia-1.13 1c2e98b58e (before) | 4983, 4996 ms | 4902 ms | 0.2 ms |
| + the entry and `typeinf_ext_toplevel` for `PlainRTInterp` in the bootstrap list (not committed) | 5129, 5123 ms | 5021 ms | 0.2 ms |
| + what inference reaches by dynamic dispatch for it (a4e9ad5da9) | 81.0, 80.7, 82.6 ms | 7.8 ms | 0.3 ms |

- The second row: the entry was compiled (`entry_compiled.jl`), and `--trace-compile` (`trace_after.txt` is the third row's) showed `optimize` 3.7 s and `typeinf_local` 1.0 s compiled at the first call, reached by dynamic dispatch, as for `NativeInterpreter`, whose versions the bootstrap list names.
- What is left in a plain session: one closure in `typeinf_edge` (73 ms), whose generated name the list cannot name. Under the criterion (100 ms).
- Sessions D and C on a4e9ad5da9 (`experiments/ttfx/logs/e209/`, a warm-up and two sessions): D 0.962–0.968 s, C 10.71–10.77 s, against 0.961–0.977 and 10.90–10.94 s on 1c2e98b58e (`logs/w76/`). They did not pay the compile: neither calls run-time `return_type` in the session.
