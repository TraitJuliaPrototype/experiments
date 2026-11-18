# W-166: the demonstrators' programs build again as trimmed binaries (E-507)

**The question** (registry row E-507): do the demonstrators' programs build as trimmed binaries on the head once the
equations' functions answer at the kept forms (traits T-130, lowering L-67) and the loops hand a member over as the
wrapper `compiled_for(x)` (open issue 242)? Does the ODE program's build reach its verifier once code that runs while
a build loads is compiled as in a session (open issue 241)? What would change the design: a loop that the wrapper does
not serve in a build, or a session that pays for the wrapper.

## How to run

```sh
source experiments/implementation/w166/env.sh        # the workspace's env.sh, a depot of this work's own, $JN, $W156
cd experiments/implementation/w166
(cd ../../../TraitWorld && $JN --project=. ../experiments/implementation/w166/probes/t130.jl)   # stage 1's probe
$JN --project=$W156/env_demo probes/kept_tables.jl      # TraitTables' column code at a plain column, a box, a wrapper
bash suites.sh <label> tables csv report …               # W-156's suites.sh with this directory's depot and logs
bash sessions.sh <tag> 3                                 # W-156's regression control (report, table session)
bash small.sh <label> [tree]                             # E-384's eight small trait programs: build, run, compare
JULIA_TREE=julia-next NAME=w166-<name> bash ../w135/build.sh table $W156/env_demo   # a demonstrator's program
python3 ../w135/summarize.py ../w135/logs/w166-<name>.build.log
```

- `probes/t130.jl`: `eltype` (value and type), `zero(eltype(t))`, `Vector{eltype(t)}` and the inferred result at a
  plain member, a box, a box of a subtrait, the wrapper; `keytype`/`valtype` of `Keyed`; a box of an intersection.
- `probes/kept_tables.jl`: W-156's probe, with the library's `compiled_for`.
- `small.sh` builds with `../w139/build.sh`; its build logs are `../w139/logs/w166-<label>-<app>.build.log`.
- The programs' build logs are `../w135/logs/w166-*.build.log` (`build.sh` writes there).
- Builds run with `ulimit -c 0`: a crashed build leaves no core file.

## Results, 2026-11-18

See the tables below; the logs are in `logs/`.
