#!/bin/bash
# E-291: a bare process, start to exit, on each build and in Python. A warm-up and $1 (5) runs each.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$R/env.sh"; runs=${1:-5}
PY=${PYENV:?set PYENV}/bin/python
LOG=$H/logs/floor.log
echo "# E-291 $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" > "$LOG"
one() {   # name, command...
    local name=$1; shift; local ts=""
    for i in w $(seq "$runs"); do
        s=$(date +%s.%N); nice -n 10 "$@" >/dev/null 2>&1; e=$(date +%s.%N)
        [ $i = w ] || ts="$ts $(echo "$e - $s" | bc | sed 's/^\./0./' | cut -c1-5)"
    done
    echo "$name:$ts" >> "$LOG"
}
one "stock 1.13.2" $HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia --startup-file=no -e nothing
one "vanilla v1.13.2 (built here)" $R/julia-vanilla/julia --startup-file=no -e nothing
one "earlier build julia-1.13" $R/julia-1.13/julia --startup-file=no -e nothing
one "unified build" $R/julia-unified/julia --startup-file=no -e nothing
one "python -c pass" $PY -c pass
one "python -c 'import pandas, matplotlib'" $PY -c "import pandas, matplotlib.pyplot"
echo "# done $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
cat "$LOG"
