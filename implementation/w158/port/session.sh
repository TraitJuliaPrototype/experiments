#!/bin/bash
# W-158, the port's part: the ODE program (../../w135/apps/ode.jl) as a session, as ../sessions.sh counts the
# report's and the table's: a fresh process with one thread, niced; a warm-up (it writes the packages' images where
# they are stale) and N runs; the marks of ../../w120/session_marks.jl; what the session compiles, by class
# (../../w120/classify_trace.py on the last run's trace); then the compiled instances of the port's packages after
# one run (probes/instances.jl). And the build's check run in the session (../probes/ode_members.jl): its rounds,
# members and errors.
#     bash session.sh <tag> [N]      -> logs/session-<tag>.log, logs/ode-<tag>.trace
set -u; H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
tag=$1; N=${2:-3}; LOG=$H/logs/session-$tag.log; U=$H/../..
echo "# W-158 port session $tag $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-next $(rev julia-next) TraitWorld $(rev TraitWorld) TraitDifferentialEquations $(rev TraitDifferentialEquations)" | tee "$LOG"
for r in $(seq 0 $N); do
  s=$(date +%s.%N)
  line=$(VERIFY=0 nice -n 10 $JN -t 1 --startup-file=no --project=$ENVD --trace-compile=$H/logs/ode-$tag.trace --trace-compile-timing $U/w120/session_marks.jl $U/w135/apps/ode.jl 2>/dev/null | grep "^load " | tail -1)
  e=$(date +%s.%N)
  [ $r = 0 ] && continue
  echo "ode run $r: wall $(echo "$e - $s" | bc | cut -c1-5) s | $line" | tee -a "$LOG"
done
python3 $U/w120/classify_trace.py $H/logs/ode-$tag.trace | sed "s|$TW_ROOT/||" | tee -a "$LOG"
VERIFY=0 nice -n 10 $JN -t 1 --startup-file=no --project=$ENVD $H/probes/instances.jl $U/w135/apps/ode.jl 2>/dev/null | grep '^instances' | tee -a "$LOG"
(cd $H/.. && VERIFY=0 nice -n 10 $JN -t 1 --startup-file=no --project=$ENVD probes/ode_members.jl 2>&1) | sed "s|$TW_ROOT/||g" | cut -c1-400 | tee -a "$LOG"
echo "# load after $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a "$LOG"
