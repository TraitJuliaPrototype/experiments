#!/bin/bash
# W-155: the checks on the head of `next` (D-5, the split's branch edge, D-7), one after another.
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
B=$TW_ROOT/julia-next/tw-build.log
sleep 30
until grep -q "BUILD EXIT" $B; do sleep 20; done
grep -q "BUILD EXIT 0" $B || { echo "build failed" > logs/final-chain.log; exit 1; }
echo "# precompile $(date -Is) | next $(git -C $TW_ROOT/julia-next rev-parse --short=10 HEAD)" > logs/final-precompile.log
for e in env_forks env_facts env_session; do
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JN --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/final-precompile.log 2>&1
done
for e in env_forks env_facts; do
  echo "== $e | load $(cut -d' ' -f1-3 /proc/loadavg) | next $(git -C $TW_ROOT/julia-next rev-parse --short=10 HEAD) | TraitWorld-w155 $(git -C $TW_ROOT/TraitWorld-w155 log -1 --format=%h) forks $(git -C $TW_ROOT/forks-unified log -1 --format=%h) | $(date -Is)"
  nice -n 10 timeout 1800 $JN --startup-file=no --project=$e deep.jl $CSVFILE $LOADS 2>&1 | grep -v "^ *$" | cut -c1-1200
done > logs/final-deep.log 2>&1
d=$(mktemp -d -p $TW_ROOT/.julia-depot/agent-depots/w155)
JULIA_DEPOT_PATH=$d:$TW_ROOT/.julia-depot JULIA_DEBUG_EXTERNAL_CIS=1 nice -n 10 $JN --startup-file=no --project=$TW_ROOT/TraitWorld-w155 image.jl 2>&1 | grep -E "TraitWorld image|external CIs" | tail -3 > logs/final-image.log
rm -rf "$d"
bash suites.sh julia-next final gate tests library digests > /dev/null 2>&1
echo "final done $(date -Is)" >> logs/final-summary.log
