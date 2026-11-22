#!/bin/bash
# W-168, G-6 (E-519's open part): the plot's and the report's binaries (trimmed by w166/build_c.sh) write their PNG; a
# session of the same program writes it too: the two files compared byte for byte (cmp), the outputs on stdout
# compared as g6_builds.sh does. Each in a directory of its own, the same relative argument (the PNG's name).
# The build's own images step is as g6_builds.sh's. Run once more after the compare for a second PNG of the binary
# (the binary against itself), so that "differ" can be told from "not reproducible".
#     bash g6_png.sh <label>        -> logs/g6-png-<label>.log. About 3 minutes.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; SETTINGS=${SETTINGS:-H}; D=$LOGS/g6-png-$label; mkdir -p "$D"
header "$LOGS/g6-png-$label.log" "G-6 E-519 the PNGs of the plot's and the report's binaries against a session's (cmp)" $SETTINGS
for s in $SETTINGS; do check $s; E=$(envfor $s "$IMPL/w134/env_demo" demo) || exit 1
  for app in plot report; do
    pk=""; args="out.png"; [ $app = report ] && args="sensors.csv out.png"
    NAME=$s-png-$app JULIA_TREE=$(realpath --relative-to="$R" "$(jtree $s)") TW=$(realpath --relative-to="$R" "$(tree $s TW)") \
      DEPOT=$(depot $s) LOGDIR=$D OUTDIR=$D/out bash "$IMPL/w166/build_c.sh" $app "$E" > "$D/$s-$app.stdout" 2>&1
    f=$D/w166c-$s-png-$app.build.log
    echo "$s $app | $(grep -h '^from source' "$f" | head -1) | $(python3 "$IMPL/w135/summarize.py" "$f" | head -1 | cut -c1-200) | $(grep -h '^link:' "$f" | tail -1) | load $(load)" >> "$LOG"
    bin="$D/out/w166c-$s-png-$app"; [ -x "$bin" ] || { echo "  no binary" >> "$LOG"; continue; }
    for d in ses bin bin2; do rm -rf "$D/$app-$d"; mkdir -p "$D/$app-$d"; [ $app = report ] && cp "$R/TraitReport/data/sensors.csv" "$D/$app-$d/"; done
    (cd "$D/$app-ses" && VERIFY=0 TO=600 jl $s --project="$E" -e 'include(ARGS[1]); exit(main(ARGS[2:end]))' "$IMPL/w135/apps/$app.jl" $args > ses.out 2>&1); ses=$?
    (cd "$D/$app-bin" && timeout 120 "$bin" $args > bin.out 2>&1); b1=$?
    (cd "$D/$app-bin2" && timeout 120 "$bin" $args > bin.out 2>&1); b2=$?
    echo "  session exit $ses, binary exits $b1 $b2 | stdout equal: $(cmp -s "$D/$app-ses/ses.out" "$D/$app-bin/bin.out" && echo yes || echo no)" >> "$LOG"
    for p in ses bin bin2; do echo "  out.png ($p): $(stat -c %s "$D/$app-$p/out.png" 2>/dev/null || echo missing) bytes, sha256 $(sha256sum "$D/$app-$p/out.png" 2>/dev/null | cut -c1-16)" >> "$LOG"; done
    echo "  PNG binary against session: $(cmp -s "$D/$app-ses/out.png" "$D/$app-bin/out.png" && echo IDENTICAL || echo DIFFER) | binary against binary: $(cmp -s "$D/$app-bin/out.png" "$D/$app-bin2/out.png" && echo identical || echo differ) | first differing byte: $(cmp "$D/$app-ses/out.png" "$D/$app-bin/out.png" 2>&1 | head -1 | cut -c1-120)" >> "$LOG"
    rm -f "$bin"
  done; done
footer
