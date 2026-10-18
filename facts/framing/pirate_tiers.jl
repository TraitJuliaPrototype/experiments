# A winning pirate, in each order against the trait code it changes, under both tiers
# (design.md §3.2 and §3.5; the review's example 2, "the before order").
#
#   XLib's worker `wtotal` (an image, key Vector{Float64}) calls `XFun.weight(::Float64)`.
#   The pirate `XFun.weight(::Float64) = 3.0` owns neither `weight` nor `Float64`. It wins there.
#
#     julia --project=../../examples/env pirate_tiers.jl ORDER                    # default tier
#     JULIA_TW_STRICT=1 julia --project=../../examples/env pirate_tiers.jl ORDER  # strict tier
#
# ORDER:
#   after          `using XLib`, a call, then `using XPirate` (the pirate from a package image)
#   before         `using XPirate`, then `using XLib` (the pirate already loaded: piece 15's case)
#   prompt-after   `using XLib`, a call, then the pirate defined at the prompt
#   prompt-before  the pirate at the prompt, then `using XLib`
#   binding        S10 for trait code: a trait module reads a const of module Cfg; another module
#                  redefines it (no hook sees bindings)
#
# Expected, the design (§3.2, §3.5):
#   default tier: the pirate is followed in every order; results are plain Julia's.
#   strict tier:  after / prompt-after: refused where it is defined (a PirateError at the prompt;
#                 left inactive at an image's activation); the method then does not exist for
#                 plain Julia either. before / prompt-before: an error naming the pirate when the
#                 image whose facts it breaks is loaded (piece 15) — pending, not built: today the
#                 pirate is followed and the image's code silently recompiles.
#                 binding: refused or named by a rule for bindings — pending, no rule and no hook.
include(joinpath(@__DIR__, "..", "..", "examples", "common.jl"))
using TraitWorld
order = ARGS[1]
STRICT = TraitWorld.STRICT[]
tier = STRICT ? "strict" : "default"
println("julia ", VERSION, "  facts mode (all): ", facts_mode(), "  tier: ", tier, "  order: ", order)
v = [1.0, 2.0]
plainw() = Base.invokelatest(() -> sum(x -> Main.XFun.weight(x) * x, v))   # what plain Julia computes now
pirate_prompt = :(Main.XFun.weight(x::Float64) = 3.0)
logs = IOBuffer()

if order in ("after", "prompt-after")
    @eval using XLib, XFun
    check("$order/$tier before the pirate: wtotal = 3.0", wtotal(v) == 3.0)
    cis = valid_cis(XLib)
    if order == "after"
        r = outcome(() -> Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(logs)) do
            @eval using XPirate; nothing
        end)
    else
        r = outcome(() -> (toplevel(pirate_prompt); nothing))
    end
    msg = String(take!(logs)) * (r isa Exception ? sprint(showerror, r) : "")
    w = Base.invokelatest(wtotal, v); p = plainw()
    if STRICT
        refused = p == 3.0
        check("$order/strict the pirate is refused where it is defined", refused,
              order == "after" ? "load log: $(first(msg, 300))" : "raised: $(r isa Exception ? typeof(r) : r)")
        check("$order/strict the message names the method and the code", occursin("weight", msg) && occursin("XLib", msg) || occursin("wtotal", msg),
              first(msg, 400))
        check("$order/strict trait code unchanged and identical to plain Julia", w == p == 3.0, "trait $w, plain $p")
        check("$order/strict no compiled code of XLib lost", nlost(cis) == 0, "$(nlost(cis)) lost")
    else
        check("$order/default the pirate is followed: identical to plain Julia", w == p == 9.0, "trait $w, plain $p")
        check("$order/default XLib's code at the pirate's fact recompiles (lost > 0)", nlost(cis) > 0, "$(nlost(cis)) of $(length(cis)) lost")
    end
elseif order in ("before", "prompt-before")
    @eval using XFun
    if order == "before"
        @eval using XPirate
    else
        toplevel(pirate_prompt)
    end
    r = outcome(() -> Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(logs)) do
        @eval using XLib; nothing
    end)
    msg = String(take!(logs)) * (r isa Exception ? sprint(showerror, r) : "")
    w = r isa Exception ? r : Base.invokelatest(Main.XLib.wtotal, v); p = plainw()
    check("$order/$tier results identical to plain Julia (or an error)", w isa Exception || w == p == 9.0, "trait $w, plain $p")
    if STRICT
        if r isa Exception || occursin("Pirate", msg)
            check("$order/strict an error names the pirate at the image's load (piece 15)", occursin("weight", msg), first(msg, 400))
        else
            pending("$order/strict an error names the pirate at the image's load",
                    "piece 15 (image validation reports the winning method)", "followed silently, wtotal = $w")
        end
    end
elseif order == "binding"
    toplevel(quote
        module Cfg; const SCALE = 2.0; end
        @trait_module module BindLib
        using TraitWorld
        import ..Cfg
        export BV, scaled
        @trait BV{R} begin
            bv(r::R)::Vector{Float64}
        end
        @implement BV{Vector{Float64}} begin
            bv(r) = r
        end
        scaled(b::BV) = (s = 0.0; for x in bv(b); s += Cfg.SCALE * x; end; s)
        end
    end)
    s0 = Base.invokelatest(Main.BindLib.scaled, v)
    check("binding/$tier before: scaled = 6.0", s0 == 6.0, "got $s0")
    cis = valid_cis(Main.BindLib)
    r = outcome(() -> (toplevel(:(module Intruder; Core.eval(Main.Cfg, :(const SCALE = 5.0)); end)); nothing))
    s1 = Base.invokelatest(Main.BindLib.scaled, v)
    check("binding/$tier the new value is read (identical to plain Julia)", r !== nothing || s1 == 15.0, "got $s1, raised $(r === nothing ? "nothing" : typeof(r))")
    check("binding/$tier the trait module's code is invalidated", nlost(cis) > 0, "$(nlost(cis)) of $(length(cis)) lost")
    STRICT && pending("binding/strict a binding redefined by a non-owner is refused or named",
                      "a rule for bindings and a hook that sees them (design.md §3.2, open-issues §1.10)",
                      r === nothing ? "accepted silently" : "raised $(typeof(r))")
else
    error("unknown order $order")
end
summary()
