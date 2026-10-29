# W-89: the facts image hangs under `--compile=min` (facts F-23, compiler C-5)

Build: julia-1.13 `a4e9ad5da9` (trait-world-1.13), facts image of 2026-10-28 09:56. Fix: branch
`w89-compile-min`, commit `3cf728a718` (worktree `julia-1.13-w89`; `0001-gf-compile-min-facts-owner.patch`).
Not built yet.

## How to run
- `check_compile_min.sh [julia-1.13 dir]`: starts the facts image with `--compile=min -t1`, kills it
  after 30 s. PASS/FAIL for F-23 (starts, runs) and C-5 (at most 2 CodeInstances for `f` after 1000 calls).
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

## Fix (3cf728a718, src/gf.c only)
- `jl_code_owner`: a builtin method (no source, no generator, not an opaque closure's, with an
  unspecialized instance: the test of gf.c:166) is the plain owner's for every reach.
- The compile-off and no-source branches make their CodeInstance for the asking owner.
  The unspecialized code they copy is the asking owner's, else the plain owner's
  (`unspec_compiled_for_owner`); the plain owner never runs code compiled by facts.

Rebuild: libjulia-internal only (`TW_TARGET=julia-src-release`); no Julia code changes, and the images
hold no `:facts` CodeInstance of a builtin, so neither system image needs a rebuild.

## Results
| Date | Build | Check | Result |
|---|---|---|---|
| 2026-10-29 | a4e9ad5da9 (unpatched) | `check_compile_min.sh` | FAIL F-23, killed after 30 s (`check_unpatched.log`) |

Left as is: the fallback after a failed inference (gf.c:4027) also makes an owner-`nothing` CodeInstance
or returns the plain unspecialized one for any owner; stock Julia misses there on every call too.
The module option `compile=min` applies to the plain owner only (gf.c:3889, from c3415abde6).
