# Stock Julia 1.13.2: install the load-time half of the trait-world filter at run time, by including
# the ported Compiler/src/reinfer.jl (reinfer_tw_1132.jl, beside this file) into Base.Compiler.ReinferUtils
# (no rebuild), then run a measurement script with the remaining arguments.
#   julia +1.13.2 --startup-file=no --project=experiments/interfaces/env experiments/runtime-injection/exp113/inject113.jl <script.jl> [args...]
# INJECT=0 runs the script without the injection (the same wrapper, for A/B).
# JULIA_TW_PROTECT=<names> (read by the injected code) treats those packages as trait-world code (x13, measurement only).
# Each step is a top-level statement of its own, so that it runs in the world after the redefinitions.
const INJ = get(ENV, "INJECT", "1") == "1"
const R = Base.Compiler.ReinferUtils                                       # where image validation lives on 1.13
const T_INJ = INJ ? @elapsed(Base.include(R, joinpath(@__DIR__, "reinfer_tw_1132.jl"))) : 0.0
const T_ACT = INJ ? @elapsed(Base.Compiler.activate_codegen!()) : 0.0     # 1.13 validates images in the typeinf world
INJ && (Base._require_world_age[] = Base.get_world_counter())             # the loader runs in the require world
INJ && println("injected the ported reinfer.jl in ", round(T_INJ; digits = 3), " s, activate_codegen! ", round(T_ACT; digits = 3), " s")
const SCRIPT = abspath(popfirst!(ARGS))
include(SCRIPT)
INJ && println("load filter (injected): image edges kept ", R._tw_skipped[])
