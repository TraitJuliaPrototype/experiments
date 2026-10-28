#!/bin/bash
# A/B harness (W-85): the same probe against two states of a repository, each in fresh processes, side by side.
#
#     experiments/tools/ab/ab.sh <repo dir> <before ref> <env dir | -> <probe.jl> [runs, default 3]
#
# - "before" is a git worktree of <repo dir> at <before ref>, a sibling of the repository (<repo>-ab-<sha>),
#   so that packages' relative [sources] paths (../TraitWorld) resolve as in the repository; reused if present.
# - "after" is the repository's working tree, or with AFTER=<ref> a second worktree at that ref.
# - <env dir> is the environment the probe runs in; `-` makes one holding only the repository's own package.
#   Each side gets a copy of it (its Project.toml and Manifest.toml, every relative path made absolute; for
#   "before" the paths into the repository point at the worktree), in its own depot, stacked on ~/.julia, so
#   the two builds' caches neither evict each other nor ~/.julia's.
# - The probe prints `AB <name> key=value …` lines: `ABProbe.abmeasure` / `abreport`, included as
#   `include(joinpath(ENV["AB_TOOLS"], "ABProbe.jl"))`. AB_SIDE is `before` or `after` in the probe.
# - The runs alternate between the sides. One Julia job at a time through the shared lock; niced.
#
# Environment: JULIA (default the patched julia-1.13), AB_WORK (where the env copies, depots and results go;
# default $TMPDIR/ab), AFTER (a ref for the "after" side), AB_PROBE_ARGS (passed to the probe).
set -eu
[ $# -ge 4 ] || { sed -n '2,20p' "$0"; exit 2; }
REPO=$(cd "$1" && pwd); REF=$2; ENVARG=$3; PROBE=$(cd "$(dirname "$4")" && pwd)/$(basename "$4"); RUNS=${5:-3}
[ -f "$PROBE" ] || { echo "ab: no probe $4" >&2; exit 2; }
TOOLS=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$TOOLS/../../.." && pwd)
J=${JULIA:-$ROOT/julia-1.13/julia}
LOCK=/tmp/claude-1000/julia-review.lock
WORK=${AB_WORK:-${TMPDIR:-/tmp}/ab}

# the worktree of a ref, beside the repository; checked to be at that commit
worktree() {
    local sha=$1 wt="$REPO-ab-${1:0:9}"
    if [ -d "$wt" ]; then
        [ "$(git -C "$wt" rev-parse HEAD)" = "$sha" ] || { echo "ab: $wt exists at another commit" >&2; exit 1; }
    else
        git -C "$REPO" worktree add -q --detach "$wt" "$sha" >&2
    fi
    echo "$wt"
}
BSHA=$(git -C "$REPO" rev-parse --verify "$REF^{commit}")
WTB=$(worktree "$BSHA")
if [ -n "${AFTER:-}" ]; then
    ASHA=$(git -C "$REPO" rev-parse --verify "$AFTER^{commit}"); WTA=$(worktree "$ASHA"); ATAG=${ASHA:0:9}
else
    WTA=$REPO; ATAG="worktree"
    git -C "$REPO" diff --quiet HEAD -- || ATAG="worktree+changes"
fi
CMP="$WORK/$(basename "$REPO")-${BSHA:0:9}-vs-$ATAG"
mkdir -p "$CMP"

# the environment
if [ "$ENVARG" = "-" ]; then
    ENV0="$CMP/env0"; mkdir -p "$ENV0"
    python3 - "$REPO/Project.toml" "$ENV0/Project.toml" "$REPO" <<'PY'
import sys, re
src, dst, repo = sys.argv[1:]
s = open(src).read()
name = re.search(r'^name\s*=\s*"([^"]+)"', s, re.M).group(1)
uuid = re.search(r'^uuid\s*=\s*"([^"]+)"', s, re.M).group(1)
open(dst, "w").write(f'[deps]\n{name} = "{uuid}"\n\n[sources]\n{name} = {{path = "{repo}"}}\n')
PY
else
    ENV0=$(cd "$ENVARG" && pwd)
fi
# copy an environment, every relative path absolute; paths into the repository moved to <to>. An environment
# inside the repository is taken from <to>, as that side has it.
copyenv() {
    local dst=$1 to=$2 src=$ENV0
    case "$ENV0/" in "$REPO"/*) src="$to${ENV0#"$REPO"}" ;; esac
    rm -rf "$dst"; mkdir -p "$dst"
    for f in Project.toml Manifest.toml; do
        [ -f "$src/$f" ] || continue
        python3 - "$src/$f" "$dst/$f" "$src" "$REPO" "$to" <<'PY'
import sys, re, os
src, dst, envdir, repo, to = sys.argv[1:]
s = open(src).read()
def fix(m):
    a = os.path.normpath(os.path.join(envdir, m.group(2)))
    if a == repo or a.startswith(repo + os.sep):
        a = to + a[len(repo):]
    return m.group(1) + a + m.group(3)
open(dst, "w").write(re.sub(r'(path\s*=\s*")([^"]+)(")', fix, s))
PY
    done
}
copyenv "$CMP/env-after" "$WTA"
copyenv "$CMP/env-before" "$WTB"
mkdir -p "$CMP/depot-after" "$CMP/depot-before"
: > "$CMP/after.txt"; : > "$CMP/before.txt"

export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=${JULIA_NUM_PRECOMPILE_TASKS:-4} AB_TOOLS="$TOOLS"
jl() {  # side, args…
    local side=$1; shift
    JULIA_DEPOT_PATH="$CMP/depot-$side:$HOME/.julia:" AB_SIDE=$side \
        flock "$LOCK" nice -n 19 "$J" --startup-file=no --project="$CMP/env-$side" "$@"
}
for side in after before; do
    echo "ab: $side: resolving and precompiling ($CMP/$side-precompile.log)" >&2
    jl $side -e 'using Pkg; Pkg.resolve(); Pkg.precompile()' > "$CMP/$side-precompile.log" 2>&1 ||
        { echo "ab: $side: precompile failed, see $CMP/$side-precompile.log" >&2; tail -20 "$CMP/$side-precompile.log" >&2; exit 1; }
    jl $side -e 'using Pkg; Pkg.status()' > "$CMP/$side-status.txt" 2>&1 || true
done
for i in $(seq "$RUNS"); do
    for side in after before; do
        echo "ab: run $i, $side" >&2
        jl $side "$PROBE" ${AB_PROBE_ARGS:-} > "$CMP/$side-run$i.log" 2>&1 || echo "ab: $side run $i failed, see $CMP/$side-run$i.log" >&2
        grep '^AB ' "$CMP/$side-run$i.log" >> "$CMP/$side.txt" || true
    done
done
python3 - "$CMP/before.txt" "$CMP/after.txt" "$(basename "$REPO") ${BSHA:0:9} ($REF)" "$ATAG" "$RUNS" <<'PY' | tee "$CMP/result.txt"
import sys, collections
def load(f):
    d = collections.OrderedDict()
    for l in open(f):
        parts = l.split()
        if len(parts) < 2: continue
        kv = {}
        for x in parts[2:]:
            k, _, v = x.partition("=")
            try: kv[k] = float(v)
            except ValueError: pass
        d.setdefault(parts[1], []).append(kv)
    return d
b, a = load(sys.argv[1]), load(sys.argv[2])
print(f"A/B: before = {sys.argv[3]}, after = {sys.argv[4]}; {sys.argv[5]} processes per side; min–max over them; ratio of the minima")
fmt = lambda v: "-" if not v else (f"{min(v):.4g}" if min(v) == max(v) else f"{min(v):.4g}–{max(v):.4g}")
for name in dict.fromkeys(list(b) + list(a)):
    print(f"  {name}")
    keys = list(dict.fromkeys(k for r in b.get(name, []) + a.get(name, []) for k in r))
    for k in keys:
        rb = [r[k] for r in b.get(name, []) if k in r]; ra = [r[k] for r in a.get(name, []) if k in r]
        ratio = f"  x{min(ra) / min(rb):.2f}" if rb and ra and min(rb) > 0 else ""
        print(f"    {k:18s} before {fmt(rb):>17s}   after {fmt(ra):>17s}{ratio}")
PY
echo "ab: logs, environments and depots in $CMP" >&2
