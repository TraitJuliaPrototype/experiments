#!/bin/bash
# W-166c (E-509): bash workload_guards.sh [dir...] -- top-level code a package runs while Julia generates *any* output,
# guarded by `jl_generating_output() == 1` alone (or PrecompileTools' `@compile_workload`, whose guard is the same).
# Such code runs where the package's image is built (incremental: every dependency's `__init__` has run) and also in a
# trimmed build that loads the package from source (not incremental: no `__init__` has run), where a call into a
# JLL's library or into BLAS/LAPACK fails. A guard `Base.generating_output(true)` runs it only for the image.
# Default dirs: the library and the demonstrators of the workspace. Lines that also test `incremental` are not listed.
R=$(cd "$(dirname "$0")/../../.." && pwd)
dirs=("$@"); [ ${#dirs[@]} -eq 0 ] && dirs=("$R/TraitWorld/src" "$R/TraitTables/src" "$R/TraitCSV/src" "$R/TraitMakie/src" "$R/TraitReport/src" "$R/TraitDifferentialEquations/src" "$R/TraitDifferentialEquations/lib")
grep -rn --include='*.jl' -E '^\s*(if|@static if)?\s*ccall\(:jl_generating_output, *Cint, *\(\)\) *== *1\s*(#.*)?$|^\s*@compile_workload\b' "${dirs[@]}" \
  | grep -v incremental | sed "s#^$R/##"
