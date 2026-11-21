#!/bin/bash
# W-156: the annotations per demonstrator at a revision (code lines of .jl files under the demonstrator's code
# directories; comment lines and lines that name a form in backticks, a docstring's prose, left out; a line counts
# once per kind):
#   casts     Julia's casts: `compiled_for(` in a file that does not bind the wrapper's function, `with_dynamic(`,
#             `keep(`, `Kept{`, `kept_call(`
#   options   `@trait_module` lines that write `first_seen` or `dynamic`
#   boxes     `Dynamic{…}` written
#   wrappers  `compiled_for(` in a file that binds the wrapper's function (its test directory's runtests.jl for a
#             test file), `Compiled(`
#   default   `@default_dynamic`
#   unwrap    `unwrap(`
#     bash counts.sh <rev>       e.g. unified, w156
# WRAPPER=all: at a revision where the library's exported `compiled_for` is the wrapper and Julia has no cast (the
# head after traits T-126 and compiler C-112), every `compiled_for(` counts as a wrapper (W-159; default as before)
set -u
R=$(cd "$(dirname "$0")/../../.." && pwd)
rev=$1
count() {   # repo, dirs...
  local repo=$1; shift
  ( cd "$R/$repo"
    c=0; o=0; b=0; w=0; d=0; u=0
    for f in $(git ls-tree -r --name-only "$rev" -- "$@" | grep '\.jl$'); do
      txt=$(git show "$rev:$f" | grep -vE '^\s*#' | grep -vE '`[^`]*(compiled_for|Dynamic\{|Compiled\(|unwrap\(|keep\(|with_dynamic)[^`]*`')
      bound=0
      echo "$txt" | grep -q 'ByType: compiled_for' && bound=1
      [ "${WRAPPER:-}" = all ] && bound=1
      case $f in */test/*|test/*) t=$(dirname "$f")/runtests.jl; git show "$rev:$t" 2>/dev/null | grep -q 'ByType: compiled_for' && bound=1 ;; esac
      n=$(echo "$txt" | grep -cE '\bcompiled_for\(' ); [ $bound = 1 ] && w=$((w + n)) || c=$((c + n))
      c=$((c + $(echo "$txt" | grep -cE 'with_dynamic\(|\bkeep\(|\bKept\{|kept_call\(')))
      o=$((o + $(echo "$txt" | grep -cE '@trait_module.*\b(first_seen|dynamic)\b')))
      b=$((b + $(echo "$txt" | grep -cE 'Dynamic\{')))
      w=$((w + $(echo "$txt" | grep -cE '\bCompiled\(')))
      d=$((d + $(echo "$txt" | grep -cE '@default_dynamic')))
      u=$((u + $(echo "$txt" | grep -cE '\bunwrap\(')))
    done
    printf "| %s | %d | %d | %d | %d | %d | %d |\n" "$repo" $c $o $b $w $d $u )
}
echo "# W-156 annotations at $rev (counts.sh): code lines of .jl files, comment lines left out"
echo "| demonstrator | casts | module options | boxes | wrappers | @default_dynamic | unwrap |"
echo "|---|---|---|---|---|---|---|"
count TraitTables src test
count TraitCSV src ext test
count TraitReport src scripts
count TraitMakie src test scripts compat
count forks Tables/src Tables/test Tables/ext CSV/src CSV/test CSV/ext DataFrames/src DataFrames/test DataFrames/ext scripts
count TraitDifferentialEquations src lib test scripts examples
