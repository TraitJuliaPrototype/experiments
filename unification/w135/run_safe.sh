#!/bin/bash
# E-361: bash run_safe.sh -- every app built with --trim=safe, and the verifier's report counted
# (summarize.py). Writes logs/run-safe.log; the build logs are logs/<name>.build.log. Builds run one
# after another. Run run_warn.sh first: its sessions write the packages' images (README).
set -u
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; R=$(cd "$H/../../.." && pwd)
LOG=$H/logs/run-safe.log
rev() { git -C "$R/$1" log -1 --format=%h; }
echo "# E-361 run_safe $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-unified $(rev julia-unified) julia-vanilla $(rev julia-vanilla) TraitWorld-unified $(rev TraitWorld-unified)" > "$LOG"
one() { # one <name> <app> <tree> <project or "">   (the app's env is the caller's)
  local name=$1 app=$2 tree=$3 proj=$4
  rm -f out/$name out/$name-o.a
  NAME=$name TRIM=safe JULIA_TREE=$tree bash build.sh $app $proj > /dev/null 2>&1
  ROOTS=4 python3 summarize.py logs/$name.build.log | tee -a "$LOG"
}
U=julia-unified; V=julia-vanilla
one hello hello $U ""
one jll-safe-unified jll $U "$H/env_jll"
one jll-safe-vanilla jll $V "$H/env_jll"
VERIFY=0 one table-bare table $U ""
VERIFY=1 one table-verify table $U ""
TABLE_PLAIN=1 one table-plain table $U ""
TABLE_PLAIN=1 one table-plain-vanilla table $V ""
VERIFY=0 one ode-bare ode $U ""
VERIFY=1 one ode-verify ode $U ""
VERIFY=0 ODE_AD=1 one ode-ad-bare ode $U ""
VERIFY=1 ODE_AD=1 one ode-ad-verify ode $U ""
ODE_PLAIN=1 one ode-plain ode $U ""
ODE_PLAIN=1 one ode-plain-vanilla ode $V ""
VERIFY=0 one plot-bare plot $U ""
VERIFY=1 one plot-verify plot $U ""
one plot_plain plot_plain $U ""
one plot_plain-vanilla plot_plain $V ""
