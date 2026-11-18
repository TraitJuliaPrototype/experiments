# Held against reference layout (session 22, keys plan)

`layout_bench.jl`, stock Julia 1.13.2, run alone at `nice -n 19`, best of 7. The question (the user): can `f(t::Trait{U,T})` be a worker compiled per key that reads the user's object directly, `t.data::U`, instead of a view holding the fields?

Layouts:
- **plain:** Julia today, the loop compiled per user type;
- **held:** the fields copied into the view at the entry (a snapshot), the writable `t` through the object;
- **ref:** the view is the user's object and byte offsets passed in at run time, read with `unsafe_load`;
- **reft:** the same, with the loads and stores carrying Julia's own alias metadata (TBAA `jtbaa_mutab`) through `llvmcall`, as a runtime would emit them.

ns per element (K5: ns per call), n = 4096 (n = 16 in brackets):

| layout | K1 reduce | K2 store into another array | K3 `t += dt` | K4 fields read before the loop | K5 short call |
|---|---|---|---|---|---|
| plain | 0.93 (0.33) | 0.13 (0.12) | 0.94 (0.99) | 0.13 (0.12) | 0.93 |
| held | 0.92–0.94 (0.31) | 0.13 (0.12) | 0.94 (1.02) | 0.13 (0.12) | 0.93–0.95 |
| ref | 0.93–0.95 (0.42) | **0.64** (0.74–0.79) | 0.93–0.94 (1.03) | 0.12–0.13 (0.25–0.27) | 2.85–4.17 |
| reft | 0.92–0.95 (0.40–0.41) | 0.13 (0.21) | 0.94 (1.01–1.03) | 0.13 (0.25–0.27) | 2.93–2.99 |

**Findings:**
- **The plain offset load loses vectorization in loops that store.** Without alias information, LLVM must assume a store into `du` may change the user's field, so it reloads `t.data` and `t.p` every iteration: 5× on K2.
- **With Julia's alias metadata the reference layout matches plain Julia in every loop.** That includes loops that read the fields inside the loop (K1, K2). The metadata is the same that Julia's own field loads carry, so this is what a runtime would emit, and stock Julia can emit it through `llvmcall`.
- **The remaining cost is about 2 ns per call:** the base pointer, the type check on the loaded reference, and the offsets passed in. Against an entry of about 215 ns this is noise; at n = 16 it shows as 0.2 against 0.12 ns per element.
- **One compiled kernel serves all three user types** in the reference layout: mutable, immutable, and different field orders.
- **Writes:** an isbits field is stored at its offset with the same metadata, and costs as much as plain Julia (K3). A reference field needs the write barrier and goes through `setfield!` (10.7 ns, `baseline-1.13.md`).
- **Not covered:**
  - a field stored inline that is not isbits (an immutable struct holding references), which needs the builtin `getfield`;
  - GPU kernels, which cannot take the boxed object.
