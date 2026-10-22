# Shared by the E-158 checks: the setting line, the machine's load, and counting CodeInstances.
using TraitWorld, TraitDifferentialEquations, Printf
const ODECore = TraitDifferentialEquations.ODECore

gitc(d) = let c = try readchomp(`git -C $d rev-parse --short HEAD`) catch; "?" end
    dirty = try !isempty(readchomp(`git -C $d status --porcelain --untracked-files=no`)) catch; false end
    dirty ? c * "+changes" : c
end
loadavg() = join(first(split(read("/proc/loadavg", String)), 3), " ")
const SETTING = Base.Compiler.NativeInterpreter().facts ? "all" : "product"

function header(check, what)
    println("== E-158 ", check, ": ", what)
    println("   julia ", VERSION, " (", Base.GIT_VERSION_INFO.commit_short, ")  TraitWorld ", gitc(pkgdir(TraitWorld)),
            "  TDE ", gitc(pkgdir(TraitDifferentialEquations)), " (", readchomp(`git -C $(pkgdir(TraitDifferentialEquations)) branch --show-current`), ")",
            "  setting ", SETTING, "  strict ", TraitWorld.STRICT[] ? "on" : "off", "  threads ", Threads.nthreads())
    println("   load (cut -d' ' -f1-3 /proc/loadavg) at start: ", loadavg())
    println()
end
const NCHECK = Ref(0); const NFAIL = Ref(0)
"A check: PASS or FAIL with a detail; the footer counts them."
function check(what, ok, detail = "")
    NCHECK[] += 1
    ok || (NFAIL[] += 1)
    println(ok ? "  PASS  " : "  FAIL  ", what, isempty(detail) ? "" : "  [" * detail * "]")
end
function footer()
    println("\nchecks: ", NCHECK[] - NFAIL[], " of ", NCHECK[], " pass")
    println("load at end: ", loadavg())
end

# --- counting CodeInstances --------------------------------------------------------------------
# Every method of the given modules, from Julia's global method table; for each, its
# specializations (MethodInstances) and the CodeInstances in each one's cache, by owner (`nothing`:
# plain code; `:facts`: code compiled by the facts compiler; TraitWorld's check owner: inference of
# TraitWorld's checks only). A snapshot maps (MethodInstance, owner) to the number of CodeInstances.
const MT = isdefined(Core, :methodtable) ? Core.methodtable : Core.GlobalMethods
function snapshot(pred)
    snap = Dict{Tuple{Core.MethodInstance,Any},Int}()
    Base.visit(MT) do m
        pred(m) || return
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                k = (mi, ci.owner)
                snap[k] = get(snap, k, 0) + 1
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return snap
end
modpred(mods...) = m -> m.module in mods
"The (MethodInstance, owner) pairs new in `b` against `a` (or with more CodeInstances)."
newin(a, b) = sort!([k for (k, n) in b if get(a, k, 0) < n]; by = k -> string(k[1].def.module, ".", k[1].def.name))
ownername(o) = o === nothing ? "plain" : o === :facts ? "facts" : string(typeof(o))
function report_new(label, ks; show = 40)
    println("  ", label, ": ", length(ks), " new CodeInstance(s)")
    for (mi, o) in ks[1:min(end, show)]
        s = string(mi.specTypes)
        println("     [", ownername(o), "] ", mi.def.module, ".", mi.def.name, "  ", length(s) > 260 ? s[1:260] * "…" : s)
    end
    length(ks) > show && println("     … ", length(ks) - show, " more")
end
"Count by module of the methods, over every module."
function bymodule(ks)
    d = Dict{String,Int}()
    for (mi, o) in ks
        k = string(mi.def.module)
        d[k] = get(d, k, 0) + 1
    end
    return sort!(collect(d); by = first)
end
