#!/bin/bash
# W-167: the images setting G needs, into G's depot (w159/prepare.sh's steps, with this directory's lib.sh).
#     bash prepare.sh [env ...]     envs: tw up facts forks lib demo nd ndtest (default all) -> logs/prepare-G.log
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
S=G; ENVS=${*:-tw up facts forks lib demo nd ndtest}
header "$LOGS/prepare-G.log" "W-167 prepare G ($ENVS)" G
check G
for e in $ENVS; do
  case $e in
    tw) p=$(tree G TW) ;;
    up|facts|forks|lib|demo) p=$(envfor G "$IMPL/w134/env_$e" "$e") || exit 1 ;;
    nd) p=$(envfor G "$R/ndport/env_unified_r5" nd) || exit 1 ;;
    ndtest) p=$(envfor G "$R/ndport/env_unified" ndtest) || exit 1 ;;
    *) die "environment $e" ;;
  esac
  t0=$(date +%s)
  JULIA_NUM_PRECOMPILE_TASKS=4 ALLOW_PRECOMPILE=1 TO=5400 HEAD=200 cell "precompile G $e (${p#$R/})" \
    jl G --project="$p" -e 'Base.Precompilation.precompilepkgs(; timing = true)' || echo "# $e: precompile failed" >> "$LOG"
  echo "# $e: $(( $(date +%s) - t0 )) s" >> "$LOG"
done
footer
