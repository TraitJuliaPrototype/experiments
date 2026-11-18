#!/bin/bash
# W-157: the checks after a build of `next-s3`, in order: the environments' images, the census of both
# configurations with the nine loads (side by side), the methods the patches would not reach, the suites.
#     bash chain.sh <label>
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"; cd "$H"
L=$1
bash precompile.sh $L
CENSUS_TSV=logs/$L-facts.tsv nice -n 10 $JS --startup-file=no --project=env_facts census.jl $CSVFILE $LOADS > logs/$L-census-facts.log 2>&1 &
CENSUS_TSV=logs/$L-forks.tsv nice -n 10 $JS --startup-file=no --project=env_forks census.jl $CSVFILE $LOADS > logs/$L-census-forks.log 2>&1
wait
nice -n 10 $JS --startup-file=no --project=env_forks diag/intercept.jl CSV DataFrames TraitWorld $LOADS > logs/$L-intercept.log 2>&1
bash suites.sh $L > /dev/null 2>&1
echo "chain $L done $(date -Is)" >> logs/$L-summary.log
