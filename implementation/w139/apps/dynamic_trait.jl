# E-364 (c): a member stored as Dynamic{Shape}.
include("geometry_trait.jl")
struct Scene
    item::Dynamic{Shape}
end
function (@main)(args::Vector{String})::Cint
    sc = Scene(Dynamic{Shape}(length(args) > 0 ? Rect(2.0, 3.0) : Circle(1.0)))
    println(Core.stdout, report(sc.item))
    return 0
end
