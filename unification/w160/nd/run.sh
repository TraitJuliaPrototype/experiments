#!/usr/bin/env bash
# E-438: NetworkDynamics' workload (ndport/scripts/workload.jl, as u_workload.sh runs it: NDW_API=ports, passes first,
# again, params, changed, graphtype) and E-313's probe of step d, in fresh sessions, the baseline (env_base) and the
# head (env_head) interleaved: a warm-up, then <runs> runs of each. One thread, niced, offline, W-151's depot, never
# precompiling (run mkenvs.sh and precompile each environment first).
#     ./run.sh <name> [runs=2]          logs: logs/<name>-<base|head>-<0..runs>.log, logs/<name>-probe-<base|head>.log
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); source $H/../env.sh >/dev/null
name=$1; runs=${2:-2}
ND=$TW_ROOT/ndport; mkdir -p $H/logs
export OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1
export NDW_API=ports NDW_STACK=ports
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
# W-151's depot after W-160's: the baseline's caches are read from it, new ones written to W-160's
export JULIA_DEPOT_PATH=$TW_ROOT/.julia-depot/agent-depots/w160:$TW_ROOT/.julia-depot/agent-depots/w151:$TW_ROOT/.julia-depot:
rev() { echo "$(git -C $1 log -1 --format=%h)$([ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*')"; }
hdr() {  # $1 base|head
  if [ $1 = base ]; then echo "# TraitWorld $(rev $TW_ROOT/TraitWorld-base) TDE $(rev $TW_ROOT/wt/w151-base/TDE) ND $(rev $TW_ROOT/wt/w151-base/NetworkDynamics)"
  else echo "# TraitWorld $(rev $TW_ROOT/TraitWorld-unified) TDE $(rev $TW_ROOT/TraitDifferentialEquations-unified) ND $(rev $ND/pkgs/NetworkDynamics-unified)"; fi
  echo "# julia $( [ $1 = head ] && echo next $(rev $TW_ROOT/julia-next) || echo unified $(rev $TW_ROOT/julia-unified)) TraitMakie $(rev $TW_ROOT/wt/w160-tm) (wt/w160-tm) GraphMakie $(rev $ND/pkgs/GraphMakie-unified) Graphs $(rev $ND/pkgs/Graphs-unified) ndport $(rev $ND) env $H/env_$1"
  echo "# date $(date -Is) load-before $(cut -d' ' -f1 /proc/loadavg)"
}
for i in $(seq 0 "$runs"); do
  for which in base head; do
    f=$H/logs/$name-$which-$i.log
    { echo "# E-438 workload $which run $i (0: the warm-up) passes=first,again,params,changed,graphtype"; hdr $which; } > $f
    t0=$(date +%s.%N)
    (cd $ND && NDW_PASSES=first,again,params,changed,graphtype nice -n 10 timeout -s KILL 1500 $( [ $which = head ] && echo $JN || echo $JU ) --startup-file=no --threads=1 --project=$H/env_$which scripts/workload.jl) >> $f 2>&1; rc=$?
    t1=$(date +%s.%N)
    echo "# rc=$rc session $(echo "$t1 - $t0" | bc) load-after $(cut -d' ' -f1 /proc/loadavg)" >> $f
    grep -q "Precompiling" $f && echo "# NOTE: the run precompiled" >> $f
    echo "$which $i rc=$rc session $(echo "$t1 - $t0" | bc) $(grep '^W total' $f)"
  done
done
for which in base head; do
  f=$H/logs/$name-probe-$which.log
  { echo "# E-438 probe of step d (scripts/e313_probe.jl, passes=again) $which"; hdr $which; } > $f
  (cd $ND && NDW_PASSES=again nice -n 10 timeout -s KILL 1500 $( [ $which = head ] && echo $JN || echo $JU ) --startup-file=no --threads=1 --project=$H/env_$which scripts/e313_probe.jl) >> $f 2>&1
  echo "probe $which: $(grep '^P step_d' $f | tr '\n' ' ')"
done
