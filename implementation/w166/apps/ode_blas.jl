# W-166 (open issue 241), a probe: E-361's ODE program (../../w135/apps/ode.jl) with BLAS forwarded first. A trimmed
# build's process does not run OpenBLAS_jll's and LinearAlgebra's `__init__` (plain Julia, vanilla too:
# loadrun_lapack.jl), so a LAPACK call while it loads the program (TraitNonlinearSolve's workload) calls a null pointer.
import OpenBLAS_jll, LinearAlgebra
OpenBLAS_jll.__init__(); LinearAlgebra.__init__()
include(joinpath(@__DIR__, "..", "..", "w135", "apps", "ode.jl"))
