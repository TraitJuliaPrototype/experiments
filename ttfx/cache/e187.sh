#!/bin/bash
# After W-64's revert: rebuild Julia and the facts system image, precompile C's environment, run the suites, then
# E-187: C's cache rebuilt from its store with small parts merged (TraitWorld session-cache 1d8e140), C/pk measured.
set -uo pipefail
R=/home/hellmann/Repos/julia-trait-bound; cd $R
( cd julia-1.13 && bash tw-build.sh; tail -1 tw-build.log )
bash experiments/factscompiler/scripts/build_facts_sysimage.sh > /tmp/claude-1000/facts-sysimage.log 2>&1; echo "facts sysimage rc=$?"
cd experiments/ttfx; H=$PWD; J=$R/julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=8 OPENBLAS_NUM_THREADS=1
mkdir -p logs/e187
for e in "env_core:$H/depot-C:$HOME/.julia:" "env_d:" "env_up:"; do
  env=${e%%:*}; dep=${e#*:}
  ( [ -n "$dep" ] && export JULIA_DEPOT_PATH=$dep
    flock /tmp/claude-1000/julia-review.lock nice -n 10 $J --startup-file=no --project=$env -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile s=", round(t; digits=1))' ) > logs/e187/precompile-$env.log 2>&1
  echo "$env $(grep -E 'precompile s=|ERROR' logs/e187/precompile-$env.log | tail -1)"
done
bash $R/experiments/checks/run_all.sh w64revert > /dev/null 2>&1
( cd $R/experiments/checks/logs/w64revert && for f in *.log; do echo "suite $f: $(grep -hE 'tests passed|errored during|checks pass|pass, .* fail' $f | tail -1)"; done )
# E-187: the cache's parts merged; the store kept, the parts and index made again
D=$(ls -d $H/cache/tw-cache-C/*/)
rm -rf $D/parts $D/index.txt $D/known.txt $D/build.lock
( export JULIA_DEPOT_PATH=$H/depot-C:$HOME/.julia: JULIA_TW_CACHE=0
  t0=$(date +%s); flock /tmp/claude-1000/julia-review.lock nice -n 10 $J --startup-file=no --project=env_core -e "using TraitWorld; TraitWorld._cache_build(\"$D\")" 2>&1 | tail -2; echo "builder s=$(( $(date +%s) - t0 ))" ) | tee logs/e187/builder.log
echo "parts: $(wc -l < $D/index.txt)"
bash run.sh e187 "C/p C/pk" 3
