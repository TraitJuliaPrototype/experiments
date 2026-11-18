#!/bin/bash
# W-156 (traits T-128): the census of the attribute's surface in the demonstrators. Every use, with file and
# line, in three kinds:
#   surface  a name of the attribute's surface: the casts `with_dynamic` and Julia's `compiled_for` imported
#            from the library, `keep`, `Kept`, `kept_call`, `isdynamic`, the module options `first_seen` and
#            `dynamic`, `@default_compiled`, the `detect_` functions, `attributed_call`, `Core.compiled_for`;
#   cast     `compiled_for(` in code of a file that does not bind the wrapper's function
#            (`using TraitWorld.ByType: compiled_for`; a test file: its directory's `runtests.jl` binds it);
#            a line of prose (a comment, a docstring in backticks) is not listed here;
#   prose    a comment, docstring or README line that describes the attribute: a cast, a value kept
#            "with its attribute".
#     bash census.sh [output]        (default: stdout); from any directory
set -u
R=$(cd "$(dirname "$0")/../../.." && pwd)
out=${1:-/dev/stdout}
SURF='with_dynamic|\bkeep\(|^\s*(using|import)\b.*\bkeep\b|\bKept\{|\bKept\b\s*[,)]|::\s*Kept\b|kept_call|kept_interpolant|\bisdynamic\b|first_seen|@trait_module.*\bdynamic\b|@default_compiled|detect_unused_casts|detect_kept_storage|detect_dynamic_fallbacks|attributed_call|Core\.compiled_for|^\s*(using|import)\s+TraitWorld\s*:.*\bcompiled_for\b'
PROSE='\bcast(s|ing|ed)?\b|with (its|their) attributes?\b|(^|[^a-z])attribute (\((traits|`sol)|is a choice)|carried attribute'
census() {   # repo, then its directories and files
  local repo=$1; shift
  ( cd "$R/$repo" || exit
    files=$(git ls-files -- "$@" 2>/dev/null | grep -E '\.(jl|md|sh)$' | grep -v -E '(^|/)HISTORY\.md$')
    for f in $files; do
      grep -nE "$SURF" "$f" | sed "s|^|$repo/$f:|; s|^\([^:]*:[0-9]*\):|surface \1: |"
      bound=0
      grep -q 'ByType: compiled_for' "$f" && bound=1
      case $f in */test/*|test/*) d=$(dirname "$f"); grep -qs 'ByType: compiled_for' "$d/runtests.jl" && bound=1 ;; esac
      if [ $bound = 0 ]; then
        # code lines: not a comment, and the name not inside backticks (a docstring's or a README's prose)
        grep -nE '\bcompiled_for\(' "$f" | grep -vE "$SURF" | grep -vE '^[0-9]+:\s*#' | grep -vE '`[^`]*compiled_for[^`]*`' |
          case $f in *.md) cat > /dev/null ;; *) sed "s|^|cast    $repo/$f:|; s|^\(cast    [^:]*:[0-9]*\):|\1: |" ;; esac
      fi
      case $f in
        *.md) grep -nE "$PROSE" "$f" ;;
        *)    grep -nE "$PROSE" "$f" | grep -E '^[0-9]+:\s*#|^[0-9]+:[^"]*$|`' ;;
      esac | grep -vE "$SURF" | sed "s|^|prose   $repo/$f:|; s|^\(prose   [^:]*:[0-9]*\):|\1: |"
    done ) | cut -c1-260
}
{
echo "# W-156 census $(date -Is): the attribute's surface in the demonstrators (census.sh)"
for t in TraitTables TraitCSV TraitReport TraitMakie TraitDifferentialEquations forks; do
  echo "# $t $(git -C "$R/$t" rev-parse --abbrev-ref HEAD) $(git -C "$R/$t" log -1 --format=%h)"
done
census TraitTables src test scripts examples README.md
census TraitCSV src ext test scripts examples README.md
census TraitReport src scripts README.md
census TraitMakie src test scripts compat README.md
census forks Tables/src Tables/test Tables/ext CSV/src CSV/test CSV/ext DataFrames/src DataFrames/test DataFrames/ext scripts README.md
census TraitDifferentialEquations src lib test scripts examples README.md
} > "$out"
