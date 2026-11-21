#!/bin/bash
# W-159, G-7: E-373, a gate on the head only: each demonstrator's suite and session check (w156/suites.sh: tables csv
# report report-session makie makie-session tde tde-session forks-tables digests examples) and NetworkDynamics' test
# subset (w161/suites.sh nd). Not a measurement of time; a failure is named with its rule (E-373's criterion).
# The two scripts run on julia-next with the trees at their default paths (the head's defaults), each with its own
# depot (w156's, w161's) and logs (their logs/ directories, label w159-<label>): the summaries are copied here.
#     bash g7_suites.sh <label> [names...]     -> logs/g7-suites-<label>.log. 20 to 30 minutes: over ten, see README.
source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
label=$1; shift; NAMES=${*:-tables csv report report-session makie makie-session tde tde-session forks-tables digests examples}
[ "$(jtree H)" = "$R/julia-next" ] || die "the suites run on julia-next only (H_JULIA=$H_JULIA)"
header "$LOGS/g7-suites-$label.log" "G-7 E-373 the suites on the head (w156/suites.sh, w161/suites.sh nd)" H
check H
bash "$IMPL/w156/suites.sh" w159-$label $NAMES >> "$LOG" 2>&1
bash "$IMPL/w161/suites.sh" w159-$label nd >> "$LOG" 2>&1
cat "$IMPL/w156/logs/w159-$label-summary.log" "$IMPL/w161/logs/w159-$label-summary.log" >> "$LOG" 2>/dev/null
footer
