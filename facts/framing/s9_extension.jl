# S9, the extension exception (design.md §3.2, second bullet; open-issues §1.10): an extension of
# a stakeholder whose method applies at a fact of compiled code without mentioning its trigger's
# types, activated by loading the unrelated trigger.
#
#   XFun owns `score`; XLib's worker (an image, key Vector{Float64}) calls `score(::Float64)`.
#   XFun's extension on XTrig defines `score(::Float64)`. `using XTrig` activates it.
#
#     julia --project=../../examples/env s9_extension.jl                   # default tier
#     JULIA_TW_STRICT=1 julia --project=../../examples/env s9_extension.jl # strict tier
#     (either with JULIA_COMPILE_BY_FACTS=1 for the facts mode of all code)
#
# Expected (the design, decided 2026-10-20): the extension's method is followed, as plain Julia
# follows it (identical or error), and XLib's compiled code is invalidated in every mode and both
# tiers: the extension counts as XFun, a stakeholder of score(::Float64). Strict mode warns,
# naming the method and the trait code it affects.
include(joinpath(@__DIR__, "..", "..", "examples", "common.jl"))
using XLib, XFun
import TraitWorld
STRICT = TraitWorld.STRICT[]
println("julia ", VERSION, "  facts mode (all): ", facts_mode(), "  strict: ", STRICT)
v = [1.0, 2.0]
t0 = total(v)
check("S9 before: total = 3.0", t0 == 3.0, "got $t0")
cis = valid_cis(XLib)
logbuf = IOBuffer()
r = Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(logbuf, Base.CoreLogging.Warn)) do
    outcome(() -> (@eval using XTrig; nothing))
end
logtext = String(take!(logbuf))
check("S9 loading the trigger raises nothing", r === nothing, r === nothing ? "" : sprint(showerror, r))
ext = Base.get_extension(XFun, :XFunXTrigExt)
check("S9 the extension is active", ext !== nothing)
t1 = Base.invokelatest(total, v); p1 = sum(XFun.score, v)
check("S9 the extension's method is followed (identical to plain Julia)", t1 == p1 == 6.0, "trait $t1, plain $p1")
n = nlost(cis)
check("S9 XLib's compiled code is invalidated (the named exception)", n > 0, "$n of $(length(cis)) CodeInstances of XLib lost")
if STRICT
    check("S9 strict tier: the extension's winning method is followed with a warning", occursin("package extension", logtext) && occursin("score", logtext),
          isempty(logtext) ? "no warning" : first(logtext, 300))
else
    check("S9 default tier: no warning", !occursin("package extension", logtext), first(logtext, 300))
end
# To measure after (B): the recompile of XLib's worker after `using XTrig` (first call after the load).
summary()
