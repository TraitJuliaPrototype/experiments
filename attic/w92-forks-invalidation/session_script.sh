#!/bin/bash
# E-238: the forks' session (forks/scripts/session.jl) as a script with the REPL's display mirrored: each input the
# REPL would display is shown as the REPL shows it (`show` with MIME"text/plain" to an `IOContext` over a
# `REPL.LimitIO`, here over an `IOBuffer`); REPL is loaded first, as in the REPL. At each mark: the step's wall
# and compile time and the CodeInstances it created, by owner and by the package of their method.
#     bash session_script.sh <out.log>   (run on the branch w92-wrapped: logs/script-wrapped.log) [env=forks/env_forks]
set -u
cd "$(dirname "$0")"; H=$PWD; R=$(cd ../.. && pwd)
out=$1; env=${2:-$R/forks/env_forks}
gen=$(mktemp -p ${TMPDIR:-/tmp} w92sessXXXX.jl)
{
cat <<'JL'
Base.cumulative_compile_timing(true)
using REPL
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function _allcis()
    s = Base.IdSet{Any}()
    Base.visit(_MT) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci isa Core.CodeInstance; push!(s, ci); ci = isdefined(ci, :next) ? ci.next : nothing; end
        end
    end
    s
end
_mi(ci) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
_disp(x) = (show(IOContext(REPL.LimitIO(IOBuffer(), 10^7), :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), x); nothing)
const _ST = Ref{Any}(nothing)
function _m(name)
    t = time(); c = Base.cumulative_compile_time_ns()[1] / 1e9
    if _ST[] !== nothing
        t0, c0, before = _ST[]
        new = [ci for ci in _allcis() if !(ci in before)]
        byown = Dict{Any,Int}(); bymod = Dict{Any,Int}()
        for ci in new
            byown[ci.owner] = get(byown, ci.owner, 0) + 1
            m = _mi(ci).def; k = (ci.owner, m isa Method ? Base.moduleroot(m.module) : Core)
            bymod[k] = get(bymod, k, 0) + 1
        end
        println("S ", rpad(name, 18), " wall ", lpad(round(t - t0; digits = 3), 6), " compile ", lpad(round(c - c0; digits = 3), 6),
                " new ", lpad(length(new), 5), "  ", join(("$(repr(o)) $(m) $n" for ((o, m), n) in sort!(collect(bymod); by = last, rev = true)[1:min(end, 5)]), "; "))
    end
    _ST[] = (time(), Base.cumulative_compile_time_ns()[1] / 1e9, _allcis())
    nothing
end
JL
awk '
    /^#/ || /^_m\(s\) = / || /^exit\(\)/ || /^\s*$/ { next }
    /^_m\(/ { print; next }
    /;\s*$/ || /^using / { print; next }
    /^[A-Za-z_0-9.]+ = / { print; n = $1; print "_disp(" n ")"; next }
    { print "_disp(" $0 ")" }' $R/forks/scripts/session.jl
} > $gen
cp $gen $H/logs/session_script.jl
cd $R/forks
DATA=$R/forks/data JULIA_PKG_OFFLINE=true flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout -s KILL 900 \
    $R/julia-1.13/julia --startup-file=no --project=$env $gen > $out 2>&1
rm -f $gen
