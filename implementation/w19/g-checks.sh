#!/bin/bash
# W-19, third part: the checks of one build: the instances of `!==` in the system image, the probes of
# `up/19` (`!==`, `preserve_handle`), code compiled twice for one result, the facts gates (the in-force ones
# that need no set or library, and the series' own copies and gates). One process each, niced.
#     bash g-checks.sh <tree> <label>          -> logs/g-checks-<label>.log
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh" >/dev/null 2>&1
T=$1; label=$2
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w19:$R/.julia-depot: JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
J="nice -n 10 $R/$T/julia --startup-file=no --history-file=no -t 1"
{ echo "# W-19 g-checks $label | $T $(git -C $R/$T log -1 --format=%h) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "## instances of !== in the system image"
  $J -e 'm = only(methods(!==)); mis = collect(Base.specializations(m)); println("MethodInstances ", length(mis), ": ", join(string.(getfield.(mis, :specTypes))[1:min(3, end)], ", "))'
  echo "## probes"
  for p in ne preserve; do printf "%-10s " $p; $J $H/motiv/f-callsig-probes.jl $p 2>&1 | tail -1; done
  echo "## compiled twice"
  $J $H/motiv/g-twice.jl 2>&1 | tail -3
  echo "## gates"
  bash $R/experiments/implementation/gates/run_all.sh $T 'f[13457]_*' 2>&1 | grep -E "^(PASS|FAIL)|gates:"
  bash $R/experiments/implementation/gates/run_all.sh $T 'n1[57]_*' 2>&1 | grep -E "^(PASS|FAIL)|gates:"
  bash $R/experiments/implementation/gates/run_all.sh $T 'f6_*' 2>&1 | grep -E "^(PASS|FAIL)|gates:"
  for g in $H/gates/*.jl; do
    printf "%-28s " $(basename $g); (cd $R/experiments/implementation/gates && $J $g 2>&1 | tail -2 | tr '\n' ' '); echo
  done
  echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)"
} 2>&1 | tee $H/logs/g-checks-$label.log
