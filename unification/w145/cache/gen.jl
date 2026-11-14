# W-145, part 2 (G-3): generates the packages and environments of the cache workloads.
#     julia gen.jl <TraitWorld-unified path>      -> pkgs/<form>-<case>/{SeriesA,RingB,GlueC,env}
# Two independent packages: SeriesA (a trait `Series` with generic algorithms at it, and a member of
# its own with a workload) and RingB (a type `Ring` with its own functions). A session combines them:
# A's algorithms on B's type. The membership of `Ring` in `Series` is declared, by case,
#   byB      in RingB (which then depends on SeriesA)
#   byBw     the same, and RingB's workload runs A's algorithms on a Ring
#   ext      in an extension of RingB triggered by SeriesA
#   extw     the same, with the workload in the extension
#   glue     in a third package GlueC (it owns neither: a pirate's membership; GlueC is a plain module,
#            since a trait module refuses to declare it)
#   session  in the session, in Main
# Forms: tc (trait, Julia's default: compiled for the member's type), td (trait with `@default_dynamic`:
# compiled once), p (plain Julia: generic functions, the "membership" is the two methods).
tw = abspath(ARGS[1])
root = joinpath(@__DIR__, "pkgs"); rm(root; force = true, recursive = true)
const UUID_TW = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"
const UUID_A = "a1a1a1a1-0000-4000-8000-000000145a01"
const UUID_B = "a1a1a1a1-0000-4000-8000-000000145b01"
const UUID_C = "a1a1a1a1-0000-4000-8000-000000145c01"

algorithms(arg) = """
total(s$arg) = (t = 0.0; for i in 1:len(s); t += at(s, i); end; t)
mean(s$arg) = total(s) / len(s)
function variance(s$arg)
    m = mean(s); v = 0.0
    for i in 1:len(s); d = at(s, i) - m; v += d * d; end
    return v / max(len(s) - 1, 1)
end
normalize(s$arg) = (m = mean(s); sd = sqrt(variance(s)); Float64[(at(s, i) - m) / sd for i in 1:len(s)])
function smooth(s$arg, w::Int)
    n = len(s); out = Vector{Float64}(undef, n)
    for i in 1:n
        lo = max(1, i - w); hi = min(n, i + w); t = 0.0
        for j in lo:hi; t += at(s, j); end
        out[i] = t / (hi - lo + 1)
    end
    return out
end
function histogram(s$arg, nb::Int)
    lo = Inf; hi = -Inf
    for i in 1:len(s); x = at(s, i); lo = min(lo, x); hi = max(hi, x); end
    counts = zeros(Int, nb); width = (hi - lo) / nb
    for i in 1:len(s)
        b = width == 0 ? 1 : clamp(floor(Int, (at(s, i) - lo) / width) + 1, 1, nb)
        counts[b] += 1
    end
    return counts
end
topk(s$arg, k::Int) = partialsort!(Float64[at(s, i) for i in 1:len(s)], 1:min(k, len(s)); rev = true)
function describe(s$arg)
    io = IOBuffer()
    print(io, "n=", len(s), " mean=", round(mean(s); digits = 3), " sd=", round(sqrt(variance(s)); digits = 3))
    print(io, " top=", join(string.(round.(topk(s, 3); digits = 2)), ","))
    return String(take!(io))
end
"""
workload(x) = "total($x); mean($x); variance($x); normalize($x); smooth($x, 3); histogram($x, 8); topk($x, 5); describe($x)"
const EXPORTS = "len, at, total, mean, variance, normalize, smooth, histogram, topk, describe"

function series(form)
    form == :p && return """
    module SeriesA
    export $EXPORTS
    function len end
    function at end
    $(algorithms(""))
    struct Vec; data::Vector{Float64}; end
    len(v::Vec) = length(v.data)
    at(v::Vec, i::Int) = v.data[i]
    let v = Vec(collect(1.0:50.0)); $(workload("v")); end
    end
    """
    return """
    module SeriesA
    using TraitWorld
    @trait_module
    export Series, $EXPORTS
    @trait Series begin
        $(form == :td ? "@default_dynamic" : "")
        len(s::Series)::Int
        at(s::Series, i::Int)::Float64
    end
    $(algorithms("::Series"))
    struct Vec; data::Vector{Float64}; end
    len(v::Vec) = length(v.data)
    at(v::Vec, i::Int) = v.data[i]
    @implement Series Vec
    let v = Vec(collect(1.0:50.0)); $(workload("v")); end
    end
    """
end
membership(form; q = "SeriesA.") = """
$(q)len(r::Ring) = capacity(r)
$(q)at(r::Ring, i::Int) = ringat(r, i)
""" * (form == :p ? "" : "@implement $(q)Series Ring\n")
function ring(form, case)
    inb = case in (:byB, :byBw)
    return """
    module RingB
    $(form == :p ? "" : "using TraitWorld\n@trait_module")
    $(inb ? "import SeriesA" : "")
    export Ring, capacity, ringat, rotated
    struct Ring; data::Vector{Float64}; head::Int; end
    Ring(n::Int) = Ring(Float64[sin(0.37 * i) * i for i in 1:n], 1)
    capacity(r::Ring) = length(r.data)
    ringat(r::Ring, i::Int) = r.data[mod1(r.head + i - 1, length(r.data))]
    rotated(r::Ring, k::Int) = Ring(r.data, mod1(r.head + k, length(r.data)))
    let r = Ring(16); capacity(r); ringat(r, 3); rotated(r, 2); end
    $(inb ? membership(form) : "")
    $(case == :byBw ? "let r = Ring(16); SeriesA." * replace(workload("r"), "; " => "; SeriesA.") * "; end" : "")
    end
    """
