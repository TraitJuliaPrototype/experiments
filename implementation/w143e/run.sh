#!/bin/bash
# W-143e (E-541; W-143d's run.sh): one session of the census on a Julia tree, a fresh process, its log with the trees' commits and the load.
#     TREE=<tree> bash run.sh <label> forks|facts|ode [census.jl | diag/culprit.jl | diag/code_of.jl] [names...]
#     TREE=<tree> bash run.sh <label> images          # the package images of the three environments (once per build)
# -> logs/<label>-<session>.log (and the table logs/<label>-<session>.tsv for the census)
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
label=$1; sess=$2; prog=${3:-census.jl}; shift 3 2>/dev/null || shift $#
rev() { echo "$(git -C "$1" rev-parse --short=10 HEAD)$([ -z "$(git -C "$1" status --porcelain --untracked-files=no)" ] || echo '*')"; }
log=logs/$label-$sess.log
{ echo "# W-143e $label $sess $prog $* | $(date -Is) | load-before $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "# $TREE $(rev $TW_ROOT/$TREE) (binary $($JN --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')) | TraitWorld $(rev $TW_ROOT/TraitWorld) | forks $(rev $TW_ROOT/forks) | TraitDifferentialEquations $(rev $TW_ROOT/TraitDifferentialEquations) | experiments $(rev $TW_ROOT/experiments)"
  echo "# product setting, strict mode off, one thread, one fresh process; depot $W143E_DEPOT before the shared one"
} > "$log"
s=$(date +%s)
if [ "$sess" = images ]; then
  for e in forks facts; do nice -n 10 $JN --startup-file=no --project=envs/$e -e 'using CSV, DataFrames' >> "$log" 2>&1; done
  nice -n 10 $JN --startup-file=no --project=envs/demo -e 'using TraitWorld, TraitDifferentialEquations' >> "$log" 2>&1
  rc=$?
else
  case $sess in
    forks) env=envs/forks; work=table; arg=$CSVFILE ;;
    facts) env=envs/facts; work=table; arg=$CSVFILE ;;
    ode)   env=envs/demo;  work=ode;   arg=- ;;
    *) echo "session: forks, facts, ode or images"; exit 1 ;;
  esac
  CENSUS_WORK=$work CENSUS_TSV=$([ "$prog" = census.jl ] && echo logs/$label-$sess.tsv) nice -n 10 timeout -s KILL 1800 \
    $JN --startup-file=no --history-file=no -t 1 --project=$env "$prog" "$arg" "$@" >> "$log" 2>&1
  rc=$?
fi
echo "# done rc $rc | $(( $(date +%s) - s )) s | $(date -Is) | load-after $(cut -d' ' -f1-3 /proc/loadavg)" >> "$log"
[ "$sess" != images ] && grep -q Precompiling "$log" && echo "# NOTE: the run precompiled (an image was stale or missing)" >> "$log"
tail -3 "$log"
