#!/bin/bash
# E-289: the unified build against the earlier build's final state, on the same host (the shared host).
#     bash run.sh <part> [runs=3]
# Parts (each a discarded warm-up, then <runs> fresh processes, one job at a time, niced):
#   f-early | f-unified   the goal's task, TraitReport's form (f) (scripts/report_forks.jl): the forks' CSV.read into a
#                         DataFrame, a summary, TraitMakie's histogram; TraitReport/env_f or TraitReport-unified/env_fu
#   forks-early | forks-unified   the forks' REPL session (forks*/scripts/measure_session.sh, config fk-patched)
#   d-early | d-unified   the TDE + TraitMakie session, setting D (experiments/ttfx/workload_d.jl, WL_D=trait);
#                         experiments/ttfx/env_d or env_d_unified/ here
#   py-app                Python's form (pandas + matplotlib, experiments/interfaces/python/app.py)
# PYENV: a Python with pandas 3.0.6 and matplotlib 3.11.2. Logs: logs/<part>.log.
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"
label=$1; runs=${2:-3}; part=${label%%-w[0-9]*}   # a label is a part with an optional suffix -w<n> (E-292: -w123)
EARLY=$R/julia-1.13/julia; UNI=$R/julia-unified/julia
PYENV=${PYENV:?set PYENV}
CSV=$R/experiments/interfaces/App/data/sample.csv
OUT=$H/out; mkdir -p "$OUT" "$H/logs"; export MPLCONFIGDIR=$OUT/mpl JULIA_PKG_OFFLINE=true
export JULIA_LOCK=$H/.lock JULIA_GATE=$H/.gate
LOG=$H/logs/$label.log
rev() { git -C "$R/$1" log -1 --format=%h; }
bin() { [ -x "$R/$1/julia" ] && "$R/$1/julia" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)' 2>/dev/null || echo "?"; }   # the binary's own commit, * if built from a dirty tree
{ echo "# E-289 $label $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-1.13 $(rev julia-1.13) TraitWorld $(rev TraitWorld) TraitReport $(rev TraitReport) forks $(rev forks) TDE $(rev TraitDifferentialEquations) TraitMakie $(rev TraitMakie) | unified $(rev julia-unified) (binary $(bin julia-unified)) TraitWorld-unified $(rev TraitWorld-unified) TraitReport-unified $(rev TraitReport-unified) forks-unified $(rev forks-unified) TDE-unified $(rev TraitDifferentialEquations-unified) TraitMakie-unified $(rev TraitMakie-unified)"; } > "$LOG"

phases() {   # marks "T t1 t2 ..." -> startup, the steps, exit, wall (as TraitReport's measure.sh)
    awk -v s="$1" -v e="$2" -v names="$3" '/^T / {
        n = split(names, nm, " ")
        printf "startup %.3f", $2 - s
        for (i = 3; i <= NF; i++) printf " | %s %.3f", nm[i-2], $i - $(i-1)
        printf " | exit %.3f | wall %.3f\n", e - $NF, e - s }'
}
report() {   # julia dir env -- one form (f) process
    local J=$1 dir=$2 env=$3 s e p
    cd "$R/$dir"
    for i in w $(seq "$runs"); do
        s=$(date +%s.%N)
        p=$(nice -n 10 "$J" --startup-file=no --project=$env scripts/report_forks.jl "$CSV" "$OUT/f-$part.png" 2>&1 >"$OUT/f-$part.txt")
        e=$(date +%s.%N)
        echo "$i | load $(cut -d' ' -f1 /proc/loadavg) | $(echo "$p" | phases "$s" "$e" "imports read summarize plot+PNG")" >> "$LOG"
        echo "$p" | grep -v '^T ' | head -3 >> "$LOG"
    done
}
dsession() {   # julia env [script] -- setting D, timed from before exec to exit
    local J=$1 env=$2 script=${3:-workload_d.jl}
    cd "$R/experiments/ttfx"
    for i in w $(seq "$runs"); do
        f=$OUT/d-$label-$i.log
        { echo "W $(date +%s.%N)"
          WL_D=trait WL_SHAPE=matched WL_ORDER=A WL_SPEC=auto JULIA_NUM_THREADS=1 nice -n 10 timeout 600 \
              "$J" --startup-file=no --compiled-modules=existing --pkgimages=existing --project=$env $script "$OUT/png-$part" 2>&1
          echo "rc=$?"; echo "E $(date +%s.%N)"; } > "$f"
        echo "$i | load $(cut -d' ' -f1 /proc/loadavg) | $(python3 -I summarize.py "$f" | cut -d'|' -f2-)" >> "$LOG"
        grep -E '^(D|P) ' "$f" | md5sum | sed 's/^/results digest /' >> "$LOG"
    done
}
mkdir -p "$OUT/png-$part"
case $part in
    f-early)   report "$EARLY" TraitReport env_f ;;
    f-unified) report "$UNI" TraitReport-unified env_fu ;;
    forks-early)   (cd "$R/forks" && PATCHED=$EARLY PYENV=$PYENV bash scripts/measure_session.sh "$runs" "fk-patched") >> "$LOG" 2>&1 ;;
    forks-unified) (cd "$R/forks-unified" && PATCHED=$UNI PYENV=$PYENV bash scripts/measure_session.sh "$runs" "fk-patched") >> "$LOG" 2>&1 ;;
    forks-py)      (cd "$R/forks" && PYENV=$PYENV bash scripts/measure_session.sh "$runs" "py") >> "$LOG" 2>&1 ;;
    d-early)   dsession "$EARLY" env_d ;;
    d-unified) dsession "$UNI" "$H/env_d_unified" ;;
    dprobe-unified) dsession "$UNI" "$H/env_d_unified" "$H/probe_c54.jl" ;;   # E-293: problems at Dynamic, past C-54
    t-unified)     (cd "$R/TraitReport-unified" && JULIAS=$UNI PYENV=$PYENV bash scripts/measure.sh "$runs" "t") >> "$LOG" 2>&1 ;;
    py-app)
        for i in w $(seq "$runs"); do
            s=$(date +%s.%N); p=$("$PYENV/bin/python" "$R/experiments/interfaces/python/app.py" "$CSV" "$OUT/py.png" 2>&1 >/dev/null); e=$(date +%s.%N)
            echo "$i | $p | wall $(echo "$e - $s" | bc)" >> "$LOG"
        done ;;
    *) echo "unknown part $part"; exit 2 ;;
esac
echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
cat "$LOG"
