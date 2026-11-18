using TraitWorld
# the box's call at Dynamic{Callable{A, S}} itself: A and S are the box's own parameters
function (d::Dynamic{Core.Callable{A, S}})(args...) where {A, S}
    args isa A && return TraitWorld._checked_result(getfield(d, :object)(args...), S)
    throw(MethodError(getfield(d, :object), args))
end
include(joinpath(@__DIR__, "..", "check", "callable_path.jl"))
