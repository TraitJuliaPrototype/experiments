# E-230: TraitWorld's load report for `using TraitDifferentialEquations` (JULIA_TW_LOADREPORT=1).
Base.cumulative_compile_timing(true)
t = @elapsed using TraitDifferentialEquations
println("LOAD TraitDifferentialEquations wall ", round(t; digits = 3), " compile ", round(Base.cumulative_compile_time_ns()[1] / 1e9; digits = 3))
using TraitWorld
TraitWorld.loadreport(; top = 20)
