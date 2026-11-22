#!/bin/bash
# W-169: the second part of r1 (run after the first): the unprofiled runs and the profiles of the demonstrators'
# sessions, the frames sessions' profiles again with the profiler that loads no standard library, and every run of
# the first part that failed its checks.
cd "$(dirname "$0")"
while [ "$(ps -eo args | grep -c '^bash run_all.sh r1')" -gt 0 ]; do sleep 20; done
KINDS=prof bash run_all.sh r1 table ode plot
NOTIME=1 KINDS=prof bash run_all.sh r1 frames
