# W-167: W-159's drivers' library (../../w159/lib.sh) with a setting of its own, G: the head (H) with the library at
# W-167's worktree. Sourced by the drivers in rows/ and by prepare.sh here; nothing here runs a measurement.
#   G  julia-next, TraitWorld at wt/w158g-tw (branch w167), every other tree as H's.
# What differs from w159/lib.sh:
#   - the environments are made under w167/envs/<S>/ (never w159/envs/, which the round's own drivers rewrite);
#   - G's depot is .julia-depot/agent-depots/w167/G, stacked before the round's H depot (read only: the images of
#     packages that do not depend on the library) and the shared depot. H, B, V keep the round's depots, read only
#     here: preflight stops a row before a cell could write into them;
#   - logs under w167/logs/.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../w159" && pwd)/lib.sh"
W167=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LOGS=${W167_LOGS:-$W167/logs}; mkdir -p "$LOGS"
: "${G_JULIA:=$H_JULIA}" "${G_TW:=wt/w158g-tw}" "${G_TDE:=$H_TDE}" "${G_TM:=$H_TM}" "${G_TT:=$H_TT}" "${G_TC:=$H_TC}"
: "${G_TR:=$H_TR}" "${G_FORKS:=$H_FORKS}" "${G_ND:=$H_ND}"
depot() { case $1 in G) echo "$R/.julia-depot/agent-depots/w167/G" ;; *) echo "$W159_DEPOTS/$1" ;; esac; }
jl() { local s=$1 stack; shift; mkdir -p "$(depot "$s")"; stack=$(depot "$s")
  [ "$s" = G ] && stack="$stack:$W159_DEPOTS/H"
  env JULIA_DEPOT_PATH="${XDEPOT:+$XDEPOT:}$stack:$R/.julia-depot:" nice -n 10 timeout -s KILL "${TO:-1800}" "$(jbin "$s")" \
    --startup-file=no --history-file=no -t 1 "$@"; }
envfor() { local s=$1 src=$2 name=$3 dst="$W167/envs/$1/$3" pairs=() k
  for k in $KEYS; do pairs+=("$R/${SRC[$k]}=$(tree "$s" "$k")"); done
  case $s in H|G) pairs+=("$IMPL/w134/pkgs-facts=$W159/pkgs-facts-head") ;; esac
  python3 "$W159/mkenv.py" "$src" "$dst" "${pairs[@]}" >&2 || die "environment $name for setting $s: a tree is missing"
  echo "$dst"; }
