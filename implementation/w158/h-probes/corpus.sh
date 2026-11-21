#!/bin/bash
# Open issue 251: the readings over every corpus, one Julia process at a time, niced (README "The check's verdict and
# the optimizer"). After `source h-probes/env.sh`:   bash corpus.sh <label> [corpus …]
# Writes ../logs/h-corpus-<corpus>-<label>.log (the differences) and .tsv (every method under every reading).
set -u
L=$1; shift
CS=${@:-library intro tutorial strict demos}
for c in $CS; do
  if [ "$c" = demos ]; then cd $TW_ROOT/TraitDifferentialEquations; P=$ENVG; else cd $LIBG; P=.; fi
  echo "# $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" > $W158/logs/h-corpus-$c-$L.log
  H_CORPUS=$c H_OUT=$W158/logs/h-corpus-$c-$L.tsv timeout 1500 nice -n 10 $JN --startup-file=no --project=$P $W158/h-probes/corpus.jl >> $W158/logs/h-corpus-$c-$L.log 2>&1
  echo "$c: exit $?; $(grep '== corpus' $W158/logs/h-corpus-$c-$L.log)"
done
