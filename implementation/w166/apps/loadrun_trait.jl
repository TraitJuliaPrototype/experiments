# W-166 (open issue 241): a small trait program that runs trait code while the build loads it: `main` of E-364's
# loop over a `Vector{Shape}` (each item known only by its trait) called at the top level, then built as usual.
include(joinpath(@__DIR__, "..", "..", "w139", "apps", "vector_trait.jl"))
main(String[])
