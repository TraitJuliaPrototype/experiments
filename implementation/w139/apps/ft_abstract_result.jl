# W-142: a function whose result is of an abstract type that is no trait, never called on.
include("geometry_trait.jl")
struct Holder; x::Real; end
get(h::Holder) = h.x                      # an abstract result
keepit(h::Holder) = (get(h); 1)
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, keepit(Holder(length(args))))
    return 0
end
