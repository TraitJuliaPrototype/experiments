#!/bin/bash
# W-169: the images every session needs, written into the setting's own depot (agent-depots/w169/<S>) before any
# timed run.     bash prepare.sh H [up facts forks demo nd]     -> logs/prepare-<S>.log
# V needs `up` only; its images are the round's (read only), so this writes nothing for V unless one is missing.
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
S=$1; shift
case $S in H) ALL="up facts forks demo nd" ;; V) ALL="up" ;; *) die "setting $S" ;; esac
ENVS=${*:-$ALL}
header "$LOGS/prepare-$S.log" "W-169 prepare $S ($ENVS)" "$S"
echo "# depots: $(jdepots "$S")" >> "$LOG"
check "$S"
for e in $ENVS; do p=$(envof "$S" "$e") || exit 1
  t0=$(date +%s)
  JULIA_NUM_PRECOMPILE_TASKS=4 ALLOW_PRECOMPILE=1 TO=5400 HEAD=200 cell "precompile $S $e" \
    jl "$S" --project="$p" -e 'Base.Precompilation.precompilepkgs(; timing = true)' || echo "# $e: precompile failed" >> "$LOG"
  echo "# $e: $(( $(date +%s) - t0 )) s" >> "$LOG"
done
footer
