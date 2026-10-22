# One-time: the environment of E-158 (TDE's checkout on branch w34, its example packages, the
# PlainODE control, TraitWorld from the checkout, ForwardDiff, SnoopCompileCore).
using Pkg
Pkg.activate(@__DIR__)
Pkg.develop([PackageSpec(path = "../../../TraitWorld"),
             PackageSpec(path = "../../../TraitDifferentialEquations"),
             PackageSpec(path = "../../../TraitDifferentialEquations/examples/LorenzModels"),
             PackageSpec(path = "../../../TraitDifferentialEquations/baselines/PlainODE")])
Pkg.add(["ForwardDiff", "SnoopCompileCore"])
