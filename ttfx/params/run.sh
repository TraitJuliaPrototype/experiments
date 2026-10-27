#!/bin/bash
# E-181: the probe (params.jl) on TraitDifferentialEquations' branch $1 (w34 or partial-p), each parameter kind in
# two fresh sessions; logs in logs/e181/.   bash params/run.sh <branch>
set -uo pipefail
cd "$(dirname "$0")/.."; R=$(cd ../.. && pwd); b=$1
git -C $R/TraitDifferentialEquations checkout -q $b || exit 1
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 OPENBLAS_NUM_THREADS=1
flock /tmp/claude-1000/julia-review.lock nice -n 19 $R/julia-1.13/julia --startup-file=no --project=env_d -e 'using Pkg; Pkg.precompile()' > /dev/null 2>&1
mkdir -p logs/e181
for k in vector tuple namedtuple struct; do for i in 1 2; do
  f=logs/e181/$b-$k-$i.log
  echo "# branch=$b ($(git -C $R/TraitDifferentialEquations log -1 --format=%h)) kind=$k run=$i julia-1.13=$(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld=$(git -C $R/TraitWorld log -1 --format=%h) load=$(cut -d' ' -f1-3 /proc/loadavg)" > $f
  PKIND=$k flock /tmp/claude-1000/julia-review.lock taskset -c 0-1 nice -n 19 $R/julia-1.13/julia --startup-file=no --compiled-modules=existing --pkgimages=existing --project=env_d params/params.jl >> $f 2>&1
  grep -E "^R|rror|recompil|Precompiling" $f | sed "s/^/$b $i: /"
done; done
