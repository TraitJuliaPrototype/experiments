#!/bin/bash
# The gates on a built tree, one Julia process per gate, niced (gates/README.md).
# Usage, from anywhere (source env.sh first):
#     experiments/implementation/gates/run_all.sh <julia tree>              every gate in force, then every stage gate
#     experiments/implementation/gates/run_all.sh <julia tree> '<pattern>'  the gates in force matching it: 'm[12]_*', '[nf]*', 'n20_*'
# - A gate in force is a file `gates/*.jl` but `util.jl`. It runs with the stub library (`--project=experiments/implementation`),
#   or with the library where its header has the line `# project: TraitWorld`.
# - The stage gates are listed in `stage_gates.txt` beside this script. One marked `long` runs only with ALL=1.
# - A pattern that matches no gate in force is looked up in `not-in-force/` and `retired/` (scripts of earlier
#   experiments name such files); those are run as they are, and fail as the README says.
# - One line per gate: `PASS name`, or `FAIL name (exit n)` and the last lines of its output; then the tallies:
#   `gates: …` for the gates in force, and without a pattern `stage gates: …`. Exit status 1 if any failed.
# - LIB=<tree> (relative to the workspace root, or absolute) replaces `TraitWorld` as the library's tree.
R=${TW_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
T=$(cd "$R" && cd "$1" && pwd) || exit 2
P=${2:-}
U=$R/experiments/implementation
G=$U/gates
LIB=$(cd "$R" && cd "${LIB:-TraitWorld}" && pwd) || exit 2

project() {   # the project a gate runs with: stub, TraitWorld or none
  case $1 in
    stub) echo "--project=$U" ;;
    TraitWorld) echo "--project=$LIB" ;;
    none) echo "" ;;
    *) echo "unknown project '$1'" >&2; return 1 ;;
  esac
}

# run <name> <script> <project> [verdict]: one process; with `verdict`, the last line of output must hold ": OK"
run() {
  local name=$1 g=$2 proj out rc
  proj=$(project "$3") || return 1
  out=$(nice -n 10 "$T/julia" --startup-file=no $proj "$g" 2>&1 < /dev/null); rc=$?
  if [ $rc = 0 ] && [ "${4:-}" = verdict ] && ! echo "$out" | tail -1 | grep -q ': OK'; then rc=verdict; fi
  if [ $rc = 0 ]; then echo "PASS $name"; return 0; fi
  echo "FAIL $name (exit $rc)"; echo "$out" | tail -15 | sed 's/^/    /'; return 1
}
gate_project() { grep -q '^# project: TraitWorld' "$1" && echo TraitWorld || echo stub; }

failed=0
pass=0; fail=0
shopt -s nullglob
if [ -n "$P" ]; then
  files=()
  for g in $G/$P.jl; do [ -f "$g" ] && [ "$(basename "$g")" != util.jl ] && files+=("$g"); done
  if [ ${#files[@]} = 0 ]; then
    for g in $G/not-in-force/$P.jl $G/retired/$P.jl; do [ -f "$g" ] && files+=("$g"); done
    [ ${#files[@]} = 0 ] || echo "(not gates in force: ${files[*]#$G/})"
  fi
else
  files=()
  for g in $G/*.jl; do [ "$(basename "$g")" = util.jl ] || files+=("$g"); done
fi
for g in "${files[@]}"; do
  if run "$(basename "$g")" "$g" "$(gate_project "$g")"; then pass=$((pass+1)); else fail=$((fail+1)); fi
done
echo "gates: $pass passed, $fail failed"
[ $fail = 0 ] || failed=1

if [ -z "$P" ]; then
  pass=0; fail=0; skip=0
  while read -r path proj flags; do
    case $path in ''|'#'*) continue ;; esac
    if [[ " $flags " == *" long "* ]] && [ "${ALL:-0}" != 1 ]; then echo "SKIP $path (long; ALL=1 runs it)"; skip=$((skip+1)); continue; fi
    v=; [[ " $flags " == *" verdict "* ]] && v=verdict
    if run "$path" "$U/$path" "$proj" $v; then pass=$((pass+1)); else fail=$((fail+1)); fi
  done < "$G/stage_gates.txt"
  echo "stage gates: $pass passed, $fail failed, $skip skipped"
  [ $fail = 0 ] || failed=1
fi
exit $failed
