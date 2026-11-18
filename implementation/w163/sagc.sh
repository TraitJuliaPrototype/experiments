#!/bin/bash
# W-163: Julia's static check of GC roots (the clang static analyzer with src/clangsa's GCChecker, as
# `make -C src clang-sagc-<file>` runs it) over the runtime files the design changed, in one tree.
#     bash sagc.sh <tool tree> <tree to check> <log> [files...]
# <tool tree>: a built tree with `make -C src install-analysis-deps clangsa` done (clang, the plugin, the
# dependencies' headers). <tree to check>: its src/ is read; it needs the generated files
# (julia_version.h, jl_internal_funcs.inc, jl_data_globals_defs.inc, julia_flisp.boot.inc) in src/: for a
# tree not built, copy them from a built tree of the same commit. Files: default every .c of src/ that
# the design changed (git diff 45b6d15e34), minus rtutils.c (Julia's Makefile skips it), gc-mmtk.c (not the stock collector) and the files other files include (iddict.c, idset.c, staticdata_utils.c, …: src/Makefile's INCLUDED_C_FILES). The .cpp files run with `make -C src analyzegc`.
# One line per finding in the log, then the notes; the summary at the end: "<file>: N findings".
set -u
TT=$(cd "$1" && pwd); CT=$(cd "$2" && pwd); LOG=$3; shift 3
FILES=${*:-$(git -C "$TT" diff --name-only 45b6d15e34 -- src | grep -E '^src/[^/]+\.c$' | sed 's|src/||' | grep -vE '^(rtutils|gc-mmtk|staticdata_utils|precompile_utils|iddict|idset|crc32c-tables|signals-[a-z]+|mach_excServer)\.c$')}
# the command make uses, for module.c, with the paths of the checked tree's src/
CMD=$(make -n -C "$TT/src" clang-sagc-module 2>/dev/null | grep -o "$TT/usr/tools/clang -D__clang_gcanalyzer__.*" | sed "s| -x c $TT/src/module.c||")
: > "$LOG"
for f in $FILES; do
  echo "### $f" >> "$LOG"
  # the checked tree's src first on the include path, then the tool tree's headers of the dependencies
  c=$(echo "$CMD" | sed "s|-I$TT/src|-I$CT/src|g")
  ex=""  # the per-file exceptions of src/Makefile (SA_EXCEPTIONS-<file>)
  [ "$f" = subtype.c ] && ex='-Xanalyzer -analyzer-config -Xanalyzer silence-checkers="core.uninitialized.Assign;core.UndefinedBinaryOperatorResult"'
  [ "$f" = jloptions.c ] && ex='-Xanalyzer -analyzer-config -Xanalyzer silence-checkers="core.NonNullParamChecker;unix.cstring.NullArg"'
  (cd "$CT/src" && eval nice -n 10 $c $ex -x c "$CT/src/$f") 2>&1 | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG"
done
# The check must have run: a compiler that could not start (no plugin, no clang, a missing generated file)
# prints an error that names no source line, and would otherwise read as "0 findings".
if grep -qE "^(error|fatal error): |unable to load plugin|No such file or directory" "$LOG"; then
  echo "## summary" >> "$LOG"; echo "THE CHECK DID NOT RUN for at least one file: see the errors above" | tee -a "$LOG" >&2
  exit 2
fi
echo "## summary" >> "$LOG"
awk '/^### /{f=$2} /: error: |: warning: /{n[f]++} END{for (k in n) print k": "n[k]" findings"}' "$LOG" | sort >> "$LOG"
echo "checked: $(grep -c '^### ' "$LOG") files; findings: $(grep -cE ': error: |: warning: ' "$LOG")" | tee -a "$LOG"
