# E-266 (X5): the facts copies of Base in today's images, as plain code that satisfies G2

The work plan's §8, X5 (the user, 2026-11-06: "Adopt, keys as optional is approved. Run the X now"). Registry
row: `writeup/record/experiments.md` E-266.

**The question.** Today the facts owner compiles its own copies of the Base methods that facts code reaches. Images keep them,
also where only a dynamic call reaches them (keep-compiled). Under the draft there is one CodeInstance per
MethodInstance and policy ([compiler §2.3](../../../writeup/reference-unified/compiler.md#23-one-codeinstance-per-methodinstance-and-policy)):
facts code calls Base's plain code. Mitigation M1 keeps plain code in an image where its record satisfies G2
([§3.2](../../../writeup/reference-unified/compiler.md#32-g2-as-a-predicate)). How much of what the facts copies
hold today would M1 keep?

## How to run

```sh
source env.sh
experiments/unification/x5/run.sh run1      # one job per image: TraitWorld, TraitDifferentialEquations, TraitMakie
```

`x5.jl <label> <package>` runs right after `using <package>`:
1. **The census.** Every CodeInstance of the facts owner valid now, by its method's origin. For Core's and Base's: whether a valid plain CodeInstance exists already (the system image, a loaded image), or none (*missing*).
2. **The timing.** Each missing one compiled plainly (`Compiler.typeinf_ext_toplevel` with the plain owner, then `jl_compile_codeinst`), callees first by the facts copies' edges, timed one by one. A callee compiled inside a caller's inference counts as the caller's time.
3. **G2 as plain code.** The plain record read, counted two ways:
   - **own:** every dispatch edge at a fact signature (`Compiler.is_fact_sig`; a lookup that does not cover is not G2; `invoke` and binding edges allowed). An upper bound: an inlined callee's own record is not read.
   - **deep:** the same, and every callee's plain record transitively; facts callees count as G2. A lower bound: every callee is treated as inlined.

julia-1.13 00dcc9994c, TraitWorld 33dd55e, TDE e9e07ed, TraitMakie ba46982; product setting, strict mode off;
`JULIA_LOAD_PATH` TraitMakie's and TDE's script environments; 4 cores per job through `experiments/tools/jl`.
Run 1's loads also precompiled the images into the job's new depot (in a subprocess). Run 2 loaded them.

## Results (2026-11-06; two runs; machine load 4–5 of 128 cores)

| Image | Facts CodeInstances of Core and Base | Plain present | Missing | Compiled plainly (run 1 / run 2) |
|---|---|---|---|---|
| TraitWorld | 7,920 | 6,761 | 1,159 | 4.33 / 4.49 s |
| TraitDifferentialEquations | 11,802 | 7,885 | 3,917 | 19.99 / 20.00 s |
| TraitMakie | 9,811 | 7,504 | 2,307 | 7.92 / 7.90 s |

G2 as plain code, the missing ones (run 2; the counts are the same in run 1):

| Image | own: G2 | own: not | deep: G2 | deep: not | Kept by M1, share of the time (deep–own) |
|---|---|---|---|---|---|
| TraitWorld | 1,063 (3.61 s) | 96 (0.86 s) | 892 (2.26 s) | 267 (2.20 s) | 50–80 % |
| TraitDifferentialEquations | 3,712 (18.41 s) | 198 (1.56 s) | 3,344 (15.54 s) | 566 (4.43 s) | 78–92 % |
| TraitMakie | 2,159 (6.72 s) | 133 (1.16 s) | 1,841 (4.41 s) | 451 (3.47 s) | 56–85 % |

7 instances in TDE and 15 in TraitMakie had no plain code after compiling, from constant results or an error.

Of the missing instances, many name a type of TraitWorld, the prototype's own machinery, which the unified
library replaces:
- TraitWorld: 476 (2.13 s);
- TDE: 1,601 (5.63 s);
- TraitMakie: 1,014 (3.51 s).

Among those not G2, the largest are broadcasting and `show` over containers of `Any`
(`Base.Broadcast.combine_eltypes(string, (Vector{Any},))`), ScopedValues' tries, and sorting with a closure's order.

## What it means

- **Below the registered threshold:** M1 keeps more than half of the compile time in every image under both
  bounds (50 % at the lowest, TraitWorld's deep count). M1 recovers most of what keep-compiled's facts copies of
  Base hold today.
- **What M1 does not keep** is 0.9–4.4 s of plain compile per image if every instance is used again: TraitWorld
  0.86–2.20 s, TDE 1.56–4.43 s, TraitMakie 1.16–3.47 s. That is an upper bound on a session's first-use cost, in
  two ways:
  - a session compiles only what it calls;
  - of all the missing instances' time, 28–47 % names TraitWorld's types (its machinery).
- **The scale without M1:** 4.5–20 s of plain compile per image would move from the image into the session's
  first use. M1 belongs in W-100's scope, as the plan's §8 says.
