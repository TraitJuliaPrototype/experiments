#!/bin/bash
# W-145, part 4b: the ports' loads, with the membership walk invalidating and as a control without.
#     bash run.sh [tag] [N]     -> logs/loads[-tag].log
# Each row: a warm-up and N fresh processes per mode, one thread, niced. The last run's events are kept.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../../.." && pwd); source "$R/env.sh"
tag=${1:+-$1}; N=${2:-3}; LOG=$H/logs/loads$tag.log
J=$R/julia-unified/julia; V=$R/julia-vanilla/julia; W=$H/../../w134
rev() { git -C "$R/$1" log -1 --format=%h; }
export JULIA_PKG_OFFLINE=true
echo "# W-145 loads $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld $(rev TraitWorld-unified) | N=$N, one thread" | tee "$LOG"
row() { # row <name> <julia> <env> <modes> <packages…>
  local name=$1 jl=$2 env=$3 modes=$4; shift 4
  for mode in $modes; do
    for r in $(seq 0 $N); do
      out=$(nice -n 10 "$jl" -t 1 --startup-file=no --project="$env" "$H/load.jl" $mode "$@" 2>&1)
      [ $r = 0 ] && continue
      echo "$name run $r: $(echo "$out" | grep '^LOAD' | cut -c6-)" | tee -a "$LOG"
      [ $r = $N ] && echo "$out" | grep 'EVENT\|ENDED' | sed "s/^/$name $mode/" | tee -a "$LOG"
      echo "$out" | grep -v '^LOAD\|EVENT\|ENDED' | head -3 | sed "s/^/$name !! /" | tee -a "$LOG"
    done
  done
}
row traitworld      "$J" "$R/TraitWorld-unified"      "walk nowalk" TraitWorld
row tables          "$J" "$W/env_demo"                "walk nowalk" TraitTables TraitCSV
JULIA_TW_STRICT=1 row tables-strict "$J" "$W/env_demo"         "walk"        TraitTables TraitCSV      # GT-2
row ode             "$J" "$W/env_demo"                "walk nowalk" TraitDifferentialEquations
row makie           "$J" "$R/TraitMakie-unified"      "walk nowalk" TraitMakie
row forks           "$J" "$W/env_forks"               "walk nowalk" CSV DataFrames
row upstream-facts  "$J" "$W/env_facts"               "walk"        CSV DataFrames
row upstream        "$J" "$W/env_up"                  "walk"        CSV DataFrames
row upstream-vanilla "$V" "$W/env_up"                 "walk"        CSV DataFrames
row nd              "$J" "$R/ndport/env_unified"      "walk nowalk" NetworkDynamics
