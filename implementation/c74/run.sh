#!/usr/bin/env bash
# C-74's reproducer: build C74Probe's image (printing the closures' CodeInstances while it is built), then load it and print them again.
set -uo pipefail
cd "$(dirname "$0")"; R=$(cd ../../.. && pwd)
source "$R/env.sh" >/dev/null 2>&1
J=${C74_JULIA:-$R/julia-unified/julia}
export JULIA_PKG_OFFLINE=true
nice -n 10 "$J" --startup-file=no --project=env -e 'using Pkg; Pkg.resolve(); Pkg.precompile("C74Probe")' 2>&1 | grep -E 'build:|Precompil|rror' 
nice -n 10 "$J" --startup-file=no --project=env -e 'using C74Probe; C74Probe.report(stdout, "load")'
