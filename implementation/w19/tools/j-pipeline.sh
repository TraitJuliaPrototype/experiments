#!/bin/bash
# Make the part commits from the WIP trees: each tree with the fixups, committed on the one below.
set -e
cd /p/projects/coen/julia-trait-bound/wt/w19-patch
M=/tmp/claude-harvest/w19f/msg; C=/tmp/claude-harvest/w19f/cut
prev=98960887b3
for pair in T15:a978083b77 T11:bd6298c4e0 T12:f910815692 T13:2129d64245 T14:84a7bddbcb T17:ab2cf6464a S3:eb3904f025 T16:180f23e4cd; do
  part=${pair%%:*}; wip=${pair##*:}
  git checkout -q --detach $wip
  python3 $C/fixups.py
  case $part in T13|T14|T17|S3) python3 $C/fix_kind.py ;; esac
  case $part in T14|T17|S3) python3 - <<'PY'
import sys; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
s=rd('Compiler/src/abstractinterpretation.jl')
old="# a set or an intersection of sets, its parameters given or not\nis_trait_arg_type(@nospecialize(t)) = ccall(:jl_is_trait_arg_type, Cint, (Any,), t) != 0\n\n"
if old in s: wr('Compiler/src/abstractinterpretation.jl', s.replace(old,''))
PY
  ;; esac
  git add -A Compiler base src stdlib test
  tree=$(git write-tree)
  prev=$(git commit-tree $tree -p $prev -F $M/$part.txt)
  echo "$part $prev"
  git reset -q --hard
done
git checkout -q --detach $prev
