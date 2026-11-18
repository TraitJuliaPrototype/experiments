#!/bin/bash
# E-234: the emulated cache across sessions (E-175's method, experiments/ttfx/cache/make_cache.sh) from a recording
# of rec.jl: a package whose precompile step replays the recorded types (plain: `precompile`; the facts owner's:
# `fpc`; TraitWorld's first-call checks: `checked`, kept in its image as checked ahead), and an environment with it.
#     bash make_cache.sh <name> <recording.jls> <source env> <env out> "<packages it uses>"
#     e.g. bash make_cache.sh SessionCacheFk1 cache/SessionCacheFk-1.jls ../../forks/env_forks env_cache_fk "CSV DataFrames Statistics Dates TraitWorld"
set -euo pipefail
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../.. && pwd)
N=$1; REC=$2; SRC=$(cd $3 && pwd); OUTENV=$4; USES=$5
J=$R/julia-1.13/julia
P=cache/$N; rm -rf $P; mkdir -p $P/src; cp $REC $P/src/trace.jls
uuid=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, '$N'))")
{ printf 'name = "%s"\nuuid = "%s"\nversion = "0.0.1"\n\n[deps]\n' $N $uuid
  for u in $USES; do grep -E "^$u = \"" $SRC/Project.toml || true; done
  # the REPL's types (a REPL session's display code); a stdlib, not in the source environment
  case " $USES " in *" REPL "*) echo 'REPL = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"' ;; esac
  echo 'Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"'; } > $P/Project.toml
cat > $P/src/$N.jl <<JL
# E-234: an emulated cache across sessions: the types a session compiled after its load (rec.jl's recording,
# trace.jls), compiled into this package's image.
module $N
using ${USES// /, }, Serialization
"Compile the method instance of signature \`T\` for the facts owner (a recorded facts CodeInstance, E-175)."
function fpc(@nospecialize(T))
    w = Base.get_world_counter()
    ms = Base._methods_by_ftype(T, 1, w)
    (ms isa Vector && length(ms) == 1) || return false
    mi = Base.Compiler.specialize_method(ms[1])
    ci = Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, Base.Compiler.FACTS_OWNER)
    return ci !== nothing
end
"Run a worker signature's first-call check now and keep its result in this package's image (TraitWorld's ahead checks)."
checked(@nospecialize(T)) = (TraitWorld._check_ahead!(@__MODULE__, nothing, T); true)
include_dependency(joinpath(@__DIR__, "trace.jls"))
des(b) = try Serialization.deserialize(IOBuffer(b)) catch; nothing end
const COUNTS = let r = Serialization.deserialize(joinpath(@__DIR__, "trace.jls")), ok = 0, failed = 0, unread = 0
    for (f, v) in ((precompile, r.plain), (fpc, r.facts), (checked, r.checks)), b in v
        T = des(b)
        T === nothing && (unread += 1; continue)
        (try f(T) catch; false end) === true ? (ok += 1) : (failed += 1)
    end
    (ok = ok, failed = failed, unread = unread)
end
end
JL
rm -rf $OUTENV; mkdir -p $OUTENV
# the source environment's relative paths made absolute
sed -E "s#path = \"\.\./#path = \"$SRC/../#" $SRC/Project.toml > $OUTENV/Project.toml
sed -E "s#path = \"\.\./#path = \"$SRC/../#" $SRC/Manifest.toml > $OUTENV/Manifest.toml
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout -s KILL 1200 $J --startup-file=no --project=$OUTENV -e "using Pkg; Pkg.develop(path=\"$H/$P\"); t = @elapsed Pkg.precompile(); println(\"precompile s=\", round(t; digits=1))" > logs/cache-$N-precompile.log 2>&1
grep -E "precompile s=|ERROR" logs/cache-$N-precompile.log | tail -3
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout -s KILL 300 $J --startup-file=no --project=$OUTENV -e "t = @elapsed using $N; println(\"$N: \", $N.COUNTS, \" load s=\", round(t; digits=3))" | tee -a logs/cache-$N-precompile.log
