#!/bin/bash
# W-155: E-419's runs before the code slot's removal, on the D-5 build (after chain_d5.sh).
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
until grep -q "chain done" logs/e417-precompile.log; do sleep 20; done
bash runs.sh julia-next e419-before 2
s=$(date +%s); nice -n 10 $JN --startup-file=no -e 'Base.runtests(["precompile"]; ncores=1)' > logs/e419-before-test-precompile.log 2>&1; rc=$?
echo "precompile test (before) | exit $rc | $(( $(date +%s) - s )) s | $(grep -E 'SUCCESS|FAILURE' logs/e419-before-test-precompile.log | tail -1)" >> logs/e419-summary.log
echo "before done $(date -Is)" >> logs/e419-summary.log
