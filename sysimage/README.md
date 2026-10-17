# The policy in the platform: a system image with TraitWorld

Session 26 (2026-10-17), decided by the user (open-issues §1.3): the facts policy's compiler is compiled with the system image and runs in a world fixed at startup, as Julia's own compiler does. This is the prototype: the patched build's `sys.so` plus TraitWorld, loaded from source while generating output.

**Build** (alone on the machine, niced, under a memory watchdog; about 2 minutes):

    flock <julia lock> experiments/sysimage/build.sh     # writes $TMPDIR/systw/systw.so (OUT= to change)
    julia-1.13/julia -J $TMPDIR/systw/systw.so ...

- `build.jl` initializes `Sys.BINDIR`, `DEPOT_PATH` and `LOAD_PATH`, which are empty while generating output, loads TraitWorld (its precompile block compiles the policy's compiler for `FactsInterp` and the machinery's slow paths under the policy), runs a small trait module once, and empties the paths again.
- It loads TraitWorld from `JULIA_LOAD_PATH="$TMPDIR/twtestenv13p:@stdlib"`, an environment that has TraitWorld by path.
- Packages that depend on TraitWorld need images compiled against this system image: precompile each environment once with `-J`.

**Measured** (session 26):
- 245 MB (the base `sys.so` is 193 MB); startup 0.125 s (0.10 s); `using TraitWorld` 0.013 s.
- TraitWorld's suite: 344 of 344.
- REPL loaded first, a new key's first call (TraitMakie, a new colour type, first PNG): 0.22 s, against 5.9 s with TraitWorld as a package.
- TraitReport form (b) after other loads (work, `TraitReport/scripts/report_loads.jl`): 1.7–2.2 s, against 5.3–5.7 s with TraitWorld as a package. The rest is CSV's native code, invalidated as in plain Julia (TraitCSV's job). The plain package takes 2.7–3.4 s.

**Open:**
- The demonstrators' rows on this image.
- A cleaner form: the policy as part of Julia's Compiler (the upstream proposal) rather than TraitWorld whole in the image.
- Whether the machinery's native code in the image is invalidated by later loads: `@implement` after loads.
