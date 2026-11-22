#!/bin/bash
# W-169 (E-536): the round, group by group; each session beside its plain run, interleaved.
#     bash run_all.sh <label> [<group> ...]       groups: frames table ode plot nd (default all)   RUNS=3
# Per cell: a warm-up and RUNS unprofiled runs (time), interleaved within the group; then one run of each of
# prof, trace, inval (and dispatch on the head). nd: one run of each kind (a session is a minute), no warm-up.
# NOTIME=1 skips the unprofiled runs, KINDS=<kinds> and CELLS="<session>:<S> ..." narrow a group (to finish a group).
# Waits while the machine's 1-minute load is above half its cores. -> logs/<label>/, logs/run-<label>.log
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
label=$1; shift; RUNS=${RUNS:-3}; export LABEL=$label
GROUPS_=${*:-frames table ode plot nd}
RL=$LOGS/run-$label.log
half=$(( $(nproc --all) / 2 ))
waitload() { while [ "$(cut -d' ' -f1 /proc/loadavg | cut -d. -f1)" -ge "$half" ]; do echo "# waiting: load $(load)" >> "$RL"; sleep 60; done; }
one() { waitload; local t=$(date +%s); bash "$W169/profile.sh" "$@"; local rc=$?; echo "$* | rc $rc | $(( $(date +%s) - t )) s | load $(load)" >> "$RL"; }
echo "# W-169 run_all $label $GROUPS_ | $(date -Is) | load $(load)" >> "$RL"
for g in $GROUPS_; do
  case $g in
    frames) cells="frames-up:V frames-up:H frames-facts:H frames-forks:H" ;;
    table)  cells="table:H table-plain:H" ;;
    ode)    cells="ode:H ode-plain:H odecb:H odecb-plain:H" ;;
    plot)   cells="plot:H plot-plain:H report:H report-plain:H" ;;
    nd)     for k in time prof trace inval dispatch; do one nd H $k 1; done; continue ;;
    *) die "group $g" ;;
  esac
  [ -n "${CELLS:-}" ] && cells=$CELLS
  [ "${NOTIME:-0}" = 1 ] || for i in $(seq 0 "$RUNS"); do for c in $cells; do one "${c%:*}" "${c#*:}" time "$i"; done; done
  for k in ${KINDS:-prof trace inval dispatch}; do for c in $cells; do
    [ $k = dispatch ] && [ "${c#*:}" = V ] && continue
    one "${c%:*}" "${c#*:}" $k 1; done; done
done
echo "# done $(date -Is) | load $(load)" >> "$RL"
