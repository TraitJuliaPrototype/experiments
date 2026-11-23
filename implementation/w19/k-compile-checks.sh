#!/bin/bash
# W-19 seventh part: each commit given compiles its C runtime (make -C src, -j4, niced) and parses its changed Julia
# files (PARSE=0: not), in wt/w19-check. Usage: bash k-compile-checks.sh <log> <commit>...
cd /p/projects/coen/julia-trait-bound
source env.sh >/dev/null 2>&1
LOG=$1; shift; W=wt/w19-check
for c in "$@"; do
  git -C $W checkout -q --detach $c || { echo "$c: checkout failed" >> $LOG; continue; }
  s=$(date +%s)
  nice make -C $W/src -j4 > /tmp/claude-harvest/k-tmp/make-$c.log 2>&1; rc=$?
  files=$(git -C $W diff --name-only $c^ $c -- '*.jl' | sed "s|^|$W/|")
  p=$( [ "${PARSE:-1}" = 1 ] && [ -n "$files" ] && julia-next/julia --startup-file=no -e 'n=0; for f in ARGS; isfile(f) || continue; e = Meta.parseall(read(f, String); filename=f); any(x -> Meta.isexpr(x, (:error, :incomplete)), e.args) && (println("PARSE ERROR ", f); global n += 1); end; print(n == 0 ? "parsed" : "PARSE ERRORS")' $files || echo "no Julia files")
  echo "$c $(git -C $W log -1 --format=%s $c | cut -c1-60) | make -C src rc $rc ($(( $(date +%s) - s )) s) | $p" | tee -a $LOG
  [ $rc != 0 ] && tail -20 /tmp/claude-harvest/k-tmp/make-$c.log >> $LOG
done
