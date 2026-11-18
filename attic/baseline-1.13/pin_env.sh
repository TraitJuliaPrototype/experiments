#!/bin/bash
# Copy an environment with its manifests (1.12 and 1.13), making path sources absolute and pointing TraitWorld at a
# fixed snapshot, so that measurements do not follow a TraitWorld working tree that is being edited.
#   git -C TraitWorld archive <commit> --prefix=TraitWorld-<commit>/ | tar -x -C <dir>
#   pin_env.sh <env dir> <pinned env dir> <TraitWorld snapshot dir>
set -e
E=$(realpath "$1"); P=$2; TW=$(realpath "$3")
mkdir -p "$P"
for f in Project.toml Manifest.toml Manifest-v1.13.toml; do
  [ -f "$E/$f" ] || continue
  awk -v E="$E" -v TW="$TW" '
    {
      if (match($0, /path = "[^"]*"/)) {
        rel = substr($0, RSTART + 8, RLENGTH - 9)
        if (rel ~ /TraitWorld$/) abs = TW
        else { cmd = "realpath -m \"" E "/" rel "\""; cmd | getline abs; close(cmd) }
        $0 = substr($0, 1, RSTART - 1) "path = \"" abs "\"" substr($0, RSTART + RLENGTH)
      }
      print
    }' "$E/$f" > "$P/$f"
done
echo "pinned $E -> $P (TraitWorld: $TW)"
