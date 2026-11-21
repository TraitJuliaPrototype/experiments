# W-159: what every driver of the round shares. `source lib.sh` from a driver; nothing here runs a measurement.
#
# Settings. Each has its Julia tree, its library and demonstrator trees, and a depot of its own stacked before the
# shared one (compiled caches are written there, so one setting never evicts another's; packages come from the
# shared depot). A tree is a path below the workspace or absolute; override any by its variable.
#   H  the head: the freeze after W-158's merge (julia-next rebuilt, TraitWorld `unified`, the demonstrators'
#      `unified`). For a smoke run before the merge: H_TW=wt/w158b-tw (TraitWorld unified 81c04c3).
#   B  the tag `prototype-2026-11`, the regression control: julia-unified, TraitWorld-base, and worktrees of the
#      demonstrators at the tag (wt/w161-tde-base, wt/w160-tm, wt/w151-base/NetworkDynamics exist;
#      the others are made by trees.sh under wt/w159-tag/).
#   V  vanilla v1.13.2, the plain baseline: no trait tree (an environment that names one is refused).
# Rules every driver keeps (the playbook §4):
#   - the binary must be built from its tree's HEAD, and no tree may hold uncommitted changes (ALLOW_DIRTY=1, and
#     ALLOW_BINARY_MISMATCH="<settings>" to go on: the log then says so). The tag's julia-unified names 8fccf1e182*:
#     it was built before its last commit 7b374f39ce (Compiler/src/bootstrap.jl, 27 lines) was made;
#   - before the cells, `preflight` checks that every package a cell loads has a valid image for the setting;
#     a cell whose output says "Precompiling" fails the row (an image was stale or missing);
#   - fresh processes, one at a time, niced, one thread; /proc/loadavg before and after each cell and the row;
#   - logs under w159/logs/, with every tree's commit in the header.
set -uo pipefail
W159=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
R=$(cd "$W159/../../.." && pwd)
source "$R/env.sh" >/dev/null 2>&1
IMPL=$R/experiments/implementation
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_GC_AUTO=false
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT JULIA_LOAD_PATH
W159_DEPOTS=${W159_DEPOTS:-$R/.julia-depot/agent-depots/w159}
LOGS=${W159_LOGS:-$W159/logs}; mkdir -p "$LOGS"

: "${H_JULIA:=julia-next}" "${H_TW:=TraitWorld}" "${H_TDE:=TraitDifferentialEquations}" "${H_TM:=TraitMakie}"
: "${H_TT:=TraitTables}" "${H_TC:=TraitCSV}" "${H_TR:=TraitReport}" "${H_FORKS:=forks}"
: "${H_ND:=ndport/pkgs/NetworkDynamics-unified}"
: "${B_JULIA:=julia-unified}" "${B_TW:=TraitWorld-base}" "${B_TDE:=wt/w161-tde-base}" "${B_TM:=wt/w160-tm}"
: "${B_TT:=wt/w159-tag/TraitTables}" "${B_TC:=wt/w159-tag/TraitCSV}" "${B_TR:=wt/w159-tag/TraitReport}"
: "${B_FORKS:=wt/w159-tag/forks}" "${B_ND:=wt/w151-base/NetworkDynamics}"
: "${V_JULIA:=julia-vanilla}"
KEYS="TW TDE TM TT TC TR FORKS ND"
# the tree each key stands for in the harnesses' environments (their manifests name these paths)
declare -A SRC=([TW]=TraitWorld [TDE]=TraitDifferentialEquations [TM]=TraitMakie [TT]=TraitTables [TC]=TraitCSV
                [TR]=TraitReport [FORKS]=forks [ND]=ndport/pkgs/NetworkDynamics-unified)

