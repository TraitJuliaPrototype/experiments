#!/bin/bash
# W-159, G-6: E-383 and E-387's build: each demonstrator's program as a trimmed binary under --trim=safe
# (w166/build_c.sh, unchanged but for its log and output directories): the verifier's errors (w135/summarize.py),
# the binary's size, whether it runs and prints the session's output (the binary against the session, in one data directory). The plain
# twins (the report's PlainTables with PlainPlots, the ODE program's PlainODE) on the same build are the baseline.
# Counts do not move with the machine's load, and the tag's trees do not change: the tag's counts are E-509's
# (julia-unified with images: table 0, plot 6, report 6, ODE 50) and vanilla's E-383's; SETTINGS="H B" builds the
# tag again (B: julia-unified with its demonstrators).
#     bash g6_builds.sh <label>        APPS="table plot report ode ode_cb table-plain plot-plain report-plain ode-plain"
# ode_cb is the ODE program with callbacks it knows (w158/port/apps/ode_cb.jl); table-plain (TABLE_PLAIN=1,
# PlainTables) and plot-plain (w135/apps/plot_plain.jl, PlainPlots) are the twins of the table and the plot.
# -> logs/g6-builds-<label>.log, logs/g6-<label>/ (build logs). About 12 minutes on H alone: over ten, see README.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; SETTINGS=${SETTINGS:-H}; D=$LOGS/g6-$label; mkdir -p "$D"
header "$LOGS/g6-builds-$label.log" "G-6 E-383 the demonstrators' programs, trimmed (w166/build_c.sh)" $SETTINGS
DATA=$D/data; mkdir -p "$DATA"; cp "$R/TraitReport/data/sensors.csv" "$DATA/"
awk 'BEGIN { print "id,x,y,name"; for (i = 1; i <= 500; i++) printf "%d,%.3f,%.3f,n%d\n", i, i*0.1, 100-i*0.05, i%7 }' > "$DATA/t.csv"
for s in $SETTINGS; do check $s; E=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  for a in ${APPS:-table plot report ode ode_cb table-plain plot-plain report-plain ode-plain}; do
    app=${a%-plain}; plain=0; [ "$a" != "$app" ] && plain=1
    # the program's file (relative to w135/apps, as build_c.sh reads it) and the packages whose images it needs
    src=$app; pk=""
    case $a in
      ode_cb) src=../../w158/port/apps/ode_cb; pk="TraitWorld TraitDifferentialEquations" ;;
      table-plain) pk="PlainTables" ;;
      plot-plain) src=plot_plain; pk="PlainPlots" ;;
    esac
    t0=$(date +%s)
    TABLE_PLAIN=$plain REPORT_PLAIN=$plain ODE_PLAIN=$plain NAME=$s-$a JULIA_TREE=$(realpath --relative-to="$R" "$(jtree $s)") \
      TW=$(realpath --relative-to="$R" "$(tree $s TW)") DEPOT=$(depot $s) LOGDIR=$D OUTDIR=$D/out ${pk:+PKGS="$pk"} \
      bash "$IMPL/w166/build_c.sh" $src "$E" > "$D/$s-$a.stdout" 2>&1
    f=$D/w166c-$s-$a.build.log
    echo "$s $a | $(( $(date +%s) - t0 )) s | load $(load) | $(grep -h '^from source' "$f" | head -1) | $(python3 "$IMPL/w135/summarize.py" "$f" | head -1 | cut -c1-200) | $(grep -h '^link:' "$f" | tail -1)" >> "$LOG"
    grep -q '^from source: none' "$f" || echo "# NOTE $s $a: a package was loaded from source in the build (its count is not comparable)" >> "$LOG"
    if [ -x "$D/out/w166c-$s-$a" ]; then   # the binary and the session in the same data directory, outputs compared
      case $app in table) args="t.csv" ;; report) args="sensors.csv report.png" ;; *) args="" ;; esac
      (cd "$DATA" && timeout 120 "$D/out/w166c-$s-$a" $args > "$D/$s-$a.bin.out" 2>&1); bin=$?
      (cd "$DATA" && TABLE_PLAIN=$plain REPORT_PLAIN=$plain ODE_PLAIN=$plain VERIFY=0 TO=600 jl $s --project="$E" -e 'include(ARGS[1]); exit(main(ARGS[2:end]))' "$IMPL/w135/apps/$src.jl" $args > "$D/$s-$a.ses.out" 2>&1); ses=$?
      echo "  binary exit $bin, session exit $ses, output equal: $(cmp -s "$D/$s-$a.bin.out" "$D/$s-$a.ses.out" && echo yes || echo no)" >> "$LOG"
      rm -f "$D/out/w166c-$s-$a"
    fi
  done; done
footer
