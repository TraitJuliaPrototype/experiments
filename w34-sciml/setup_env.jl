# One-time: the project environment of E-156 (TraitWorld from the checkout; ForwardDiff for P13's duals).
using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path = "../../TraitWorld")   # relative, as the other experiments
Pkg.add("ForwardDiff")
Pkg.precompile()
