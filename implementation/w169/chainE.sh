#!/bin/bash
# W-169: the fourth part of r1: the demonstrators' trace runs again, with the phases marked in the dump of code
# generation (tools/prof.jl writes a PHASE line into it before each phase), so that what a load compiles is told
# from what the first run compiles.
cd "$(dirname "$0")"
while [ "$(ps -eo args | grep -c '^bash chainD.sh')" -gt 0 ]; do sleep 20; done
source lib.sh; export LABEL=r1
for c in table table-plain ode ode-plain odecb odecb-plain plot plot-plain report report-plain frames-up:V frames-up frames-facts frames-forks; do
  s=H; case $c in *:V) s=V; c=${c%:V} ;; esac
  bash profile.sh $c $s trace 2; echo "$c $s trace 2 | rc $? | load $(load)" >> logs/run-r1.log; done
