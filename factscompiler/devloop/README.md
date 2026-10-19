# The fast loop

- **A change to the compiler's Julia code** (`julia-1.13/Compiler/src`):
  `julia --project=devloop/env devloop/run.jl <script>` loads the in-tree compiler as a package (about 23 s) and runs the script with it. No system image is built.
- **A change to C or C++ only** (`julia-1.13/src`): `make -C julia-1.13/src` (1–2 min).
  - The system images depend on the Compiler and Base sources, not on `libjulia`, so they stay.
  - Keep C patches and compiler patches in separate iterations: a change to `Compiler/src` rebuilds both images, about 13 + 6 min.
- **The facts image** (`scripts/build_facts_sysimage.sh`) only when testing `all`.
- **Performance checks:** the quick subset, `bash step0/scripts/run_quick.sh` (148 benchmarks, about 3.5 min); the full BaseBenchmarks once, at the end.

**What the fast loop cannot test.** The compiler loaded as a package is a separate module, with its own state. TraitWorld registers the call-site split's candidates (`register_dynamic_candidate!`, part D) with `Base.Compiler`, so in the fast loop a split has no candidates: `verify_main`'s test of dynamic values reports a hole there. That test, and anything else that depends on the split, needs a real build.
