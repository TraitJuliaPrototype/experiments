# E-230: where D's load goes. A fresh process; WL_FIRST=tde|makie names which package loads first.
# Per load: wall and compile time, then @time_imports' per-package lines (in the log).
using InteractiveUtils: @time_imports   # a stdlib, loaded before the timed loads
Base.cumulative_compile_timing(true)
ct() = Base.cumulative_compile_time_ns()[1] / 1e9
first_ = get(ENV, "WL_FIRST", "tde")
order = first_ == "tde" ? (:TraitDifferentialEquations, :TraitMakie) : (:TraitMakie, :TraitDifferentialEquations)
for p in order
    c0 = ct(); t = @elapsed @eval @time_imports using $p
    println("LOAD ", p, " wall ", round(t; digits = 3), " compile ", round(ct() - c0; digits = 3))
end
