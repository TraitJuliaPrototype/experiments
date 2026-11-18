#!/bin/bash
# W-164: does each rewritten gate discriminate? One deliberate wrong assertion per case, each the replaced rule's
# answer, in a copy of the gate; every copy must FAIL on the head. Copies in a temporary directory, removed after.
#     bash experiments/implementation/gates/logs/w164_mutants.sh <julia tree>    (source env.sh first)
R=${TW_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}
T=$(cd "$R" && cd "$1" && pwd); G=$R/experiments/implementation/gates
D=$(mktemp -d "$G/logs/.mutants.XXXX"); trap 'rm -rf "$D"' EXIT
n=0
# mutant <gate> <project> <label> <python old> <python new>
mutant() {
  local g=$1 proj=$2 label=$3 old=$4 new=$5 f
  n=$((n+1)); f=$D/$n-$g.jl
  python3 - "$G/$g.jl" "$f" "$old" "$new" "$G/util.jl" <<'EOF' || { echo "MUTANT $n $g: the line was not found"; return; }
import sys
src, dst, old, new, util = sys.argv[1:]
s = open(src).read()
assert s.count(old) == 1, "line not found once"
s = s.replace(old, new).replace('include("util.jl")', 'include("%s")' % util)
open(dst, "w").write(s)
EOF
  out=$(nice -n 10 "$T/julia" --startup-file=no --project="$proj" "$f" 2>&1); rc=$?
  if [ $rc = 0 ]; then echo "PASSES (does not discriminate) $g: $label"; else echo "FAILS as it should $g: $label | $(echo "$out" | grep -m1 -E 'Error' | cut -c1-160)"; fi
}
U=$R/experiments/implementation; TW=$R/TraitWorld
mutant n8_callable "$U" "uppercase, with no method at Int, is no member (the replaced rule: membership by methods)" \
  '@assert typeof(uppercase) <: C{Tuple{Int}, Int} "no method of uppercase at Int: a member still"' \
  '@assert !(typeof(uppercase) <: C{Tuple{Int}, Int})'
mutant n8_callable "$U" "a method definition begins a membership" \
  '@assert probe(newf) && ci.max_world == typemax(UInt) "a method at A invalidates no membership answer"' \
  '@assert probe(newf) && ci.max_world != typemax(UInt)'
mutant n8_callable_box "$TW" "a wrapper's call outside A raises (the replaced rule: A checked under every attribute)" \
  '@assert B.callwide(cf(B.wide)) == 1' \
  '@assert raises(MethodError, B.callwide, cf(B.wide))'
mutant n8_callable_box "$TW" "a box's result is converted" \
  '@assert raises(TypeError, B.call2, B.intresult, 1.0) "used, not returned: an Int is not converted to Float64"' \
  '@assert B.call2(B.intresult, 1.0) == 2.0'
mutant n26_callable_late_method "$TW" "a function without a method at A takes apply2(::Any) (the replaced rule: no member)" \
  '@assert outcome(L.callit) === MethodError "refused at the box, not sent to apply2(::Any)"' \
  '@assert outcome(L.callit) === :any'
mutant n26_callable_late_method "$TW" "the method at A leaves the code that relied on its absence" \
  '@assert ci.max_world != typemax(UInt) "the method at A ends the code that relied on its absence"' \
  '@assert ci.max_world == typemax(UInt)'
mutant n20_unmet_lookup "$U" "All{AbstractString, Callable} is met by a call method (the replaced rule)" \
  '@assert unmet(AC20) "All{AbstractString, Callable} is unmet before a declaration"' \
  '@assert !unmet(AC20)'
mutant n22_declared_assert "$U" "a method's declared result is read at the set (the replaced rule)" \
  '@assert Base.return_types(throughk, (Vector{Sized22},)) != Any[Int]' \
  '@assert Base.return_types(throughk, (Vector{Sized22},)) == Any[Int]'
mutant n22_declared_assert "$U" "the result is converted" \
  '@assert try through(Measured22[M22()]); false catch e; e isa TypeError end "asserted, not converted"' \
  '@assert through(Measured22[M22()]) == 2'
