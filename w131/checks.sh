#!/bin/bash
# Open issue 131 and L-49 checks against the branch w131 (TraitWorld worktree ../TraitWorld-w131); from ../w130/checks.sh, each Julia job in a slot of
# experiments/tools/jl: TraitWorld (product setting and the test bed `all`), the acceptance suite (both), the
# demonstrators' suites and TDE's session from scratch copies whose TraitWorld paths name the worktree (absolute;
# Pkg's test sandbox refuses a path through a link),
# the forks' session digests from a scratch copy of env_forks that develops the worktree.
#     bash checks.sh <tag> <scratch dir: demos/ (copies, absolute paths: every Project.toml and Manifest.toml), forks-w131/ (env)> [demos]
R=/home/hellmann/Repos/julia-trait-bound; TW=$R/TraitWorld-w131
J=$R/julia-1.13/julia; FI=$R/julia-1.13/usr/lib/julia/facts/sys.so
L=$R/experiments/checks/logs/w131/$1; S=$2; mkdir -p $L
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
run() {  # name, dir, mode, args...
  local name=$1 dir=$2 mode=$3; shift 3
  local F=""; if [ $mode = all ]; then F="-J $FI"; export JULIA_DEPOT_PATH=/tmp/claude-1000/depot-facts:$HOME/.julia:; else unset JULIA_DEPOT_PATH; fi
  (cd $dir && $R/experiments/tools/jl --name w131-$mode timeout -s KILL 5400 $J $F --startup-file=no "$@" > $L/$name.log 2>&1); local rc=$?
  echo "$name rc=$rc  $(grep -E 'tests passed|of [0-9]+ checks pass|[0-9]+ pass, [0-9]+ fail|Test Failed|errored' $L/$name.log | tail -1)"
}
T='using Pkg; Pkg.test()'
ONLY=${3:-all}   # `demos`: the demonstrators and TDE's session only
echo "TraitWorld $(git -C $TW log --oneline -1 | cut -c1-7); julia-1.13 $(git -C $R/julia-1.13 log --oneline -1 | cut -c1-10); $(date -Iseconds)"
if [ $ONLY = all ]; then
run traitworld-product $TW plain --project=. -e "$T"
run traitworld-all     $TW all   --project=. -e "$T"
run acceptance-product $TW plain --project=. $R/experiments/facts/acceptance_compiler.jl
run acceptance-all     $TW all   --project=. $R/experiments/facts/acceptance_compiler.jl
fi
for d in TraitTables TraitCSV TraitDifferentialEquations TraitMakie; do run $d $S/demos/$d plain --project=. -e "$T"; done
# TDE's session: RESULT lines against experiments/w81/x1/session-x1-one-function.log
(cd $S/demos/TraitDifferentialEquations && JULIA_LOAD_PATH="scripts/env:@stdlib" $R/experiments/tools/jl --name w131-plain timeout -s KILL 1800 $J --startup-file=no scripts/session.jl trait > $L/tde-session.log 2>&1)
diff <(grep '^RESULT' $R/experiments/w81/x1/session-x1-one-function.log) <(grep '^RESULT' $L/tde-session.log) > $L/tde-session.diff &&
  echo "tde-session: $(grep -c '^RESULT' $L/tde-session.log) RESULT lines identical" || echo "tde-session: RESULT lines differ ($L/tde-session.diff)"
# the forks' session digests (the script takes the lock itself)
[ $ONLY = all ] || { echo done; exit 0; }
(cd $R/forks && JULIA_DEPOT_PATH=/tmp/claude-1000/depots/w131:$HOME/.julia: TMPDIR=$S bash scripts/check_session.sh $J $S/forks-w131 > $L/forks-check-session.log 2>&1); echo "forks: $(tail -3 $L/forks-check-session.log | tr '\n' ' ')"
echo done