die() { echo "W-159 FAIL: $*" >&2; [ -n "${LOG:-}" ] && echo "# FAIL: $*" >> "$LOG"; exit "${DIE_CODE:-1}"; }
abs() { case $1 in /*) echo "$1" ;; *) echo "$R/$1" ;; esac; }
jtree() { local v=${1}_JULIA; abs "${!v}"; }                          # jtree S
jbin() { echo "$(jtree "$1")/julia"; }                                # jbin S
tree() {                                                               # tree S KEY
  [ "$1" = V ] && { echo "/nonexistent/vanilla-has-no-$2"; return; }
  local v=${1}_$2; abs "${!v}"; }
depot() { echo "$W159_DEPOTS/$1"; }
rev() { [ -d "$1" ] || { echo "absent"; return; }
  echo "$(git -C "$1" rev-parse --short=10 HEAD 2>/dev/null)$([ -z "$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)" ] || echo '*')"; }
load() { cut -d' ' -f1-3 /proc/loadavg; }

# jl S <julia args...>: the setting's Julia, its depot (XDEPOT, if set, stacked first), niced, one thread, a time
# limit (TO, default 1800 s)
jl() { local s=$1; shift; mkdir -p "$(depot "$s")"
  env JULIA_DEPOT_PATH="${XDEPOT:+$XDEPOT:}$(depot "$s"):$R/.julia-depot:" nice -n 10 timeout -s KILL "${TO:-1800}" "$(jbin "$s")" \
    --startup-file=no --history-file=no -t 1 "$@"; }

# envfor S <source env dir> <name>: the harness's environment with the setting's trees -> prints its path
envfor() { local s=$1 src=$2 name=$3 dst="$W159/envs/$1/$3" pairs=() k
  for k in $KEYS; do pairs+=("$R/${SRC[$k]}=$(tree "$s" "$k")"); done
  python3 "$W159/mkenv.py" "$src" "$dst" "${pairs[@]}" >&2 || die "environment $name for setting $s: a tree is missing (trees.sh)"
  echo "$dst"; }

# check S: the binary is built from its tree's HEAD; the setting's trees hold no uncommitted change
check() { local s=$1 jt b h k t
  jt=$(jtree "$s"); [ -x "$jt/julia" ] || die "setting $s: no Julia at $jt"
  b=$("$jt/julia" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)' 2>/dev/null)
  h=$(git -C "$jt" rev-parse --short=10 HEAD)
  local bc=${b%\*}
  case "$h" in "$bc"*) ;; *)
    case " ${ALLOW_BINARY_MISMATCH:-} " in *" $s "*)
      echo "# NOTE setting $s: the binary names $b, the tree's HEAD is $h (allowed by ALLOW_BINARY_MISMATCH)" >> "${LOG:-/dev/null}" ;;
      *) die "setting $s: the binary names $b, the tree's HEAD is $h (commit, then build; ALLOW_BINARY_MISMATCH=\"$s\" to go on)" ;; esac ;; esac
  [ "$b" != "$bc" ] && echo "# NOTE setting $s: the binary is marked '*' (its tree had a tracked change when it was built); the tree is clean now" >> "${LOG:-/dev/null}"
  [ -z "$(git -C "$jt" status --porcelain --untracked-files=no -- base src Compiler stdlib 2>/dev/null)" ] ||
    [ "${ALLOW_DIRTY:-0}" = 1 ] || die "setting $s: $jt has uncommitted changes"
  [ "$s" = V ] && return 0
  for k in $KEYS; do t=$(tree "$s" "$k"); [ -d "$t" ] || continue
    [ -z "$(git -C "$t" status --porcelain --untracked-files=no 2>/dev/null)" ] || [ "${ALLOW_DIRTY:-0}" = 1 ] ||
      die "setting $s: $t has uncommitted changes"; done; }

# header LOG ROW S...: the row, the date, the load, and per setting every tree's commit, the depot
header() { local log=$1 row=$2 s k; shift 2; LOG=$log
  { echo "# W-159 $row | $(date -Is) | load-before $(load) | $(hostname -s)"
    for s in "$@"; do
      printf '# setting %s: julia %s %s (binary %s)' "$s" "$(basename "$(jtree "$s")")" "$(rev "$(jtree "$s")")" \
        "$("$(jbin "$s")" --startup-file=no -e 'print(Base.GIT_VERSION_INFO.commit_short)' 2>/dev/null)"
      if [ "$s" != V ]; then for k in $KEYS; do printf ' | %s %s %s' "$k" "$(tree "$s" "$k" | sed "s|^$R/||")" "$(rev "$(tree "$s" "$k")")"; done; fi
      printf ' | depot %s\n' "$(depot "$s" | sed "s|^$R/||")"
    done
    echo "# experiments $(rev "$R/experiments") | product setting, strict mode off, one thread, fresh process per cell${ALLOW_DIRTY:+ | ALLOW_DIRTY}${ALLOW_BINARY_MISMATCH:+ | ALLOW_BINARY_MISMATCH=$ALLOW_BINARY_MISMATCH}"
  } > "$log"; }
footer() { echo "# done $(date -Is) | load-after $(load)" >> "$LOG"; }

# preflight S ENV PKG...: every package has a valid image for the setting (else the row stops: run prepare.sh)
preflight() { local s=$1 env=$2 out; shift 2
  out=$(jl "$s" --project="$env" -e '
    bad = String[]
    for p in ARGS
        id = Base.identify_package(p)
        id === nothing && (push!(bad, p * " (not in the environment)"); continue)
        Base.isprecompiled(id) || push!(bad, p)
    end
    isempty(bad) || (println("STALE OR MISSING IMAGE: ", join(bad, ", ")); exit(1))
    println("images ok: ", join(ARGS, " "))' "$@" 2>&1); local rc=$?
  echo "# preflight $s $(basename "$env"): $out" >> "$LOG"
  [ $rc = 0 ] || die "preflight $s $(basename "$env"): $out (run prepare.sh $s)"; }

# cell LABEL <command...>: one fresh process; its output (CUT columns, HEAD lines) into the log; a run that
# precompiled fails the row
cell() { local label=$1 tmp rc; shift; tmp=$(mktemp)
  echo "== $label | load $(load)" >> "$LOG"
  "$@" > "$tmp" 2>&1; rc=$?
  grep -v '^ *$' "$tmp" | cut -c1-"${CUT:-1500}" | head -"${HEAD:-80}" >> "$LOG"
  echo "-- rc $rc | load $(load)" >> "$LOG"
  if [ "${ALLOW_PRECOMPILE:-0}" != 1 ] && grep -q 'Precompiling' "$tmp"; then rm -f "$tmp"; die "cell $label precompiled: an image was stale or missing"; fi
  rm -f "$tmp"; return $rc; }
