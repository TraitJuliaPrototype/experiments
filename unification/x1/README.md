# E-265 (X1): what G2's narrower scope costs in compile time per session of loads

The work plan's §8, X1 (the user, 2026-11-06: "Adopt, keys as optional is approved. Run the X now"). Registry
row: `writeup/record/experiments.md` E-265.

**The question.** Under the draft there is one CodeInstance per MethodInstance and policy
([compiler §2.3](../../../writeup/reference-unified/compiler.md#23-one-codeinstance-per-methodinstance-and-policy)). So
facts code calls plain code, and a load that invalidates the plain code invalidates the facts callers that
hold code edges to it. E-261 counted them: set (B) and the part the code slot keeps. This experiment times them.

## How to run

```sh
source env.sh
experiments/unification/x1/run.sh run1 forks     # E-261's forks session: CSV, DataFrames, Statistics, Dates
experiments/unification/x1/run.sh run1 g2all     # E-261's g2all session: TDE, TraitMakie, a work step, ten loads
```

Each session runs once per mode, one Julia job each (`x1.jl`, `X1_MODE`). Every mode first runs E-261's
analysis after each step (copied from `../s0a/s0a.jl`). It gives (B), the facts callers of plain code the step
invalidated, and the part of (B) the slot keeps. One difference from E-261: (B) counts each caller once, and
a caller counts as kept only when the slot keeps it for every callee. Then:
- **The session modes**, against each other:
  - `control`: nothing more;
  - `slot`: the callers the slot would not keep, and their facts callers, are invalidated for real (`jl_invalidate_code_instance`, which also takes their callers of any owner);
  - `noslot`: all of (B) and their facts callers.

  After the last step, the session's own work runs, timed, with Julia's compile counter: `forkswork.jl` (`forks/scripts/session.jl`'s steps up to the second schema; data from `forks/scripts/gendata.jl` in `data/`, not committed) and `g2call.jl` (E-261's `_work()` again). Then the plain callees that the facts code compiled again rests on, and that have no valid plain code, are compiled plainly and timed. The unified build's facts code would call them.
- **The upper modes** (`upper-slot`, `upper-noslot`): after each step, the plain callees in (B)'s edges (P) are compiled again. Then the lost set is invalidated and compiled again for its owner (`Compiler.typeinf_ext_toplevel`, `jl_compile_codeinst`), timed. This is an upper bound: every lost CodeInstance compiled again once per load.

julia-1.13 00dcc9994c, TraitWorld 33dd55e, forks 77b9aab, TraitMakie ba46982, TDE e9e07ed, TraitReport 882c533;
product setting, strict mode off; 4 cores per job through `experiments/tools/jl`, two jobs side by side.
Outputs: `out/<run>-<session>-<mode>.{tsv,txt}`, `out/<run>-<session>-<mode>-methods.tsv` (each CodeInstance
compiled again, with its module and seconds), `logs/<run>-<session>.log`.

**Superseded attempts** (kept in `out/attempt*`, `logs/attempt*`):
- the first ran both cases in one process, so "without the slot" compiled again what "with the slot" had compiled already, and counted it twice;
- the second stopped at a scoping error after the control's work.

## Results (2026-11-06; two runs; machine load 3–5 of 128 cores)

**What a session pays: its work after the loads, against the control.** Wall time / compile counter, in seconds:

| Session | Mode | Lost and invalidated | Run 1 | Run 2 | More than the control | Plain callees after the work |
|---|---|---|---|---|---|---|
| forks | control | 0 | 2.207 / 2.923 | 2.188 / 2.865 | — | — |
| forks | slot | 132 | 2.345 / 3.187 | 2.350 / 3.077 | +0.14–0.16 / +0.21–0.26 | 1 in 0.055 s |
| forks | noslot | 148 | 2.875 / 3.744 | 3.041 / 3.859 | +0.67–0.85 / +0.82–0.99 | 2 in 0.057 s |
| g2all | control | 0 | 0.111 / 0.097 | 0.109 / 0.095 | — | — |
| g2all | slot | 77 | 0.113 / 0.099 | 0.114 / 0.097 | none | 0 |
| g2all | noslot | 92 | 0.111 / 0.097 | 0.108 / 0.094 | none | 0 |

In the forks, the work compiles 33 (slot) and 39 (noslot) of the lost facts CodeInstances again. In g2all the
work compiles none of them. There the lost code is TraitWorld's load-time machinery: it has valid code again by
the end, compiled in a later step or brought back by a later package's image. The load times show no difference
beyond the first load's own variation (0.7–1.2 s).

**The upper bound** (every lost CodeInstance compiled again once per load; run 1 / run 2):

| Session | (P) plain callees | Lost with the slot | Lost without it |
|---|---|---|---|
| forks | 42 in 1.04 / 1.06 s | 139 in 2.48 / 2.48 s | 156 in 3.27 / 3.28 s |
| g2all | 45 in 18.2 / 18.0 s | 90 in 1.28 / 1.26 s | 107 in 1.50 / 1.50 s |

**What is lost** (run 2's upper modes, `out/run2-*-upper-slot-methods.tsv`):
- **forks:**
  - lost: CSV's facts code (30 in 1.07 s: `CSV._filefromprepared` at 85–90 ms each, `CSV._parse`) and TraitWorld's (56 in 0.80 s);
  - their plain callees: CSV's (17 in 0.61 s, `CSV._parse` alone 0.34 s), TraitWorld's (24 in 0.44 s), none of Base's.
- **g2all:**
  - lost: TraitWorld's facts code only (90);
  - the plain callees: TraitWorld's strict-mode and ownership checks that each load invalidates (`TraitWorld._winning_fact` 11.4 s, `TraitWorld.owned_method` 5.5 s).

## What it means

- **With the slot, a session pays about 0.2–0.3 s:** in the forks, the work's wall time +0.14–0.16 s and its compile counter +0.21–0.26 s, plus 0.06 s of plain callees. In g2all it pays nothing. That is at the registered threshold (about 0.2 s).
- **Without the slot it pays 0.7–1.0 s in the forks.** The slot (W-101) saves 0.5–0.8 s of it, which confirms E-261's case for it.
- **The rest is not Base's.** In the forks, CSV's facts code rests on CSV's own plain methods, which DataFrames' load invalidates. The recovery is the package's choice: its own helpers compiled by facts, or the boundary flag on them (M2). The registered criterion named "the Base methods" for M2's flags; the measurement names a package's own methods instead.
- **The upper bound is far above what a session pays:** 2.5 s and 1.3 s against 0.2–0.3 s and 0. The bound also includes plain code the loads invalidated anyway (P: 1.0 s; 18 s for TraitWorld's checks). Stock Julia pays that whenever plain code calls it again.
- **Caveats:**
  - TraitWorld's machinery is a large part of every lost set, and the unified library's code would differ;
  - two sessions on one machine;
  - the unified build itself does not exist yet: today's build stands in for it, its facts code made to lose what one CodeInstance per MethodInstance and policy would lose.
