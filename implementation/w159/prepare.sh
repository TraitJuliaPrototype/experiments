#!/bin/bash
# W-159, step 1 of the round, per setting: the environments made for the setting's trees, and every package image
# they need written into the setting's depot, before any timed cell (a cell that precompiles fails its row).
#     bash prepare.sh H|B|V [env ...]      -> logs/prepare-<S>.log
# Environments (the harnesses' own, their trees replaced by the setting's; mkenv.py):
#   up facts forks lib demo   W-134's env_up, env_facts, env_forks, env_lib, env_demo (the nine loads, plain code,
#                             the demonstrators' sessions, the prompt rows, the loads)
#   ndup                      V only: ndport/env_upstream (upstream NetworkDynamics on vanilla; PREP_LABEL=<x> names the log)
#   nd ndtest                 ndport's env_unified_r5 (the workload) and env_unified (the test subset)
#   tw                        the library's own project (the calls, the mistakes)
# V takes `up` only. Cost: after a rebuild of Julia every image is written again: CairoMakie's stack in `up`, `demo`
# and `nd` dominates (on the tag's round about 3 minutes per environment with 4 tasks; nd about 5). `facts` needs
# w134/pkgs-facts (made by w134/prep.jl; ignored by git): it is checked, not made.
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
S=$1; shift
case $S in H|B) ALL="tw up facts forks lib demo nd ndtest" ;; V) ALL="up" ;; *) die "setting $S" ;; esac
ENVS=${*:-$ALL}
header "$LOGS/prepare-$S${PREP_LABEL:+-$PREP_LABEL}.log" "prepare $S ($ENVS)" "$S"
check "$S"
[ -d "$IMPL/w134/pkgs-facts/CSV" ] || die "w134/pkgs-facts is missing: run w134/prep.jl (its README)"
[ "$S" != H ] || [ -d "$W159/pkgs-facts-head/CSV" ] || die "w159/pkgs-facts-head is missing: run facts_head.sh"
for e in $ENVS; do
  case $e in
    tw) p=$(tree "$S" TW) ;;
    up|facts|forks|lib|demo) p=$(envfor "$S" "$IMPL/w134/env_$e" "$e") || exit 1 ;;
    nd) p=$(envfor "$S" "$R/ndport/env_unified_r5" nd) || exit 1 ;;
    ndtest) p=$(envfor "$S" "$R/ndport/env_unified" ndtest) || exit 1 ;;
    ndup) p=$(envfor "$S" "$R/ndport/env_upstream" ndup) || exit 1 ;;   # V only: upstream NetworkDynamics (g2_nd.sh UPSTREAM=1)
    *) die "environment $e" ;;
  esac
  t0=$(date +%s)
  JULIA_NUM_PRECOMPILE_TASKS=4 ALLOW_PRECOMPILE=1 TO=5400 HEAD=200 cell "precompile $S $e (${p#$R/})" \
    jl "$S" --project="$p" -e 'Base.Precompilation.precompilepkgs(; timing = true)' || echo "# $e: precompile failed" >> "$LOG"
  echo "# $e: $(( $(date +%s) - t0 )) s" >> "$LOG"
done
footer
