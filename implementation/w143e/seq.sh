#!/bin/bash
# W-143e: runs of run.sh one after another (one Julia job at a time).   TREE=<tree> bash seq.sh <label> <session:prog>...
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; label=$1; shift
for x in "$@"; do s=${x%%:*}; p=${x#*:}; [ "$p" = "$x" ] && p=census.jl
  l=$label; [ "$p" != census.jl ] && l=$label-$(basename $p .jl)
  bash run.sh $l $s $p > /dev/null 2>&1; done
echo SEQDONE