end
ext(form, case) = """
module RingBSeriesAExt
$(form == :p ? "" : "using TraitWorld")
using RingB, SeriesA
import RingB: Ring, capacity, ringat
$(membership(form))
$(case == :extw ? "let r = Ring(16); " * workload("r") * "; end" : "")
end
"""
glue(form) = """
module GlueC
$(form == :p ? "" : "using TraitWorld")
using RingB, SeriesA
$(membership(form))
end
"""
# the session's script, in two files: the loads, and the session's own code
loads(case) = "using SeriesA, RingB" * (case == :glue ? ", GlueC" : "") * "\n"
body(form, case) = (case == :session ? (form == :p ? "" : "using TraitWorld\n") * membership(form) : "") * """
function main(args)
    r = Ring(1000)
    s = total(r) + mean(r) + variance(r)
    s += sum(normalize(r)) + sum(smooth(r, 3)) + sum(histogram(r, 8)) + sum(topk(r, 5))
    println(describe(rotated(r, 3)), " ", round(s; digits = 3))
    return 0
end
"""

twdeps = sort!(collect(keys(get(Base.parsed_toml(joinpath(tw, "Project.toml")), "deps", Dict()))))
stdlibs = Dict{String, Any}()
function addstd!(name)
    haskey(stdlibs, name) && return
    proj = Base.parsed_toml(joinpath(Sys.STDLIB, name, "Project.toml"))
    stdlibs[name] = proj
    foreach(addstd!, keys(get(proj, "deps", Dict())))
end
foreach(addstd!, twdeps)
quoted(xs) = "[" * join(("\"$x\"" for x in sort!(collect(xs))), ", ") * "]"
depsline(ds) = isempty(ds) ? "" : "deps = $(quoted(ds))\n"

for form in (:tc, :td, :p), case in (:byB, :byBw, :ext, :extw, :glue, :session)
    d = joinpath(root, "$form-$case")
    t = form != :p
    twdep = t ? "TraitWorld = \"$UUID_TW\"\n" : ""
    for p in ("SeriesA", "RingB"); mkpath(joinpath(d, p, "src")); end
    write(joinpath(d, "SeriesA", "Project.toml"), "name = \"SeriesA\"\nuuid = \"$UUID_A\"\n[deps]\n$twdep")
    write(joinpath(d, "SeriesA", "src", "SeriesA.jl"), series(form))
    inb = case in (:byB, :byBw); isext = case in (:ext, :extw)
    write(joinpath(d, "RingB", "Project.toml"), "name = \"RingB\"\nuuid = \"$UUID_B\"\n[deps]\n$twdep" *
          (inb ? "SeriesA = \"$UUID_A\"\n" : "") *
          (isext ? "[weakdeps]\nSeriesA = \"$UUID_A\"\n[extensions]\nRingBSeriesAExt = \"SeriesA\"\n" : ""))
    write(joinpath(d, "RingB", "src", "RingB.jl"), ring(form, case))
    if isext
        mkpath(joinpath(d, "RingB", "ext")); write(joinpath(d, "RingB", "ext", "RingBSeriesAExt.jl"), ext(form, case))
    end
    if case == :glue
        mkpath(joinpath(d, "GlueC", "src"))
        write(joinpath(d, "GlueC", "Project.toml"), "name = \"GlueC\"\nuuid = \"$UUID_C\"\n[deps]\n$(twdep)RingB = \"$UUID_B\"\nSeriesA = \"$UUID_A\"\n")
        write(joinpath(d, "GlueC", "src", "GlueC.jl"), glue(form))
    end
    env = joinpath(d, "env"); mkpath(env)
    write(joinpath(env, "Project.toml"), "[deps]\nSeriesA = \"$UUID_A\"\nRingB = \"$UUID_B\"\n$twdep" * (case == :glue ? "GlueC = \"$UUID_C\"\n" : ""))
    td = t ? ["TraitWorld"] : String[]
    man = """
    julia_version = "$(VERSION)"
    manifest_format = "2.0"

    [[deps.SeriesA]]
    $(depsline(td))path = "$(joinpath(d, "SeriesA"))"
    uuid = "$UUID_A"
    version = "0.0.0"

    [[deps.RingB]]
    $(depsline(inb ? vcat(td, "SeriesA") : td))path = "$(joinpath(d, "RingB"))"
    uuid = "$UUID_B"
    version = "0.0.0"
    """ * (isext ? "weakdeps = [\"SeriesA\"]\n\n    [deps.RingB.extensions]\n    RingBSeriesAExt = \"SeriesA\"\n" : "") *
    (case == :glue ? """

    [[deps.GlueC]]
    $(depsline(vcat(td, "RingB", "SeriesA")))path = "$(joinpath(d, "GlueC"))"
    uuid = "$UUID_C"
    version = "0.0.0"
    """ : "") * (t ? """

    [[deps.TraitWorld]]
    $(depsline(twdeps))path = "$tw"
    uuid = "$UUID_TW"
    version = "0.2.0"
    """ * join(("""

    [[deps.$n]]
    $(depsline(keys(get(stdlibs[n], "deps", Dict()))))uuid = "$(stdlibs[n]["uuid"])"
    """ for n in sort!(collect(keys(stdlibs)))), "") : "")
    write(joinpath(env, "Manifest.toml"), replace(man, r"^    "m => ""))
    write(joinpath(d, "loads.jl"), loads(case))
    write(joinpath(d, "body.jl"), body(form, case))
end
println("generated: ", join(sort!(readdir(root)), " "))
