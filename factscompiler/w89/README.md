# W-89: the facts image hangs under `--compile=min` (facts F-23, compiler C-5)

Diagnosed on julia-1.13 `a4e9ad5da9` (trait-world-1.13), facts image of 2026-10-28 09:56. Fix: julia-1.13
`bfca89decc` on trait-world-1.13 (the first draft: `0001-gf-compile-min-facts-owner.patch`, `3cf728a718`).
Built 2026-10-29 (libjulia-internal only, `TW_TARGET=julia-src-release`, 10 s, exit 0); both system images
and the facts image kept.

## How to run
- `check_compile_min.sh [julia-1.13 dir]`: starts the facts image with `--compile=min -t1`, kills it
  after 30 s. PASS/FAIL for F-23 (starts, runs) and C-5 (at most 2 CodeInstances for `f` after 1000 calls).
- The same check in the acceptance suite: G1.35 of `../../facts/acceptance_compiler.jl`, run plain and under `all`.
- `spin_bt.gdb`: breaks in the spin loop of `jl_read_codeinst_invoke`, prints the CodeInstance.
- `flag_patch_count.gdb`: sets `JL_CI_FLAGS_INVOKE_MATCHES_SPECPTR` on each CodeInstance it spins on
  and counts `jl_code_for_interpreter`.
Run each through `flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout -s KILL <s>`.

## Cause (2026-10-29)
1. Under the test bed, `jl_default_owner` of a builtin's method is `:facts` (the builtin is neither a
   facts method nor the compiler's code). The interpreter calls builtins through `jl_apply_generic`, so
   `_jl_invoke_owner` looks for a `:facts` CodeInstance of e.g. `isa(Any...)`. There is none: a builtin
   has one CodeInstance, the plain owner's, made by `jl_mk_builtin_func` (gf.c:344).
2. With compilation off, `jl_compile_method_internal_owner` copies the method's unspecialized code
   (gf.c:3901-3909). For a builtin that is that one CodeInstance: `invoke = jl_fptr_args`,
   `specptr = jl_f_isa`, `flags = 0b1000`. Its flags never get `JL_CI_FLAGS_INVOKE_MATCHES_SPECPTR`
   (neither in `jl_mk_builtin_func` nor in `jl_update_all_fptrs`, which restores builtins through a
   relocation, not the fptr record). `jl_read_codeinst_invoke` waits for that flag (gf.c:3799-3801)
   forever. Stock Julia never gets there: its owner is the plain one, whose lookup finds the CodeInstance.
   (`spin_bt.log`)
3. With the flag set by gdb on the 21 builtins it spins on, the image starts and runs (`flag_patch_count.log`).
   It then shows C-5: each call to `f` makes a new owner-`nothing` interpreted CodeInstance, because the
   compile-off branches (gf.c:3912, 3935) make the copy for owner `nothing`; the `:facts` lookup misses it
   on every call: 1000 calls, 1000 CodeInstances, 1030 `jl_code_for_interpreter` calls.

## Fix (bfca89decc, src/gf.c only)
- `jl_code_owner`: a builtin method is the plain owner's for every reach. It is recognised by its
  signature: the function type is a subtype of `Core.Builtin`, intrinsics among them (`method_is_builtin`).
  The first draft tested for a missing source (gf.c:166's test), which a method whose IR was stripped
  (`--strip-ir`, trimmed images) also has; such a method's facts code would have run plain code.
- The compile-off and no-source branches make their CodeInstance for the asking owner.
  The unspecialized code they copy is the asking owner's, else the plain owner's
  (`unspec_compiled_for_owner`); the plain owner never runs code compiled by facts.

Rebuild: libjulia-internal only (`TW_TARGET=julia-src-release`); no Julia code changes, and the images
hold no `:facts` CodeInstance of a builtin, so neither system image needs a rebuild.

## Results
| Date | Build | Check | Result |
|---|---|---|---|
| 2026-10-29 | a4e9ad5da9 (unpatched) | `check_compile_min.sh` | FAIL F-23, killed after 30 s (`check_unpatched.log`) |
| 2026-10-29 | bfca89decc | `check_compile_min.sh` | PASS F-23 (`1000`), PASS C-5 (1 CodeInstance after 1000 calls) (`check_patched.log`) |
| 2026-10-29 | bfca89decc | acceptance, product setting | 35 of 35, with the new G1.35 (`acceptance-product.log`) |
| 2026-10-29 | bfca89decc | acceptance, facts image | 35 of 35 (`acceptance-all.log`) |
| 2026-10-29 | bfca89decc, TraitWorld c39fedc | `Pkg.test()`, facts image, `timeout -s KILL 900` | passed, 1 min 27 s (`traitworld-all.log`) |
| 2026-10-29 | bfca89decc, TraitWorld c39fedc | `Pkg.test()`, product setting | passed, 1 min 21 s (`traitworld-product.log`) |
| 2026-10-29 | bfca89decc, TDE 44b4d14 | `Pkg.test()`, stock image | passed (`TraitDifferentialEquations.log`) |
| 2026-10-29 | bfca89decc, TraitMakie 80a16fc | `Pkg.test()`, stock image | passed (`TraitMakie.log`) |
| 2026-10-29 | bfca89decc, forks c1ac52d | `check_session.sh … env_forks` | digests equal: 26 steps; REPL 20 marks, 0 errors (`forks-session.log`) |

All runs one at a time under the lock, `nice -n 19`, `JULIA_PKG_OFFLINE=true`; the facts image runs with
`JULIA_DEPOT_PATH=/tmp/claude-1000/depot-facts:$HOME/.julia:`.

Left as is: the fallback after a failed inference (gf.c:4027) also makes an owner-`nothing` CodeInstance
or returns the plain unspecialized one for any owner; stock Julia misses there on every call too.
The module option `compile=min` applies to the plain owner only (gf.c:3889, from c3415abde6).
