#!/bin/bash
# W-163: the checks of a fixed build, one job at a time (the brief's list).
#     bash checks.sh <julia tree> <label> [names...]   names: tutorial50 gates deep d11 library base examples
# Logs: logs/<label>-<name>.log; one line per check in logs/<label>-checks.log.
set -u
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
source "$H/env.sh" >/dev/null 2>&1
T=$(cd "$R" && cd "$1" && pwd); JB=$T/julia; L=$2; shift 2
U=$R/experiments/implementation; S=$H/logs/$L-checks.log
ulimit -c 0
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | $("$JB" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)') | TraitWorld $(git -C "$R/TraitWorld" log -1 --format=%h)"
for c in ${*:-tutorial50 gates deep d11 library base examples}; do
  s=$(date +%s); f=$H/logs/$L-$c.log
  case $c in
    tutorial50) bash "$H/repro.sh" "$JB" "$L-tutorial" 50 > "$f" 2>&1; note "tutorial x50 | $(tail -1 "$f") | $(( $(date +%s) - s )) s" ;;
    gates) for p in 'm[12]_*' '[nf]*'; do bash "$U/gates/run_all.sh" "$T" "$p"; done > "$f" 2>&1
           note "gates | $(grep '^gates:' "$f" | tr '\n' ' ') | failed: $(grep '^FAIL' "$f" | awk '{print $2}' | tr '\n' ' ')| $(( $(date +%s) - s )) s" ;;
    deep) nice -n 10 "$JB" --startup-file=no "$U/w155/gate_deep.jl" > "$f" 2>&1; note "gate_deep | exit $? | $(tail -1 "$f" | cut -c1-200) | $(( $(date +%s) - s )) s" ;;
    d11) nice -n 10 "$JB" --startup-file=no --project="$U/w161/env_lib" "$U/w155b/gate_d11.jl" > "$f" 2>&1; note "gate_d11 | exit $? | $(tail -1 "$f" | cut -c1-200) | $(( $(date +%s) - s )) s" ;;
    library) (cd "$R/TraitWorld" && nice -n 10 "$JB" --startup-file=no --project=. test/runtests.jl) > "$f" 2>&1; rc=$?
             note "library | exit $rc | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'Fail|Error' "$f" | head -3 | tr '\n' ' ' | cut -c1-200) | $(( $(date +%s) - s )) s" ;;
    base) nice -n 10 "$JB" --startup-file=no -e 'Base.runtests(["core","subtype","worlds"]; ncores=1)' > "$f" 2>&1; rc=$?
          note "Base core subtype worlds | exit $rc | $(grep -E 'SUCCESS|FAILURE' "$f" | tail -1) | $(( $(date +%s) - s )) s" ;;
    examples) for e in tutorial intro strict; do bash "$H/repro.sh" "$JB" "$L-ex-$e" 1 $e.jl | tail -1; done > "$f" 2>&1; note "examples | $(tr '\n' ' ' < "$f") | $(( $(date +%s) - s )) s" ;;
  esac
done
