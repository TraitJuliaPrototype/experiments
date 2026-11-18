#!/bin/bash
# W-166 (E-507): W-156's suites.sh (../w156/suites.sh) with this directory's depot and logs; the environments are W-156's
# `../w161/suites.sh` and of each README's "Running"). Logs: logs/<label>-<name>.log; a line per suite in
# logs/<label>-summary.log.
#     bash suites.sh <label> [names...]
# names: tables csv report report-session makie makie-session tde tde-session forks-tables digests examples
set -u
H=$(cd "$(dirname "$0")" && pwd); source "$H/env.sh"
L=$1; shift
J=$JN; LOG=$H/logs; S=$LOG/$L-summary.log; R=$TW_ROOT
export LOCK=$H/logs/.lock JULIA=$JN
rev() { git -C "$R/$1" log -1 --format=%h; }
dirty() { git -C "$R/$1" diff --quiet HEAD -- . 2>/dev/null || echo +dirty; }
note() { echo "$*" | tee -a "$S"; }
note "# $L $(date -Is) load $(cut -d' ' -f1-3 /proc/loadavg) | julia-next $(rev julia-next) | TraitWorld $(rev TraitWorld)$(dirty TraitWorld) | TraitTables $(rev TraitTables)$(dirty TraitTables) | TraitCSV $(rev TraitCSV)$(dirty TraitCSV) | TraitReport $(rev TraitReport)$(dirty TraitReport) | TraitMakie $(rev TraitMakie)$(dirty TraitMakie) | TDE $(rev TraitDifferentialEquations)$(dirty TraitDifferentialEquations) | forks $(rev forks)$(dirty forks)"
tally() { grep -A1 '^Test Summary' "$1" | grep -vE '^Test Summary|^--' | head -${2:-12} | tr -s ' ' | tr '\n' ';' | cut -c1-500; grep -E 'tests passed|did not pass|Test Failed|Error During' "$1" | head -3 | tr -s ' ' | tr '\n' ';' | cut -c1-200; }
pkgtest() {   # name, directory
  local f=$LOG/$L-$1.log s=$(date +%s)
  (cd "$R/$2" && nice -n 10 "$J" --startup-file=no --project=. -e 'using Pkg; Pkg.test()') > "$f" 2>&1
  note "$1 | exit $? | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(tally "$f")"
}
run() {
  local s rc f
  s=$(date +%s)
  case $1 in
    tables) pkgtest tables TraitTables ;;
    csv) pkgtest csv TraitCSV ;;
    tde) pkgtest tde TraitDifferentialEquations ;;
    report)
      f=$LOG/$L-report.log
      TMPDIR=$(mktemp -d) nice -n 10 bash "$R/TraitReport/scripts/check.sh" > "$f" 2>&1; rc=$?
      note "report check.sh | exit $rc | $(( $(date +%s) - s )) s | $(grep -c 'ok$' "$f") ok, $(grep -c FAIL "$f") FAIL" ;;
    report-session)
      f=$LOG/$L-report-session.log
      T=$(mktemp -d); TMPDIR=$T bash "$R/TraitReport/scripts/session.sh" > "$f" 2>&1; rc=$?
      cp "$T"/traitreport_session.out "$LOG/$L-report-session.transcript" 2>/dev/null; rm -rf "$T"
      note "$1 | exit $rc | $(( $(date +%s) - s )) s | $(tail -1 "$f" | cut -c1-120)" ;;
    makie-session)
      # TraitMakie's scripts/session.sh, with this directory's environment (env_makie_session: scripts/env's
      # Project.toml, its paths from here, resolved) in place of the uninstantiated scripts/env
      f=$LOG/$L-makie-session.log; o=$LOG/$L-makie-session.transcript
      (cd "$R/TraitMakie" && export JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=140 &&
       nice -n 10 timeout 1800 script -qec "$J --startup-file=no -i --banner=no --project=$W156/env_makie_session" /dev/null \
         < <(cat scripts/session.jl; echo 'exit()') > "$o" 2>&1)
      checks() { tr -d '\r' < "$o" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' | grep -ao 'CHECK .* \(ok\|FAIL\)$'; }
      errors() { tr -d '\r' < "$o" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' | grep -a '^ERROR'; }
      want=$(grep -c '_ok("' "$R/TraitMakie/scripts/session.jl"); want_err=$(grep -c '# ERROR expected$' "$R/TraitMakie/scripts/session.jl")
      { checks; echo "errors:"; errors | cut -c1-200; } > "$f"
      note "$1 | $(( $(date +%s) - s )) s | $(checks | grep -c ' ok$') of $want checks ok, $(checks | grep -c 'FAIL$') failed; $(errors | wc -l) errors, $want_err expected" ;;
    makie)
      f=$LOG/$L-makie.log
      (cd "$R/TraitMakie" && nice -n 10 "$J" --startup-file=no --project="$W156/env_demo" test/runtests.jl) > "$f" 2>&1; rc=$?
      note "makie | exit $rc | $(( $(date +%s) - s )) s | $(grep -c '^Test Summary' "$f") testsets | $(grep -E 'Fail|Error' "$f" | head -3 | tr '\n' ' ' | cut -c1-200)" ;;
    tde-session)
      f=$LOG/$L-tde-session.log
      # scripts/env's Project.toml, its paths from here, resolved: env_tde_session
      (cd "$R/TraitDifferentialEquations" && JULIA_LOAD_PATH="$W156/env_tde_session:@stdlib" nice -n 10 "$J" --startup-file=no scripts/session.jl trait > "$f" 2>&1
       JULIA_LOAD_PATH="$W156/env_tde_session:@stdlib" nice -n 10 "$J" --startup-file=no scripts/session.jl plain > "$LOG/$L-tde-session-plain.log" 2>&1)
      if diff <(grep RESULT "$f") <(grep RESULT "$LOG/$L-tde-session-plain.log") > /dev/null && [ "$(grep -c RESULT "$f")" -gt 0 ]; then d=equal; else d=DIFFER; fi
      note "tde-session | $(( $(date +%s) - s )) s | $(grep -c 'CHECK ok' "$f") CHECK ok, $(grep -c 'CHECK FAIL' "$f") CHECK FAIL | RESULT lines against the plain session: $d ($(grep -c RESULT "$f"))" ;;
    forks-tables)
      f=$LOG/$L-forks-tables.log
      (cd "$R/forks" && JULIA_TW_VIEWCACHE=0 nice -n 10 "$J" --startup-file=no --project=env_forks -e 'using Pkg; Pkg.test("Tables")') > "$f" 2>&1; rc=$?
      note "forks Tables | exit $rc | $(( $(date +%s) - s )) s | $(tally "$f" 3)" ;;
    digests)
      f=$LOG/$L-digests.log
      (export DATA=$R/forks/data JULIA_TW_VIEWCACHE=0 LINES=40 COLUMNS=120
       nice -n 10 "$J" --startup-file=no --project="$W156/env_session" "$R/forks/scripts/session_check.jl" > "$LOG/$L-digests-forks.txt" 2> "$f"
       nice -n 10 "$J" --startup-file=no --project="$R/forks/env_upstream" "$R/forks/scripts/session_check.jl" > "$LOG/$L-digests-upstream.txt" 2>> "$f")
      if [ -s "$LOG/$L-digests-forks.txt" ] && diff -q "$LOG/$L-digests-forks.txt" "$LOG/$L-digests-upstream.txt" > /dev/null; then
        note "digests | equal: $(wc -l < "$LOG/$L-digests-forks.txt") steps | $(( $(date +%s) - s )) s"
      else
        note "digests | DIFFER or missing | see $f"
      fi ;;
    examples)
      for e in intro tutorial strict; do
        f=$LOG/$L-examples-$e.log
        (cd "$R/TraitWorld" && nice -n 10 "$J" --project=. --startup-file=no "$R/experiments/docs-examples/$e.jl") > "$f" 2>&1; rc=$?
        note "examples $e | exit $rc | $(tail -1 "$f" | cut -c1-200)"
      done ;;
  esac
}
for n in "$@"; do run $n; done
