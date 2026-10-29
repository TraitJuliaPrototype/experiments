#!/bin/bash
# W-89 / F-23 / C-5: the facts system image under --compile=min. Fails on a hang (killed after 30 s)
# and when a call target gains a CodeInstance per call. Usage: check_compile_min.sh [julia-1.13 dir]
J=${1:-$(dirname "$0")/../../../julia-1.13}
IMG=$J/usr/lib/julia/facts/sys.so
prog='f(x) = isa(x, Int); s = 0; for i in 1:1000; global s += f(i); end
c = which(f, (Int,)).specializations.cache; n = 1; while isdefined(c, :next); global n += 1; global c = c.next; end
print(s, " ", n)'
out=$(timeout -s KILL 30 "$J/usr/bin/julia" -J "$IMG" --compile=min -t1 --startup-file=no -e "$prog" 2>&1); rc=$?
if [ $rc -ne 0 ]; then echo "FAIL  F-23: --compile=min under the facts image (exit $rc${out:+: $out})"; exit 1; fi
read -r s n <<<"$out"
[ "$s" = 1000 ] && echo "PASS  F-23: --compile=min starts and runs ($out)" || { echo "FAIL  F-23: wrong result ($out)"; exit 1; }
[ "$n" -le 2 ] && echo "PASS  C-5: $n CodeInstance(s) for f after 1000 calls" || { echo "FAIL  C-5: $n CodeInstances for f after 1000 calls"; exit 1; }
