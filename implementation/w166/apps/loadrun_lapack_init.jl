# W-166: the same as loadrun_lapack.jl, with OpenBLAS_jll's and LinearAlgebra's `__init__` called first (a probe: the
# build's process does not initialize them, so BLAS forwards nothing).
using LinearAlgebra
import OpenBLAS_jll
println(Core.stdout, "before: ", length(LinearAlgebra.BLAS.lbt_get_config().loaded_libs), " BLAS libraries forwarded")
OpenBLAS_jll.__init__(); LinearAlgebra.__init__()
println(Core.stdout, "after: ", length(LinearAlgebra.BLAS.lbt_get_config().loaded_libs), " BLAS libraries forwarded")
const M = inv([2.0 1.0; 1.0 3.0])
println(Core.stdout, "at load: ", M[1, 1])
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "M ", M[1, 1])
    return 0
end
