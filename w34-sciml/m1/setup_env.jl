# One-time: the environment of E-157 (TDE's checkout on branch w34, its example packages, TraitWorld
# from the checkout, ForwardDiff, SnoopCompileCore for check 4's list of inferred methods).
using Pkg
Pkg.activate(@__DIR__)
Pkg.develop([PackageSpec(path = "../../../TraitWorld"),
             PackageSpec(path = "../../../TraitDifferentialEquations"),
             PackageSpec(path = "../../../TraitDifferentialEquations/examples/LorenzModels"),
             PackageSpec(path = "../../../TraitDifferentialEquations/examples/ChainModels")])
Pkg.add(["ForwardDiff", "SnoopCompileCore"])
