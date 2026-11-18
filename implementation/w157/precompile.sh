#!/bin/bash
# W-157: the environments' images made again for the build in julia-s3 (after each rebuild of Base).
#     bash precompile.sh <label>
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
L=${1:-base}
echo "# precompile $(date -Is) | s3 $(git -C $TW_ROOT/julia-s3 log -1 --format=%h) | load $(cut -d' ' -f1-3 /proc/loadavg)" > logs/$L-precompile.log
for e in env_forks env_facts env_session env_lib; do
  s=$(date +%s)
  JULIA_NUM_PRECOMPILE_TASKS=4 nice -n 10 $JS --startup-file=no --project=$e -e 'using Pkg; Pkg.precompile()' >> logs/$L-precompile.log 2>&1
  echo "## $e: $(( $(date +%s) - s )) s" >> logs/$L-precompile.log
done
echo "# done $(date -Is)" >> logs/$L-precompile.log
