#!/bin/bash
# W-170 (E-538): a demonstrator's program as E-536's session runs it (w169/tools/prof.jl over w169/sessions/app.jl:
# the load, the first run of `main`, a second), in a setting's environment (B, A), of one kind: time, or trace (the
# compiles with their times, the dump of every code generation, the census of what the process compiled;
# python3 ../w169/tools/top.py logs/sessions/<...>-trace-<run>).
#     bash session.sh <odecb|odecb-plain|ode|ode-plain> <B|A|C|D> <time|trace> [run]   -> logs/sessions/<session>-<S>-<kind>-<run>.out
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
ses=$1; S=$2; kind=$3; run=${4:-1}
IMPL=$R/experiments/implementation; W169=$IMPL/w169
L=$W/logs/sessions; mkdir -p "$L"
out=$L/$ses-$S-$kind-$run.out
[ "$kind" = time ] && case $run in *-*) out=$L/${run%-*}-$ses-$S-time-${run##*-}.out ;; esac
case $ses in
  odecb)       vars=(W169_APP=$IMPL/w158/port/apps/ode_cb.jl) ;;
  odecb-plain) vars=(W169_APP=$W169/sessions/ode_cb_plain.jl) ;;
  ode)         vars=(W169_APP=$IMPL/w135/apps/ode.jl ODE_PLAIN=0) ;;
  ode-plain)   vars=(W169_APP=$IMPL/w135/apps/ode.jl ODE_PLAIN=1) ;;
  *) echo "session $ses" >&2; exit 2 ;;
esac
mode=$kind; flags=()
[ "$kind" = trace ] && { mode=time; flags=(--trace-compile="$L/$ses-$S-trace-$run.trace" --trace-compile-timing)
                         vars+=(W169_LLVM=$L/$ses-$S-trace-$run.llvm W169_CENSUS=$L/$ses-$S-trace-$run.census); }
{ header "session $ses $S $kind run $run"
  stamp=$(mktemp); t0=$(date +%s.%N)
  (cd "$W169" && export W169_MODE=$mode VERIFY=0 OPENBLAS_NUM_THREADS=1 "${vars[@]}" && jS "$S" demo "${flags[@]}" "$W169/tools/prof.jl" "$W169/sessions/app.jl") 2>&1
  rc=$?; t1=$(date +%s.%N)
  echo "WALL $t0 $t1 rc $rc"
  echo "CACHES written during the run: $(find "$D/$S" -newer "$stamp" -name '*.so' 2>/dev/null | wc -l)"; rm -f "$stamp"
  echo "# done $(date -Is) | load-after $(load)"; } > "$out"
grep -q 'Precompiling' "$out" && { echo "FAIL: $ses $S $kind precompiled ($out)" >&2; exit 3; }
grep -q '^CACHES written during the run: 0$' "$out" || { echo "FAIL: $ses $S $kind wrote package images ($out)" >&2; exit 4; }
grep -q '^END ' "$out" || { echo "FAIL: $ses $S $kind did not finish ($out)" >&2; exit 2; }
exit 0
