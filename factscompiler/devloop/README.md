# The fast loop

- **A change to the compiler's Julia code** (`julia-1.13/Compiler/src`):
  `julia --project=devloop/env devloop/run.jl <script>` loads the in-tree compiler as a package (about 23 s) and runs the script with it. No system image is built.
- **A change to C or C++ only** (`julia-1.13/src`): `make -C julia-1.13/src` (1–2 min).
  - The system images depend on the Compiler and Base sources, not on `libjulia`, so they stay.
  - Keep C patches and compiler patches in separate iterations: a change to `Compiler/src` rebuilds both images, about 13 + 6 min.
- **The facts image** (`scripts/build_facts_sysimage.sh`) only when testing `all`.
- **Performance checks:** the quick subset, `bash step0/scripts/run_quick.sh` (148 benchmarks, about 3.5 min); the full BaseBenchmarks once, at the end.
