#!/bin/bash
# W-161: every gate of the two lines merged on `next` (W-160's and W-155b's), and the suites, on julia-next with
# TraitWorld-unified. One job at a time, niced. Logs: logs/<label>-<name>.log; a line per suite in
# logs/<label>-summary.log.
#     bash suites.sh <label> [names...]
# names (default: all, in this order):
#   deep      W-155's gate_deep.jl (D-5)                 d11      W-155b's gate_d11.jl (D-11)
#   w160      W-160's check gates: new_fold, stores, kept_own, mistakes (E-436, E-441, E-444, E-440)
#   tests     Julia's core, subtype, Compiler/inline, Compiler/inference
#   library   TraitWorld's suite (report.jl, owner_only.jl, delete.jl among its files)
#   tde       the ODE port's suite            nd        NetworkDynamics' test subset (two threads)
#   makie     TraitMakie's suite              digests   the forks' session digests against upstream's (E-308)
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
L=$1; shift
T=$TW_ROOT/julia-next; J=$T/julia; LOG=$H/logs; S=$LOG/$L-summary.log
LIB=${LIB:-$TW_ROOT/TraitWorld-unified}
U=$TW_ROOT/experiments/unification
rev() { git -C "$1" log -1 --format=%h; }
dirty() { git -C "$1" diff --quiet HEAD -- . 2>/dev/null || echo +dirty; }
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-next $(rev $T)$(git -C $T diff --quiet HEAD -- src Compiler base || echo +dirty) | TraitWorld $(rev $LIB)$(dirty $LIB) | TDE $(rev $TW_ROOT/TraitDifferentialEquations-unified)$(dirty $TW_ROOT/TraitDifferentialEquations-unified) | TraitMakie $(rev $TW_ROOT/TraitMakie-unified) | ND $(rev $TW_ROOT/ndport/pkgs/NetworkDynamics-unified) | forks $(rev $TW_ROOT/forks-unified)"
run() {
  local s rc f
  s=$(date +%s)
  case $1 in
    deep)
      f=$LOG/$L-gate-deep.log
      nice -n 10 "$J" --startup-file=no "$U/w155/gate_deep.jl" > "$f" 2>&1; rc=$?
      note "gate_deep | exit $rc | $(tail -1 "$f")" ;;
    d11)
      f=$LOG/$L-gate-d11.log
      nice -n 10 "$J" --startup-file=no --project="$H/env_lib" "$U/w155b/gate_d11.jl" > "$f" 2>&1; rc=$?
      note "gate_d11 | exit $rc | $(tail -1 "$f")" ;;
    w160)
      for g in new_fold stores kept_own mistakes; do
        f=$LOG/$L-w160-$g.log
        p=$LIB; [ $g = kept_own ] && p=$U
        nice -n 10 "$J" --startup-file=no --project="$p" "$U/w160/check/$g.jl" > "$f" 2>&1; rc=$?
        note "w160 $g | exit $rc | $(tail -1 "$f" | cut -c1-200)"
      done ;;
    tests)
      for t in core subtype Compiler/inline Compiler/inference; do
        f=$LOG/$L-test-$(echo $t | tr / _).log
        s=$(date +%s)
        nice -n 10 "$J" --startup-file=no -e "Base.runtests([\"$t\"]; ncores=1)" > "$f" 2>&1; rc=$?
        note "test $t | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' "$f" | tail -1)"
      done ;;
    library)
      f=$LOG/$L-library.log
      (cd "$LIB" && nice -n 10 "$J" --startup-file=no --project=. test/runtests.jl) > "$f" 2>&1; rc=$?
      note "library | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'Fail|Error' "$f" | grep -v '^\s*$' | head -3 | tr '\n' ' ' | cut -c1-200)" ;;
    tde)
      f=$LOG/$L-tde.log
      (cd $TW_ROOT/TraitDifferentialEquations-unified && nice -n 10 "$J" --startup-file=no --project=. -e 'using Pkg; Pkg.test()') > "$f" 2>&1; rc=$?
      note "tde | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'tests passed|Some tests did not pass' "$f" | tail -1)" ;;
    nd)
      f=$LOG/$L-nd.log
      (cd $TW_ROOT/ndport && nice -n 10 "$J" -t 2 --startup-file=no --project=$H/nd/env_test_head scripts/r3_nd_tests.jl) > "$f" 2>&1; rc=$?
      note "nd | exit $rc | $(( $(date +%s) - s )) s | $(grep '^TEST' "$f" | tr '\n' ';' | cut -c1-600)" ;;
    makie)
      f=$LOG/$L-makie.log
      (cd $TW_ROOT/TraitMakie-unified && nice -n 10 "$J" --startup-file=no --project="$H/env_demo" test/runtests.jl) > "$f" 2>&1; rc=$?
      note "makie | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'Fail|Error' "$f" | head -3 | tr '\n' ' ' | cut -c1-200)" ;;
    digests)
      f=$LOG/$L-digests.log
      D=$TW_ROOT/forks-unified/data
      (export DATA=$D JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=120
       nice -n 10 "$J" --startup-file=no --project="$H/env_session" "$TW_ROOT/forks-unified/scripts/session_check.jl" > "$LOG/$L-digests-forks.txt" 2> "$f"
       nice -n 10 "$J" --startup-file=no --project="$TW_ROOT/forks-unified/env_upstream" "$TW_ROOT/forks-unified/scripts/session_check.jl" > "$LOG/$L-digests-upstream.txt" 2>> "$f")
      if [ -s "$LOG/$L-digests-forks.txt" ] && diff -q "$LOG/$L-digests-forks.txt" "$LOG/$L-digests-upstream.txt" > /dev/null; then
        note "digests | equal: $(wc -l < "$LOG/$L-digests-forks.txt") steps | $(( $(date +%s) - s )) s"
      else
        note "digests | DIFFER or missing | see $f"
      fi ;;
  esac
}
[ $# -eq 0 ] && set -- deep d11 w160 library tde makie nd digests tests
for n in "$@"; do run $n; done
