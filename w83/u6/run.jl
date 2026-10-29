# U6 (E-252): one arrangement, one way of precompiling, then fresh sessions.
#
#     julia run.jl <R> <mode> <steps> [<steps> ...]
#
# mode:  parallel     Pkg.precompile() (JULIA_NUM_PRECOMPILE_TASKS as the slot sets it)
#        serial       Pkg.precompile() with JULIA_NUM_PRECOMPILE_TASKS=1
#        require      no explicit precompile: the first session's `using` precompiles (require-time path)
#        compilecache Base.compilecache of each top package in a fresh process (no Pkg)
#        none         no images: every session runs with --compiled-modules=no
#        keep         use the images as they are (no clearing, no precompile)
#        update       keep the images, then Pkg.precompile() (rebuilds what Pkg finds stale)
# steps: a comma-separated list for session.jl, one fresh session each.
# The arrangement's depot (images) is emptied first, except for `keep`.
using Pkg, TOML
const R, MODE = ARGS[1], ARGS[2]
const SESSIONS = ARGS[3:end]
const DIR = joinpath(@__DIR__, "arr", R)
const ENVDIR = joinpath(DIR, "env")
const META = TOML.parsefile(joinpath(DIR, "meta.toml"))
ENV["JULIA_PKG_OFFLINE"] = "true"
ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

if !isfile(joinpath(ENVDIR, "Manifest.toml"))
    mkpath(ENVDIR)
    Pkg.activate(ENVDIR; io = devnull)
    Pkg.develop([PackageSpec(path = joinpath(DIR, "pkgs", p)) for p in META["pkgs"]]; io = devnull)
end
Pkg.activate(ENVDIR; io = devnull)

# A depot of the arrangement's own, first on the stack: its images never mix with another arrangement's.
const ARRDEPOT = joinpath(DEPOT_PATH[1], "u6-arr", R)
MODE in ("keep", "update") || rm(ARRDEPOT; recursive = true, force = true)
mkpath(ARRDEPOT)
pushfirst!(DEPOT_PATH, ARRDEPOT)
ENV["JULIA_DEPOT_PATH"] = join(DEPOT_PATH, ":")
const JL = Base.julia_cmd()
println("RESULT $R mode=$MODE doc=$(META["doc"])")
t = @elapsed if MODE in ("parallel", "serial", "update")
    MODE == "serial" && (ENV["JULIA_NUM_PRECOMPILE_TASKS"] = "1")
    Pkg.precompile(; io = stdout)
elseif MODE == "compilecache"
    for p in META["top"]
        run(`$JL --project=$ENVDIR --startup-file=no -e "Base.compilecache(Base.identify_package(\"$p\"))"`)
    end
end
println("RESULT $R mode=$MODE precompile_seconds=$(round(t; digits = 1))")
flags = MODE == "none" ? `--compiled-modules=no` : ``
for steps in SESSIONS
    run(`$JL --project=$ENVDIR --startup-file=no $flags $(joinpath(@__DIR__, "session.jl")) $R $steps`)
end
