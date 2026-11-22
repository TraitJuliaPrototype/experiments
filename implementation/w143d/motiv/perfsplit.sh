#!/bin/bash
# W-143d (E-540): perf profile of loop.jl on Julia trees: samples per call (ns) by function, subtyping's own
# functions apart from the harness's (dynamic calls, tuple types).   bash perfsplit.sh <label> sub|isect <tree>...
H=$(cd "$(dirname "$0")/.." && pwd); source "$H/env.sh" >/dev/null
label=$1; kind=$2; shift 2; out=$H/logs/perf-$label.log
echo "# W-143d perf $label $kind | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)" > $out
for t in "$@"; do
  d=$(mktemp -d); n=$(perf record -q -o $d/p.data -F 4000 $TW_ROOT/$t/julia --startup-file=no -t 1 $H/motiv/loop.jl $kind 8 2>/dev/null | awk '{print $3}')
  echo "== $t ($(git -C $TW_ROOT/$t rev-parse --short=10 HEAD)) calls $n" >> $out
  perf report -i $d/p.data --no-children --sort symbol --stdio -n 2>/dev/null | grep -v "^#" | grep -v "^$" |
    awk -v n=$n -v hz=4000 '{s=$2; sym=$4; ns=s/hz*1e9/n; tot+=ns; if (sym ~ /apply_generic|nth_field|lookup_typevalue|int64hash|arg_tuple|inst_arg_tuple|gc_|julia_|jfptr|typekeyvalue|jl_typemap|jl_eqtable|_jl_invoke|jl_invoke/) h+=ns; else {o+=ns; if (ns>0.8) printf "   %-34s %6.1f ns\n", sym, ns}} END {printf "   all %.1f ns per call; the harness (dispatch, tuple types, allocation, Julia code) %.1f; the rest (subtyping) %.1f\n", tot, h, o}' >> $out
  rm -rf $d
done
cat $out
