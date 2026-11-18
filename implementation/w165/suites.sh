#!/bin/bash
# W-165 (E-503): the checks of the brief on a built tree, one job at a time, niced. The commands are those of
# `w161/suites.sh` and `e262_suites.sh`, with the tree's binary in place of julia-next's, and a depot of this
# work item's own stacked before the shared one (compiled caches go there; packages come from the shared depot).
#     bash experiments/implementation/w165/suites.sh <julia tree> <label> [names...]
# names (default: all, in this order): base (Base's subtype, core, ambiguous, worlds), detect (detect_ambiguities(Base)),
#   library, tde, makie, nd, digests, docs (the three example scripts)
# Logs: w165/logs/<label>-<name>.log; one line per check in w165/logs/<label>-summary.log.
set -u
H=$(cd "$(dirname "$0")" && pwd)
source "$H/../../../env.sh"
R=$TW_ROOT
T=$(cd "$R" && cd "$1" && pwd) || exit 2; J=$T/julia; L=$2; shift 2
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w165:$R/.julia-depot:
export JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
mkdir -p $R/.julia-depot/agent-depots/w165 "$H/logs"
I=$R/experiments/implementation/w161
LOG=$H/logs; S=$LOG/$L-summary.log
rev() { git -C "$1" log -1 --format=%h; }
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $(basename $T) $("$J" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') | TraitWorld $(rev $R/TraitWorld) | TDE $(rev $R/TraitDifferentialEquations) | TraitMakie $(rev $R/TraitMakie) | ND $(rev $R/ndport/pkgs/NetworkDynamics-unified) | forks $(rev $R/forks)"
run() {
  local s rc f t
  s=$(date +%s)
  case $1 in
    base)
      for t in subtype core ambiguous worlds; do
        f=$LOG/$L-base-$t.log; s=$(date +%s)
        nice -n 10 "$J" --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$f" 2>&1; rc=$?
        note "base $t | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' "$f" | tail -1)"
      done ;;
    detect)
      f=$LOG/$L-detect.log
      nice -n 10 "$J" --startup-file=no -e 'using Test; a = Test.detect_ambiguities(Base); println("detect_ambiguities(Base): ", length(a)); foreach(p -> println(p[1], "\n  ", p[2]), a)' > "$f" 2>&1; rc=$?
      note "detect | exit $rc | $(grep 'detect_ambiguities' "$f")" ;;
    library)
      f=$LOG/$L-library.log
      (cd "$R/TraitWorld" && nice -n 10 "$J" --startup-file=no --project=. test/runtests.jl) > "$f" 2>&1; rc=$?
      note "library | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'Fail|Error' "$f" | grep -v '^\s*$' | head -3 | tr '\n' ' ' | cut -c1-200)" ;;
    tde)
      f=$LOG/$L-tde.log
      (cd $R/TraitDifferentialEquations && nice -n 10 "$J" --startup-file=no --project=. -e 'using Pkg; Pkg.test()') > "$f" 2>&1; rc=$?
      note "tde | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'tests passed|Some tests did not pass' "$f" | tail -1)" ;;
    makie)
      f=$LOG/$L-makie.log
      (cd $R/TraitMakie && nice -n 10 "$J" --startup-file=no --project="$I/env_demo" test/runtests.jl) > "$f" 2>&1; rc=$?
      note "makie | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'Fail|Error' "$f" | head -3 | tr '\n' ' ' | cut -c1-200)" ;;
    nd)
      f=$LOG/$L-nd.log
      (cd $R/ndport && nice -n 10 "$J" -t 2 --startup-file=no --project=$I/nd/env_test_head scripts/r3_nd_tests.jl) > "$f" 2>&1; rc=$?
      note "nd | exit $rc | $(( $(date +%s) - s )) s | $(grep '^TEST' "$f" | tr '\n' ';' | cut -c1-600)" ;;
    digests)
      f=$LOG/$L-digests.log
      D=$R/forks/data
      (export DATA=$D JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=120
       nice -n 10 "$J" --startup-file=no --project="$I/env_session" "$R/forks/scripts/session_check.jl" > "$LOG/$L-digests-forks.txt" 2> "$f"
       nice -n 10 "$J" --startup-file=no --project="$R/forks/env_upstream" "$R/forks/scripts/session_check.jl" > "$LOG/$L-digests-upstream.txt" 2>> "$f")
      if [ -s "$LOG/$L-digests-forks.txt" ] && diff -q "$LOG/$L-digests-forks.txt" "$LOG/$L-digests-upstream.txt" > /dev/null; then
        note "digests | equal: $(wc -l < "$LOG/$L-digests-forks.txt") steps | $(( $(date +%s) - s )) s"
      else
        note "digests | DIFFER or missing | see $f"
      fi ;;
    docs)
      for t in intro tutorial strict; do
        f=$LOG/$L-docs-$t.log
        (cd $R/TraitWorld && nice -n 10 "$J" --project=. --startup-file=no $R/experiments/docs-examples/$t.jl) > "$f" 2>&1; rc=$?
        note "docs $t | exit $rc | $(tail -1 "$f" | cut -c1-200)"
      done ;;
  esac
}
[ $# -eq 0 ] && set -- base detect library tde makie nd digests docs
for n in "$@"; do run $n; done
