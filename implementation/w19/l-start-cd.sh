#!/bin/bash
# start lanes c and d once lanes a and b have ended
cd "$(dirname "$0")"
while pgrep -f "l-queue.sh l-queue-[ab].txt" > /dev/null; do sleep 30; done
rm -f /tmp/claude-harvest/l-skip-*
TREE=wt/w171-julia bash l-queue.sh l-queue-c.txt > logs/l-queue-c.out 2>&1 &
TREE=wt/w19-check bash l-queue.sh l-queue-d.txt > logs/l-queue-d.out 2>&1 &
TREE=wt/w19-julia bash l-queue.sh l-queue-e.txt > logs/l-queue-e.out 2>&1 &
wait
