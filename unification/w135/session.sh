#!/bin/bash
# E-361: bash session.sh <app> [project] [args...] -- the app run in a session, for its output (and verify_main's report with VERIFY=1).
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd); source "$R/env.sh"
app=$1; proj=${2:-$H/../w134/env_demo}; shift; shift
JULIA_PKG_OFFLINE=true nice -n 10 $R/${JULIA_TREE:-julia-unified}/julia -t 1 --startup-file=no --project=$proj -e 'include(ARGS[1]); exit(main(ARGS[2:end]))' $H/apps/$app.jl "$@"
