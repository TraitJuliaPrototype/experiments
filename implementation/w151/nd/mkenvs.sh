#!/usr/bin/env bash
# W-151: the environments of the gate's NetworkDynamics runs (E-402), from ndport's env_unified_r5 (the workload) and
# env_unified (the test subset), with every path absolute:
#   env_head, env_test_head: the trees at their heads (TraitWorld, TraitDifferentialEquations,
#                            NetworkDynamics-unified);
#   env_base:                the baseline, the tag prototype-2026-11: TraitWorld-base, and worktrees of TDE and
#                            NetworkDynamics at the tag under wt/w151-base/ (ignored by the design repository).
# The other trees (TraitMakie, GraphMakie-unified, Graphs-unified, …) are at the tag in both.
set -euo pipefail
R=/p/projects/coen/julia-trait-bound; H=$(cd "$(dirname "$0")" && pwd); ND=$R/ndport
B=$R/wt/w151-base
mkdir -p $B
[ -d $B/NetworkDynamics ] || git -C $ND/pkgs/NetworkDynamics-unified worktree add --detach $B/NetworkDynamics prototype-2026-11
[ -d $B/TDE ] || git -C $R/TraitDifferentialEquations worktree add --detach $B/TDE prototype-2026-11
mk() {  # mk <source env> <target> <base:0|1>
  local src=$ND/$1 dst=$H/$2 base=$3
  mkdir -p $dst
  for f in Project.toml Manifest.toml; do
    python3 - "$src/$f" "$dst/$f" "$src" "$base" "$R" "$B" <<'PY'
import sys, os, re
src, dst, envdir, base, R, B = sys.argv[1:]
s = open(src).read()
def fix(m):
    p = os.path.normpath(os.path.join(envdir, m.group(2)))
    if base == "1":
        p = p.replace(R + "/TraitWorld-unified", R + "/TraitWorld-base")
        p = p.replace(R + "/TraitDifferentialEquations-unified", B + "/TDE")
        p = p.replace(R + "/ndport/pkgs/NetworkDynamics-unified", B + "/NetworkDynamics")
    return m.group(1) + p + '"'
s = re.sub(r'(path\s*=\s*")([^"]+)"', fix, s)
open(dst, "w").write(s)
PY
  done
}
mk env_unified_r5 env_head 0
mk env_unified_r5 env_base 1
mk env_unified env_test_head 0
grep -h 'path = ' $H/env_base/Project.toml
