#!/bin/bash
# The night of 2026-10-22/23, one step after another, alone on the machine:
#   1. the full Julia build carrying W-41 and W-43 (julia-1.13 fa4e7f5798), under the memory guard;
#   2. the facts system image (the test bed `all`) on that build;
#   3. every suite and check (experiments/checks/run_all.sh w41-w43), the acceptance suite with G1.30, G1.31;
#   4. W-39's measurements on the new build (experiments/overnight-2026-10-21/run.sh: E-162, E-163, E-164).
# A step that fails stops the night before the measurements. One line per step in logs/driver.log.
# Start it outside Claude Code's sandbox (a job started from the sandboxed Bash tool dies with the command):
#   setsid nohup bash tonight.sh > logs/nohup.log 2>&1 < /dev/null &
set -u
R=/home/hellmann/Repos/julia-trait-bound
O=$R/experiments/overnight-2026-10-22; L=$O/logs; mkdir -p $L
LOCK=/tmp/claude-1000/julia-review.lock; mkdir -p /tmp/claude-1000
step() { echo "### $1 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" | tee -a $L/driver.log; }
fail() { echo "STOPPED: $1 $(date -Is)" | tee -a $L/driver.log; exit 1; }

step "1. Julia build (julia-1.13 $(git -C $R/julia-1.13 log --format=%h -1))"
flock $LOCK bash $R/julia-1.13/tw-build.sh; rc=$?
tail -3 $R/julia-1.13/tw-build.log > $L/build-tail.log
grep -q "BUILD EXIT 0" $R/julia-1.13/tw-build.log || fail "the build (rc=$rc; julia-1.13/tw-build.log)"
echo "  build ok: $($R/julia-1.13/julia --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)')" | tee -a $L/driver.log

step "2. facts system image"
flock $LOCK bash $R/experiments/factscompiler/scripts/build_facts_sysimage.sh > $L/facts-sysimage.log 2>&1 || fail "the facts image (logs/facts-sysimage.log)"

step "3. suites and checks (experiments/checks/logs/w41-w43/)"
bash $R/experiments/checks/run_all.sh w41-w43 > $L/checks.log 2>&1
cat $L/checks.log | tee -a $L/driver.log
acc=$(grep "acceptance-product" $L/checks.log)
echo "$acc" | awk '{for (i = 1; i < NF; i++) if ($(i+1) == "of" && $(i+3) == "checks" && $i == $(i+2)) ok = 1} END {exit !ok}' || fail "the acceptance suite (product): $acc"
grep -q "traitworld-product rc=0" $L/checks.log || fail "TraitWorld's suite (product)"

step "4. W-39's measurements on the new build"
bash $R/experiments/overnight-2026-10-21/run.sh > $L/w39.log 2>&1
step done
