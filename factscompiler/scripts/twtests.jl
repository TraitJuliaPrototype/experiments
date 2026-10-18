# TraitWorld's test suite with the compiler copy compiling everything (JULIA_FACTS_COMPILER=1 for
# facts mode) and TraitWorld's own interpreter off (JULIA_TW_FACTS=0): the configuration in which the
# policy is the compiler's.   julia --project=benv scripts/twtests.jl
using Compiler
Compiler.activate!(; reflection = true, codegen = true)
println("facts mode: ", Compiler.FACTS_MODE[], "; TraitWorld's interpreter: ", get(ENV, "JULIA_TW_FACTS", "1"))
const TWTEST = joinpath(dirname(dirname(pathof(Base.require(Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld"))))), "test")
cd(TWTEST)
include(joinpath(TWTEST, "runtests.jl"))
