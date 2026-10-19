# Session 29's performance phase: scripts and logs

Copied from `/tmp/claude-1000/demos/` (not durable) on 2026-10-19, so that every number in `writeup/design/evidence.md` and `writeup/design/performance.md` traces to a script and a log in a repository. The scripts were written for one run; paths in them point to the workspace and to `/tmp`, and they take the shared lock themselves (`flock /tmp/claude-1000/julia-review.lock`).

- **Harnesses:**
  - `measure_all.sh`: the control, the TDE and TraitMakie rows, TraitReport, the forks' session;
  - `remeasure.sh`: the rows after the machinery fixes;
  - `final_checks.sh`: the review's recursion probe, the suites, the micro benchmarks, the demonstrators' suites;
  - `after_build.sh`: TraitWorld's suite, acceptance, the raytrace;
  - `demo_suites.sh`: the demonstrators' suites and the examples.
- **Diagnostics:**
  - `afterloads*.jl`: new trait code after big loads;
  - `makie_al.jl`, `report_al*.jl`: the same for TraitMakie and TraitReport;
  - `rt_*.jl`: the raytrace's allocations and IR;
  - `s15.jl`: the forks' `String15` read;
  - `probe*.jl`: the Fable reviewer's probes (`probe3.jl`: a varargs wrapper in a plain recursion, stock against patched).
- **Logs:**
  - `logs/all.log`: the first full measurement;
  - `logs/remeasure*.log`, `logs/final-*.log`: the later rounds;
  - `logs/control*.log`: the control;
  - the session note `session-notes/2026-10-18-29-reviews-and-decisions.md` quotes each, in order.
