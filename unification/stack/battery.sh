#!/bin/bash
# The battery after a stage, on a built tree, one job at a time (niced): the gates, Base's four test
# files and the stage-top files, the acceptance cases in both settings, TraitWorld's tests, both
# workloads. Logs: experiments/unification/stack/logs/<label>-*.log and ../workloads/logs/<label>-*.log.
# Usage: source env.sh; experiments/unification/stack/battery.sh julia-unified <label>
R=$(cd "$(dirname "$0")/../../.." && pwd); T=$1; L=$2
U=$R/experiments/unification; LOG=$U/stack/logs
J=$R/$T/julia
"$U/gates/run_all.sh" "$T" 'm[12]_*' > "$LOG/$L-gates-m.log" 2>&1; tail -1 "$LOG/$L-gates-m.log"
"$U/gates/run_all.sh" "$T" '[nf]*' > "$LOG/$L-gates-nf.log" 2>&1; tail -1 "$LOG/$L-gates-nf.log"
"$U/stack/tests.sh" "$T" "$L" core subtype worlds ambiguous reflection Compiler/inline Compiler/inference precompile
for f in $U/test/acceptance/AC_*.jl; do
  b=$(basename "$f" .jl)
  (cd "$U/test/acceptance" && nice -n 10 "$J" --startup-file=no --project="$U" "$f" > "$LOG/$L-$b.log" 2>&1; echo "exit $?" >> "$LOG/$L-$b.log")
  tail -2 "$LOG/$L-$b.log" | head -1
done
(cd "$R/TraitWorld-unified" && nice -n 10 "$J" --startup-file=no --project=. test/runtests.jl > "$LOG/$L-traitworld.log" 2>&1; echo "traitworld exit $?")
for w in columns ode; do
  nice -n 10 "$J" --startup-file=no --project="$R/TraitWorld-unified" "$U/workloads/$w.jl" > "$U/workloads/logs/$L-$w.log" 2>&1
  echo "$w exit $?"
done
