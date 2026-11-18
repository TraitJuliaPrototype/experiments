#!/bin/bash
# W-155: the D-5 commit's runs, one after another (E-417).
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
L=logs/e417
echo "# precompile $(date -Is)" > $L-precompile.log
for e in env_forks env_facts env_session; do
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JN --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> $L-precompile.log 2>&1
done
for e in env_forks env_facts; do
  echo "== $e | load $(cut -d' ' -f1-3 /proc/loadavg) | next $(git -C $TW_ROOT/julia-next rev-parse --short=10 HEAD) (+ D-5 uncommitted) TraitWorld-w155 $(git -C $TW_ROOT/TraitWorld-w155 log -1 --format=%h) forks $(git -C $TW_ROOT/forks log -1 --format=%h) | $(date -Is)"
  nice -n 10 timeout 1800 $JN --startup-file=no --project=$e deep.jl $CSVFILE $LOADS 2>&1 | grep -v "^ *$" | cut -c1-1200
done > $L-deep.log 2>&1
for j in JU JN; do
  d=$(mktemp -d -p $TW_ROOT/.julia-depot/agent-depots/w155)
  lib=$([ $j = JU ] && echo TraitWorld-base || echo TraitWorld-w155)
  JULIA_DEPOT_PATH=$d:$TW_ROOT/.julia-depot JULIA_DEBUG_EXTERNAL_CIS=1 nice -n 10 ${!j} --startup-file=no --project=$TW_ROOT/$lib image.jl 2>&1 | grep -E "TraitWorld image|external CIs" | tail -3
  rm -rf "$d"
done > $L-image.log 2>&1
bash suites.sh julia-next e417 gate tests library digests > /dev/null 2>&1
LIB=$TW_ROOT/TraitWorld-base bash suites.sh julia-unified base library digests > /dev/null 2>&1
echo "chain done $(date -Is)" >> $L-precompile.log
