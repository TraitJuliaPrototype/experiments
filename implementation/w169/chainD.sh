#!/bin/bash
# W-169: the third part of r1: the runs whose package images changed under them. The profiled runs of the first part
# loaded the Profile standard library before the session, and CairoMakie's and Makie's images were rejected and
# written anew there (their .so files' times); the images of NetworkDynamics' stack, which depend on them, were then
# stale and were written anew inside nd's first unprofiled run (its check failed: logs/r1/nd-H-time-1.out). So: the
# frames sessions' unprofiled runs again on the images as they are now, nd's unprofiled run twice, and the runs of
# the first part that failed a check of the harness.
cd "$(dirname "$0")"
while [ "$(ps -eo args | grep -c '^bash run_all.sh r1')" -gt 0 ] || [ "$(ps -eo args | grep -c '^bash chainC.sh')" -gt 0 ]; do sleep 20; done
mkdir -p logs/r1/superseded
for f in logs/r1/frames-*-time-*.out logs/r1/nd-H-time-1.out logs/r1/frames-up-H-prof-2.out; do [ -f "$f" ] && mv "$f" logs/r1/superseded/; done
KINDS=" " bash run_all.sh r1 frames
source lib.sh; export LABEL=r1
for i in 1 2; do bash profile.sh nd H time $i; echo "nd H time $i | rc $? | load $(load)" >> logs/run-r1.log; done
for c in "table H trace" "table-plain H trace" "frames-up H dispatch" "frames-facts H dispatch" "frames-forks H dispatch" "frames-forks H inval"; do
  bash profile.sh $c 1; echo "$c 1 (again) | rc $? | load $(load)" >> logs/run-r1.log; done
