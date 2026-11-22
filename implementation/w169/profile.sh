#!/bin/bash
# W-169 (E-536): one run of one session in one setting, of one kind. The one harness of the round: every table of
# the README is made from these runs (tools/split.py, tools/top.py).
#     bash profile.sh <session> <setting> <kind> [<run>]       LABEL=<label> (default r1)
# -> logs/<label>/<session>-<S>-<kind>-<run>.out
# Kinds:
#   time      the phases timed with Julia's counters (compile, compiled again, the collector, allocations); with the
#             process's wall time around it, so that Julia's start and exit are told apart (START/END lines)
#   prof      the phases under the sampling profiler with C frames (W169_DELAY, default 1 ms), classed (tools/prof.jl)
#   trace     as time, with --trace-compile-timing (every compile dispatched, with its time), Julia's dump of every
#             code generation (`jl_dump_compiles`) and, at the end, the census of the code instances the process
#             inferred or compiled (tools/census.jl); tools/top.py classes them
#   inval     as time, with Julia's invalidation log on (tools/invalidations.jl)
#   dispatch  as time, with the head's dispatch profiler (JULIA_DISPATCH_PROFILE=1; H only)
# Sessions (the environment is the harness's own, made for the setting by lib.sh):
#   frames-up (V, H)  upstream CSV and DataFrames compiled plainly: E-511's work, the nine loads, the work again
#   frames-facts (H)  the same packages compiled by facts, one line per module (W-134's env_facts)
#   frames-forks (H)  the forks' CSV and DataFrames
#   table, table-plain, ode, ode-plain, odecb, odecb-plain, plot, plot-plain, report, report-plain (H)
#                     a demonstrator's program as E-521's session runs it, and its plain twin on the same build
#   nd (H)            NetworkDynamics' workload (ndport/scripts/workload.jl)
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ses=$1; S=$2; kind=$3; run=${4:-1}; label=${LABEL:-r1}
D=$LOGS/$label; mkdir -p "$D"
out=$D/$ses-$S-$kind-$run.out
CSV=$R/experiments/interfaces/App/data/sample.csv
NINE="OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays CairoMakie REPL"
APPS=$IMPL/w135/apps
SCR=$(mktemp -d)
vars=(); sesfile=$W169/sessions/app.jl; envname=demo; cwd=$W169
case $ses in
  frames-up)    envname=up;    sesfile=$W169/sessions/frames.jl; vars=(W169_CSV=$CSV "W169_LOADS=$NINE") ;;
  frames-facts) envname=facts; sesfile=$W169/sessions/frames.jl; vars=(W169_CSV=$CSV "W169_LOADS=$NINE") ;;
  frames-forks) envname=forks; sesfile=$W169/sessions/frames.jl; vars=(W169_CSV=$CSV "W169_LOADS=$NINE") ;;
  table)        vars=(W169_APP=$APPS/table.jl W169_ARGS=$W169/data/t.csv TABLE_PLAIN=0) ;;
  table-plain)  vars=(W169_APP=$APPS/table.jl W169_ARGS=$W169/data/t.csv TABLE_PLAIN=1) ;;
  ode)          vars=(W169_APP=$APPS/ode.jl ODE_PLAIN=0) ;;
  ode-plain)    vars=(W169_APP=$APPS/ode.jl ODE_PLAIN=1) ;;
  odecb)        vars=(W169_APP=$IMPL/w158/port/apps/ode_cb.jl) ;;
  odecb-plain)  vars=(W169_APP=$W169/sessions/ode_cb_plain.jl) ;;
  plot)         vars=(W169_APP=$APPS/plot.jl W169_ARGS=$SCR/plot.png) ;;
  plot-plain)   vars=(W169_APP=$APPS/plot_plain.jl W169_ARGS=$SCR/plot.png) ;;
  report)       vars=(W169_APP=$APPS/report.jl "W169_ARGS=$R/TraitReport/data/sensors.csv $SCR/report.png" REPORT_PLAIN=0) ;;
  report-plain) vars=(W169_APP=$APPS/report.jl "W169_ARGS=$R/TraitReport/data/sensors.csv $SCR/report.png" REPORT_PLAIN=1) ;;
  nd)           envname=nd; sesfile=$W169/sessions/nd.jl; cwd=$R/ndport
                vars=(W169_STDOUT=1 NDROOT=$R/ndport NDW_API=ports NDW_STACK=ports NDW_PASSES=first,again,params,changed,graphtype) ;;
  *) die "session $ses" ;;
esac
E=$(envof "$S" "$envname") || exit 1
flags=(); mode=$kind
case $kind in
  time|prof|inval) ;;
  trace) mode=time; flags=(--trace-compile="$D/$ses-$S-trace-$run.trace" --trace-compile-timing)
         vars+=(W169_LLVM=$D/$ses-$S-trace-$run.llvm W169_CENSUS=$D/$ses-$S-trace-$run.census) ;;
  dispatch) [ "$S" = V ] && die "the dispatch profiler is the head's"; mode=time; vars+=(JULIA_DISPATCH_PROFILE=1) ;;
  *) die "kind $kind" ;;
esac
{ echo "# W-169 $ses $S $kind run $run | $(date -Is) | load-before $(load) | julia $(rev "$(jtree "$S")") | TraitWorld $(rev "$(tree "$S" TW)") TDE $(rev "$(tree "$S" TDE)") TM $(rev "$(tree "$S" TM)") TT $(rev "$(tree "$S" TT)") TC $(rev "$(tree "$S" TC)") TR $(rev "$(tree "$S" TR)") forks $(rev "$(tree "$S" FORKS)") ND $(rev "$(tree "$S" ND)") | env ${E#$R/} | depots $(jdepots "$S" | sed "s|$R/||g") | product setting, strict mode off, one thread"
  stamp=$(mktemp); t0=$(date +%s.%N)
  (cd "$cwd" && export W169_MODE=$mode VERIFY=0 OPENBLAS_NUM_THREADS=1 TO=${TO:-1500} "${vars[@]}" && jl "$S" --project="$E" "${flags[@]}" "$W169/tools/prof.jl" "$sesfile") 2>&1
  rc=$?; t1=$(date +%s.%N)
  echo "WALL $t0 $t1 rc $rc"
  # a precompile writes an image's .so anew; a load touches the .ji files it uses, not the .so
  echo "CACHES written during the run: $(find "$(mydepot "$S")" -newer "$stamp" -name '*.so' 2>/dev/null | wc -l)"; rm -f "$stamp"
  echo "# done $(date -Is) | load-after $(load)"; } > "$out"
rm -rf "$SCR"
grep -q 'Precompiling' "$out" && { echo "W-169 FAIL: $ses $S $kind precompiled: an image was stale or missing ($out)" >&2; exit 3; }
grep -q '^CACHES written during the run: 0$' "$out" || { echo "W-169 FAIL: $ses $S $kind wrote package images: a load precompiled ($out)" >&2; exit 4; }
grep -q '^END ' "$out" || { echo "W-169 FAIL: $ses $S $kind did not finish ($out)" >&2; exit 2; }
exit 0
