#!/bin/bash
# U6 (E-252): every arrangement under one precompile mode; logs in logs/<R>-<mode>.log.
#     ./all.sh <mode> [R ...]
cd "$(dirname "$0")"
MODE=$1; shift
ROOT=../../..
declare -A S=(
  [R1]="P" [R2]="P" [R3]="P" [R4]="P" [R5]="Z" [R6]="Sp" [R7]="Sp"
  [R8]="Pt Fo,Sp Sp,Fo" [R8b]="Pt Fo,Sp Sp,Fo" [R9]="P,Xs main,Xs" [R9b]="P" [R10]="P"
)
for R in ${@:-R1 R2 R3 R4 R5 R6 R7 R8 R8b R9 R9b R10}; do
  $ROOT/experiments/tools/jl --name w83u6 $ROOT/julia-1.13/julia --startup-file=no run.jl $R $MODE ${S[$R]} \
    > logs/$R-$MODE.log 2>&1
  grep RESULT logs/$R-$MODE.log
done
