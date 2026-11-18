#!/bin/bash
# W-156 (traits T-128): the census of the attribute's surface in the demonstrators. Every use, with file and
# line, in three kinds:
#   surface  a name of the attribute's surface: the casts `with_dynamic` and Julia's `compiled_for` imported
#            from the library, `keep`, `Kept`, `kept_call`, `isdynamic`, the module options `first_seen` and
#            `dynamic`, `@default_compiled`, the `detect_` functions, `attributed_call`, `Core.compiled_for`;
#   cast     `compiled_for(` in code of a file that does not bind the library's `compiled_for`, the wrapper's
#            function (`using TraitWorld` or `import TraitWorld`, with the name or without an import list; a test
#            file: its directory's `runtests.jl` binds it; a file under a package's `src/`: a file at its top binds it); a line of prose (a comment, a docstring in backticks)
#            is not listed here. (Before the library's export was the wrapper's function, traits T-126, the
#            binding was `using TraitWorld.ByType: compiled_for`: a `ByType` line is now `surface`.)
#   prose    a comment, docstring or README line that describes the attribute: a cast, a value kept
#            "with its attribute".
#     bash census.sh [output]        (default: stdout); from any directory
set -u
R=$(cd "$(dirname "$0")/../../.." && pwd)
out=${1:-/dev/stdout}
SURF='with_dynamic|\bkeep\(|^\s*(using|import)\b.*\bkeep\b|\bKept\{|\bKept\b\s*[,)]|::\s*Kept\b|kept_call|kept_interpolant|\bisdynamic\b|first_seen|@trait_module.*\bdynamic\b|@default_compiled|detect_unused_casts|detect_kept_storage|detect_dynamic_fallbacks|attributed_call|Core\.compiled_for|ByType'
PROSE='\bcast(s|ing|ed)?\b|with (its|their) attributes?\b|(^|[^a-z])attribute (\((traits|`sol)|is a choice)|carried attribute'
census() {   # repo, then its directories and files
  local repo=$1; shift
  ( cd "$R/$repo" || exit
    files=$(git ls-files -- "$@" 2>/dev/null | grep -E '\.(jl|md|sh)$' | grep -v -E '(^|/)HISTORY\.md$')
    for f in $files; do
      grep -nE "$SURF" "$f" | sed "s|^|$repo/$f:|; s|^\([^:]*:[0-9]*\):|surface \1: |"
      bound=0
      # (also a REPL session's entry in a string: `"using …, TraitWorld, …"`)
      binds() { grep -qsE '^\s*(using|import)\s+([A-Za-z]+\s*,\s*)*TraitWorld\s*(,|$)|^\s*(using|import)\s+TraitWorld\s*:.*\bcompiled_for\b|"(using|import)\s+([A-Za-z]+\s*,\s*)*TraitWorld\s*[,;"]' "$1"; }
      binds "$f" && bound=1
      case $f in */test/*|test/*) d=$(dirname "$f"); binds "$d/runtests.jl" && bound=1 ;; esac
      # a file a package's module includes: the module's files at the top of its `src/` bind it
      case $f in src/*) sd=src ;; */src/*) sd=${f%%/src/*}/src ;; *) sd= ;; esac
      if [ -n "$sd" ] && [ $bound = 0 ]; then for g in "$sd"/*.jl; do binds "$g" && { bound=1; break; }; done; fi
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
for t in TraitTables TraitCSV TraitReport TraitMakie TraitDifferentialEquations forks ndport ndport/pkgs/NetworkDynamics-unified; do
  echo "# $t $(git -C "$R/$t" rev-parse --abbrev-ref HEAD) $(git -C "$R/$t" log -1 --format=%h)"
done
census TraitTables src test scripts examples README.md
census TraitCSV src ext test scripts examples README.md
census TraitReport src scripts README.md
census TraitMakie src test scripts compat README.md
census forks Tables/src Tables/test Tables/ext CSV/src CSV/test CSV/ext DataFrames/src DataFrames/test DataFrames/ext scripts README.md
census TraitDifferentialEquations src lib test scripts examples README.md
census ndport README.md
census ndport/pkgs/NetworkDynamics-unified src test README.md
} > "$out"
