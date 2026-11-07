# Shared harness for the acceptance cases (plan §C; the old suite's phrasing:
# policy value == plain value, or the named raise — `experiments/facts/` is the
# case source, oc-notes/m3-editplan.md §C is the disposition).
#
# Convention for AC_*.jl:
#   include("ac_util.jl")
#   <body: marked twin vs plain twin; values equal before/after the change>
#   ac_finish(@__FILE__)      # re-runs THIS file in a child under the test bed
#                             # (JULIA_COMPILE_BY_FACTS=1, compiler §2.5) and
#                             # requires the same OK line — "both settings"
const Compiler = Base.Compiler

const AC_UTIL = @__DIR__
include(joinpath(AC_UTIL, "..", "..", "gates", "util.jl"))

const ac_julia = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`

# A marked function's methods are compiled by facts whoever calls them: the method flag "always
# facts" (compiler §2.2), which `Expr(:meta, :facts_always)` sets at the definition. Set before the
# function's first call (a method instance reads its policy at its first use, C-49).
mark!(f) = foreach(m -> (m.facts = 0x02), methods(f))
# `@enforce_fully_typed` (traits §13) is not built yet (W-114): the case that uses it is skipped
markc!(f) = error("@enforce_fully_typed is not built yet (W-114)")
const AC_TESTBED = get(ENV, "JULIA_COMPILE_BY_FACTS", "0") == "1"

function ac_finish(path::AbstractString)
    tag = splitext(basename(path))[1]
    if AC_TESTBED
        println("$tag: OK (all)")        # we ARE the child
        return
    end
    tf = tempname()
    try
        run(pipeline(addenv(`$ac_julia $path`, "JULIA_COMPILE_BY_FACTS" => "1"),
                     stdout=tf, stderr=tf))
        out = read(tf, String)
        @assert occursin("$tag: OK (all)", out) "re-run under JULIA_COMPILE_BY_FACTS=1 must print the OK line, got: $out"
    finally
        rm(tf, force=true)
    end
    println("$tag: OK")
end
