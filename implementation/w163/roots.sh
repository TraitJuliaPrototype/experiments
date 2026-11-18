#!/bin/bash
# W-163 (the pattern of open issue 189, widened from w155b/diag/roots.sh): every global that the changed
# runtime code annotates JL_GLOBALLY_ROOTED (an annotation for the static analyzer, which the stock
# collector does not read), with whether a root list names it. The earlier tool skipped a line with a
# parenthesis anywhere (so a declaration whose comment names a file, and every _Atomic(...) global);
# this one strips comments first and reads every C file of src/ the design changed.
#     bash roots.sh <julia tree> [base commit, default 45b6d15e34 = v1.13.2]
T=$(cd "${1:?julia tree}" && pwd); B=${2:-45b6d15e34}
files=$(git -C "$T" diff --name-only "$B" -- src | grep -E '\.(c|cpp)$')
for f in $files; do
  # declarations at file scope: no leading whitespace; comments removed; function prototypes (a "(" after
  # the name that is not _Atomic's) skipped
  sed -E 's://.*$::' "$T/$f" | grep -nE '^[A-Za-z_].*JL_GLOBALLY_ROOTED' | grep -v '^[0-9]*:extern' | while IFS= read -r line; do
    decl=$(echo "$line" | sed -E 's/_Atomic\(([^)]*)\)/\1/g')
    echo "$decl" | grep -qE '[A-Za-z_][A-Za-z0-9_]* *\(' && continue
    name=$(echo "$decl" | sed -E 's/^[0-9]+://; s/ *JL_GLOBALLY_ROOTED.*//; s/.*[ *]([A-Za-z_][A-Za-z0-9_]*)(\[[^]]*\])? *$/\1/')
    if grep -qw "$name" "$T/src/gc-stock.c"; then s="rooted (gc-stock.c)"
    elif grep -qw "$name" "$T/src/staticdata.c"; then s="in the image's lists (staticdata.c): rooted only while it points into an image"
    else s="NOT IN A ROOT LIST"; fi
    git -C "$T" diff "$B" -U0 -- "$f" | grep -qw "$name" && n="named in the diff" || n=vanilla
    echo "$s | $f: $name | $n"
  done
done | sort
# Part 2: file-scope pointers to Julia objects that the design added WITHOUT the annotation (the analyzer
# then treats them as unrooted, the collector does not see them): each needs a verdict by reading.
git -C "$T" diff "$B" -U0 -- $files | grep -E '^\+(static |JL_DLLEXPORT )*(_Atomic\()?jl_[a-z_]+_t ?\)? ?\*+ ?[A-Za-z_][A-Za-z0-9_]*( = [^;(]*)?;' |
  grep -v JL_GLOBALLY_ROOTED | sed -E 's/^\+/UNANNOTATED GLOBAL | /'
