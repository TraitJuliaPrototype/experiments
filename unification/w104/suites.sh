#!/bin/bash
# E-373 (W-104, phase 4): each demonstrator's own suite on the head, one at a time, niced.
#     bash suites.sh [name ...]      names: tables csv makie report tde forks-session forks-Tables forks-CSV forks-DataFrames nd
# Logs to logs/<name>.log; a line per suite on stdout and in logs/summary.log.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
J=$R/julia-unified/julia
export JULIA_PKG_OFFLINE=true LOCK=$R/.jl-locks/julia-review.lock JULIA_LOCK=$R/.jl-locks/julia-review.lock
mkdir -p "$R/.jl-locks"
rev() { git -C "$R/$1" log -1 --format=%h; }
pkgtest() { (cd "$R/$1" && nice -n 10 timeout ${3:-3600} "$J" --startup-file=no --project=${2:-.} -e "using Pkg; Pkg.test(${4:-})"); }
run() {
  case $1 in
    tables) pkgtest TraitTables-unified ;;
    csv)    pkgtest TraitCSV-unified ;;
    makie)  pkgtest TraitMakie-unified ;;
    tde)    pkgtest TraitDifferentialEquations-unified ;;
    report) (cd "$R/TraitReport-unified" && JULIA="$J" nice -n 10 bash scripts/check.sh) ;;
    forks-session) (cd "$R/forks-unified" && nice -n 10 bash scripts/check_session.sh "$J") ;;
    forks-*) pkgtest forks-unified env_forks 5400 "\"${1#forks-}\"" ;;
    nd)     (cd "$R/ndport" && nice -n 10 timeout 3600 "$J" --startup-file=no -t 2 --project=env_unified scripts/r3_nd_tests.jl) ;;
    *) echo "unknown suite $1"; return 2 ;;
  esac
}
[ $# -eq 0 ] && set -- tables csv makie report tde forks-session forks-Tables forks-CSV forks-DataFrames nd
for n in "$@"; do
  s=$(date +%s)
  { echo "# E-373 $n $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) TraitWorld-unified $(rev TraitWorld-unified)"; run $n; } > "$H/logs/$n.log" 2>&1; rc=$?
  line="$n | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'tests passed|did not pass|Testing .* tests passed|^Test Summary' "$H/logs/$n.log" | tail -1 | cut -c1-160)"
  echo "$line" | tee -a "$H/logs/summary.log"
done
