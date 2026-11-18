# E-233: TraitReport's form (t) (TraitReport/scripts/report_tables.jl) broken down: the load with @time_imports and
# Julia's compile counter, each phase's wall and compile time, TraitWorld's load report (JULIA_TW_LOADREPORT=1),
# and the CodeInstances created after the load (rec.jl). With TR_CACHE=<package> the emulated cache loads with
# the imports (E-234); with TR_RECORD=<file.jls> the session's CodeInstances are recorded for it.
#     julia --project=<env_t or env_cache_tr> tr_breakdown.jl <csv> <out.png>
Base.cumulative_compile_timing(true)
ct() = Base.cumulative_compile_time_ns()[1] / 1e9
const DETAIL = get(ENV, "TR_DETAIL", "0") == "1"
T = [(time(), ct(), Base.gc_time_ns() / 1e9)]
mark!() = push!(T, (time(), ct(), Base.gc_time_ns() / 1e9))
DETAIL && using InteractiveUtils   # a stdlib, before the timed load
DETAIL ? (@eval @time_imports using TraitCSV, TraitTables, TraitMakie) : (@eval using TraitCSV, TraitTables, TraitMakie)
haskey(ENV, "TR_CACHE") && @eval using $(Symbol(ENV["TR_CACHE"]))
mark!()
(DETAIL || haskey(ENV, "TR_RECORD")) && (include(joinpath(@__DIR__, "rec.jl")); _snap!())
mark!()   # the probe's own time, left out below
t = TraitCSV.read(ARGS[1])
mark!()
print(summary_text(t))
mark!()
name = numericnames(t)[1]
x = floats(t, name; skipmissing = true)
f = hist(x; bins = 24, title = basename(ARGS[1]), size = (1200, 800))
vlines!(f, sum(x) / length(x); color = :red)
save(ARGS[2], f)
mark!()
names_ = ("imports", "probe", "read", "summarize", "plot+PNG")
for (k, n) in enumerate(names_)
    a, b = T[k], T[k+1]
    println(stderr, "B ", rpad(n, 10), " wall ", round(b[1] - a[1]; digits = 3), " compile ", round(b[2] - a[2]; digits = 3), " gc ", round(b[3] - a[3]; digits = 3))
end
println(stderr, "B abs ", repr(T[1][1]), " ", repr(time()))
println(stderr, "B after the load: wall ", round(T[end][1] - T[3][1]; digits = 3), " compile ", round(T[end][2] - T[3][2]; digits = 3))
if DETAIL
    _count(stderr)
    TW = Base.root_module(Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld"))
    TW.loadreport(stderr; top = 6)
end
haskey(ENV, "TR_RECORD") && _record(ENV["TR_RECORD"])
