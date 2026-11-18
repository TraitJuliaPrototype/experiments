#!/bin/bash
# W-155: the runs on the build with D-5 (fixed) and D-7 (E-417 again, E-419 after), one after another.
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
B=$TW_ROOT/julia-next/tw-build.log
until grep -q "BUILD EXIT" $B; do sleep 20; done
grep -q "BUILD EXIT 0" $B || { echo "build failed" > logs/e419-chain.log; exit 1; }
echo "# precompile $(date -Is) | next $(git -C $TW_ROOT/julia-next rev-parse --short=10 HEAD) + D-7 in the tree" > logs/e419-precompile.log
for e in env_forks env_facts env_session; do
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JN --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/e419-precompile.log 2>&1
done
for e in env_forks env_facts; do
  echo "== $e | load $(cut -d' ' -f1-3 /proc/loadavg) | next $(git -C $TW_ROOT/julia-next rev-parse --short=10 HEAD) with D-7 in the tree | TraitWorld-w155 $(git -C $TW_ROOT/TraitWorld-w155 log -1 --format=%h) forks $(git -C $TW_ROOT/forks log -1 --format=%h) | $(date -Is)"
  nice -n 10 timeout 1800 $JN --startup-file=no --project=$e deep.jl $CSVFILE $LOADS 2>&1 | grep -v "^ *$" | cut -c1-1200
done > logs/e417b-deep.log 2>&1
bash runs.sh julia-next e419-after 2
s=$(date +%s); nice -n 10 $JN --startup-file=no -e 'Base.runtests(["precompile"]; ncores=1)' > logs/e419-after-test-precompile.log 2>&1; rc=$?
echo "precompile test (after) | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' logs/e419-after-test-precompile.log | tail -1)" >> logs/e419-summary.log
d=$(mktemp -d -p $TW_ROOT/.julia-depot/agent-depots/w155)
JULIA_DEPOT_PATH=$d:$TW_ROOT/.julia-depot JULIA_DEBUG_EXTERNAL_CIS=1 nice -n 10 $JN --startup-file=no --project=$TW_ROOT/TraitWorld-w155 image.jl 2>&1 | grep -E "TraitWorld image|external CIs" | tail -3 > logs/e419-image.log
rm -rf "$d"
bash suites.sh julia-next e419 gate tests library digests > /dev/null 2>&1
echo "after done $(date -Is)" >> logs/e419-summary.log
