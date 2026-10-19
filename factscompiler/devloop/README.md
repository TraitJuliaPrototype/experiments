# The fast loop

- **A change to the compiler's Julia code** (`julia-1.13/Compiler/src`):
  `julia --project=devloop/env devloop/run.jl <script>` loads the in-tree compiler as a package (about 23 s) and runs the script with it. No system image is built.
- **A change to C or C++ only** (`julia-1.13/src`): `make -C julia-1.13/src` (1–2 min).
  - The system images depend on the Compiler and Base sources, not on `libjulia`, so they stay.
  - Keep C patches and compiler patches in separate iterations: a change to `Compiler/src` rebuilds both images, about 13 + 6 min.
- **The facts image** (`scripts/build_facts_sysimage.sh`) only when testing `all`.
- **Performance checks:** the quick subset, `bash step0/scripts/run_quick.sh` (148 benchmarks, about 3.5 min); the full BaseBenchmarks once, at the end.

**What the fast loop cannot test.** The compiler loaded as a package is a separate module, with its own state. TraitWorld registers the call-site split's candidates (`register_dynamic_candidate!`, part D) with `Base.Compiler`, so in the fast loop a split has no candidates: `verify_main`'s test of dynamic values reports a hole there. That test, and anything else that depends on the split, needs a real build.

## Tools for finding what is slow

- **`JULIA_FACTS_DISPATCH_PROFILE=1`** (patched Julia): at exit, the dynamic calls by callee method, split by the path their lookup took. The paths are the per-call-site cache, the leaf cache, the method cache's search and the full lookup, for code of the owner `:facts` and of the default owner. Many calls on the search path mean a site the per-site cache does not hold (a non-leaf entry, or a site that sees many types).
- **`fully_typed(f, argtypes)`** (TraitWorld): the run-time sites on a function's normal paths, with kinds and lines. It does not look at the targets of dynamic calls; for those, `code_typed` of the target under the facts image (run-time sites print as `dynamic`).
- **`JULIA_TW_DEBUG=1`** (TraitWorld's slow paths) and **`JULIA_TW_ALL_FRAMES=1`** (the machinery's frames in backtraces).
- **SnoopCompileCore's `@snoop_inference`** (what a call infers: step 5 found its causes with it), the invalidation log (`jl_debug_method_invalidation`), and `@timed`'s `compile_time` and `recompile_time`.
