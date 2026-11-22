# W-169 (E-536): what every script of the profiling round shares. `source lib.sh`; nothing here measures.
# It takes W-159's lib.sh (settings H, V; check, header, preflight, rev, load) and changes three things:
#   - logs go to w169/logs, environments to w169/envs (ignored by git): nothing is written under w159/;
#   - the depots: H is the head after the freeze (julia `next` 683ea4fc16, TraitWorld `unified` at its HEAD), whose
#     images the round's H depot does not hold (the head moved): H writes its images into
#     agent-depots/w169/H, stacked before the shared depot. V (vanilla v1.13.2) reads the round's V depot (its images
#     are valid: vanilla did not move) behind agent-depots/w169/V, where anything new would be written;
#   - jl: niced, one thread, `ulimit -c 0`, a time limit.
W169=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export W159_LOGS=$W169/logs
source "$W169/../w159/lib.sh"
ulimit -c 0
MYDEPOTS=$R/.julia-depot/agent-depots/w169
mydepot() { echo "$MYDEPOTS/$1"; }
jdepots() { case $1 in V) echo "$(mydepot V):$(depot V):$R/.julia-depot:" ;; *) echo "$(mydepot "$1"):$R/.julia-depot:" ;; esac; }
jl() { local s=$1; shift; mkdir -p "$(mydepot "$s")"
  env JULIA_DEPOT_PATH="$(jdepots "$s")" nice -n 10 timeout -s KILL "${TO:-1800}" "$(jbin "$s")" \
    --startup-file=no --history-file=no -t 1 "$@"; }
envfor() { local s=$1 src=$2 name=$3 dst="$W169/envs/$1/$3" pairs=() k
  for k in $KEYS; do pairs+=("$R/${SRC[$k]}=$(tree "$s" "$k")"); done
  [ "$s" = H ] && pairs+=("$IMPL/w134/pkgs-facts=$IMPL/w159/pkgs-facts-head")
  python3 "$IMPL/w159/mkenv.py" "$src" "$dst" "${pairs[@]}" >&2 || die "environment $name for setting $s: a tree is missing"
  echo "$dst"; }
# the environment of a session: the harness's own (W-134's, ndport's) for the setting
envof() { case $2 in
    up|facts|forks|demo) envfor "$1" "$IMPL/w134/env_$2" "$2" ;;
    nd) envfor "$1" "$R/ndport/env_unified_r5" nd ;;
    *) die "environment $2" ;; esac; }
