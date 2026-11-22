# W-143e (E-541): what plain code sees of the two declarations (`_promote_typesubtract`, `fieldname`'s
# `throw_field_access` declared `@nospecializeinfer`): inference's answers where they are used, the instances made, the
# results and the error message. Run on vanilla v1.13.2, the head and the branch; the lines must agree but for the
# instance counts.      julia --startup-file=no motiv/plainfx.jl
println("julia ", Base.GIT_VERSION_INFO.commit_short)
rt(f, T) = Base.infer_return_type(f, T)
println("promote_typejoin(::Type{Int}, ::Type{Nothing}) inferred: ", rt(Base.promote_typejoin, (Type{Int}, Type{Nothing})))
println("promote_typejoin(Int, Nothing) with constants inferred: ", rt(() -> Base.promote_typejoin(Int, Nothing), ()))
println("[x, nothing] inferred: ", rt(x -> [x, nothing], (Int,)), " | [x, missing, 1.0]: ", rt(x -> [x, missing, 1.0], (Int,)))
println("collect of a generator over Any inferred: ", rt(v -> collect(x for x in v), (Vector{Any},)))
println("map(identity, Any[1, nothing]): ", typeof(map(identity, Any[1, nothing])), " | [1, nothing, missing]: ", typeof([1, nothing, missing]))
println("Base.promote_typejoin(Union{Int, Nothing}, Missing): ", Base.promote_typejoin(Union{Int, Nothing}, Missing))
println("fieldname(Complex{Int}, 3): ", try fieldname(Complex{Int}, 3) catch e; sprint(showerror, e) end)
println("fieldname(Complex{Int}, 2): ", fieldname(Complex{Int}, 2))
inst(f) = [mi.specTypes for m in methods(f) for mi in Base.specializations(m)]
println("instances of _promote_typesubtract in this session: ", length(inst(Base._promote_typesubtract)), " ", inst(Base._promote_typesubtract))
