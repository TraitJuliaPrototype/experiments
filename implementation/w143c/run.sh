#!/bin/bash
# W-143c (E-535): one session of the census, a fresh process, its log with the trees' commits and the load.
#     bash run.sh <label> forks|facts|ode [census.jl | diag/culprit.jl] [names...]
# -> logs/<label>-<session>.log (and the table logs/<label>-<session>.tsv for the census)
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
label=$1; sess=$2; prog=${3:-census.jl}; shift 3 2>/dev/null || shift $#
case $sess in
  forks) env=envs/forks; work=table; arg=$CSVFILE ;;
  facts) env=envs/facts; work=table; arg=$CSVFILE ;;
  ode)   env=envs/demo;  work=ode;   arg=- ;;
  *) echo "session: forks, facts or ode"; exit 1 ;;
esac
log=logs/$label-$sess.log
rev() { echo "$(git -C "$1" rev-parse --short=10 HEAD)$([ -z "$(git -C "$1" status --porcelain --untracked-files=no)" ] || echo '*')"; }
{ echo "# W-143c $label $sess $prog $* | $(date -Is) | load-before $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "# julia-next $(rev $TW_ROOT/julia-next) (binary $($JN --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) | TraitWorld $(rev $TW_ROOT/TraitWorld) | forks $(rev $TW_ROOT/forks) | TraitDifferentialEquations $(rev $TW_ROOT/TraitDifferentialEquations) | experiments $(rev $TW_ROOT/experiments)"
  echo "# product setting, strict mode off, one thread, one fresh process; depot agent-depots/w143 before the shared one"
} > "$log"
s=$(date +%s)
CENSUS_WORK=$work CENSUS_TSV=$([ "$prog" = census.jl ] && echo logs/$label-$sess.tsv) nice -n 10 timeout -s KILL 1800 \
  $JN --startup-file=no --history-file=no -t 1 --project=$env "$prog" "$arg" "$@" >> "$log" 2>&1
rc=$?
echo "# done rc $rc | $(( $(date +%s) - s )) s | $(date -Is) | load-after $(cut -d' ' -f1-3 /proc/loadavg)" >> "$log"
grep -q Precompiling "$log" && echo "# NOTE: the run precompiled (an image was stale or missing)" >> "$log"
tail -3 "$log"
