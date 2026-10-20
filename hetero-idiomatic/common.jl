# Shared by the hi*.jl scripts: the setting, the load average, and one benchmark line.
using BenchmarkTools, Printf
const SETTING = Base.Compiler.NativeInterpreter().facts ? "all" : "product"
loadavg() = first(split(read("/proc/loadavg", String)), 3)
header(name) = println("== ", name, "  julia ", VERSION, " (", Base.GIT_VERSION_INFO.commit_short, ")  setting ", SETTING,
                       "  TraitWorld ", TRAITWORLD_COMMIT, "  load ", join(loadavg(), " "))
const TRAITWORLD_COMMIT = let d = pkgdir(Base.require(Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")))
    c = try readchomp(`git -C $d rev-parse --short HEAD`) catch; "?" end
    dirty = try !isempty(readchomp(`git -C $d status --porcelain --untracked-files=no`)) catch; false end
    dirty ? c * "+changes" : c
end
"""
One row: the median time per element over BenchmarkTools' samples, the samples taken, the
allocation per element. `n` elements per call. `setup` as in `@benchmark` (then `evals = 1`).
"""
macro row(label, kind, n, ex, setup = nothing)
    b = setup === nothing ? :(@benchmark $ex samples = 2000 seconds = 2) :
                            :(@benchmark $ex setup = $setup evals = 1 samples = 2000 seconds = 2)
    quote
        local tr = $(esc(b))
        local t = median(tr).time / $(esc(n))
        local a = median(tr).memory / $(esc(n))
        @printf("%-8s %-12s %-58s %9.2f ns/elt %7.1f B/elt  (median of %d samples)\n", SETTING, $(esc(kind)), $(esc(label)), t, a, length(tr.times))
    end
end
