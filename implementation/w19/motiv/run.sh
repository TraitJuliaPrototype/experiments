#!/bin/bash
# W-19: the motivation programs of the patches, on one build. bash motiv/run.sh <tree> -> logs/motiv-<tree>.log
# One Julia process at a time, niced; each a few seconds.
set -u; ulimit -c 0
H=$(cd "$(dirname "$0")/.." && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
export JULIA_DEPOT_PATH=$R/.julia-depot/agent-depots/w19:$R/.julia-depot: JULIA_PKG_OFFLINE=true JULIA_NUM_THREADS=1
T=$1; J="nice -n 10 $R/$T/julia --startup-file=no --history-file=no"; LOG=$H/logs/motiv-$(basename $T).log
{
echo "# W-19 motivation programs | $T $(git -C $R/$T log -1 --format=%h) | $(date -Is) | load $(cut -d' ' -f1-3 /proc/loadavg)"
echo "## invalidations (motiv/invalidations.jl), one process per probe"
for p in sizeof_type getproperty_type unwrap_unionall typejoin convert_string symbol_ctor inexacterror val_ctor immutabledict; do
  $J $H/motiv/invalidations.jl $p 2>&1 | tail -1
done
echo "## P10, P18: first calls (motiv/first_calls.jl), 3 fresh processes each"
for i in 1 2 3; do $J $H/motiv/first_calls.jl rt 2>&1 | tail -1; done
for i in 1 2 3; do $J $H/motiv/first_calls.jl irt 2>&1 | tail -1; done
echo "## P11, P12: a varargs wrapper in a recursion (motiv/varargs_recursion.jl)"
$J $H/motiv/varargs_recursion.jl 2>&1 | tail -2
echo "## P14: a dynamic call at one site with 1, 4, 16 value types (motiv/dispatch_site.jl)"
$J $H/motiv/dispatch_site.jl 2>&1 | tail -3
echo "## P16: the calling convention :caller_world (motiv/caller_world.jl)"
$J $H/motiv/caller_world.jl 2>&1 | tail -4
echo "## P15: the dispatch profiler (JULIA_DISPATCH_PROFILE=1, motiv/dispatch_site.jl)"
JULIA_DISPATCH_PROFILE=1 $J $H/motiv/dispatch_site.jl 2>&1 | grep -A4 -- '-- dynamic calls by' | head -12
echo "## P06: Val(x) at an unknown x: the calls left in its code (code_typed)"
$J -e 'f(@nospecialize(x)) = Val(x); ci = code_typed(f, (Any,))[1][1]; println("statements: ", join(filter(s -> s isa Expr && s.head in (:call, :invoke, :new, :foreigncall), ci.code), " | "))' 2>&1 | tail -1
echo "# done $(date -Is)"
} > $LOG 2>&1
cat $LOG
