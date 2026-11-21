# Open issue 251, two side cases met by the corpus (run from the library's worktree: $JN --project=. sidecases.jl):
# 1. a call of a global the module never defines (the library's test `mfvok`, test/messages.jl): the check's verdict;
# 2. `hasproperty` at a box of a trait without the field: does inference fold it (the guard of ODECore's `_mass_matrix`)?
using TraitWorld
module MsgLib
using TraitWorld
@trait_module bounded
@trait MShape begin
    marea(s::MShape)::Float64
end
end
module MB
using TraitWorld
using ..MsgLib: MShape
@trait_module
mfvok(a::MShape, ts::MShape...) = marea(a) + sum(marea, ts)
end
println("1. MB defines marea: ", isdefined(MB, :marea), "; the check at the module's end accepted mfvok: ", isdefined(MB, :mfvok),
        "; check_at_box: ", TraitWorld.check_at_box(only(methods(MB.mfvok))))
struct Obj; end
MsgLib.marea(::Obj) = 1.0
@implement MsgLib.MShape Obj
println("   mfvok(Obj()) raises: ", try MB.mfvok(Obj()); "nothing" catch e; typeof(e) end)
D = Dynamic{MsgLib.MShape}
println("2. inferred: hasproperty(::", D, ", :mass_matrix) => ", Base.infer_return_type(d -> hasproperty(d, :mass_matrix), (D,)),
        "; propertynames => ", Base.infer_return_type(propertynames, (D,)),
        "; value ", hasproperty(D(Obj()), :mass_matrix))
