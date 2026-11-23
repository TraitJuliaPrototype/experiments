# a kept form is a member of its set by a pattern bounded by the set (`Compiled{Z} where Z <: X`), so
# whether `Compiled{S}` is in `X` rests on `S`'s memberships: its non-membership is not final
@set KfX
@set KfY
struct KfS end
member!(KfX, let Z = TypeVar(:Z, KfX); UnionAll(Z, Core.Compiled{Z}) end)
member!(KfX, let Z = TypeVar(:Z, KfX); UnionAll(Z, Core.Dynamic{Z}) end)
kfqc() = Core.Compiled{KfS} <: KfX
kfqd() = Core.Dynamic{KfY} <: KfX
@test kfqc() === false && kfqd() === false
member!(KfX, KfS)
@test kfqc() === true                                  # compiled before the membership
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), KfS, KfX, @__MODULE__)
@test kfqc() === false
member!(KfX, KfY)

@testset "a type in a pattern bounded by a set is no final non-member" begin
    @test kfqd() === true                                # compiled before the membership
    @test (Core.Compiled{KfS} <: KfX) === false
end

# the kept forms are ordinary structs, members of a set only by a membership a library declares; an
# argument typed by a set that names the method's variables, compiled once, is compiled at that instance
# with the variables' values
@set KpX
@set KpP T
struct KpS end
member!(KpP{Int}, KpS)
kpvar(@nospecialize(x::KpP{T})) where {T} = T              # compiled once, at the instance
@test kpvar(KpS()) === Int

@testset "the kept forms Dynamic{X} and Compiled{T}" begin
    for K in (Core.Dynamic, Core.Compiled)
        @test isstructtype(K) && !ismutabletype(K) && fieldnames(K) == (:object,)
    end
    @test !(Core.Dynamic{KpX} <: KpX) && !(Core.Compiled{KpS} <: KpX)
    @test ccall(:jl_is_trait_arg_type, Cint, (Any,), KpP{Int}) == 1
    @test ccall(:jl_is_trait_arg_type, Cint, (Any,), Int) == 0
    @test ccall(:jl_set_erases, Cint, (Any,), Core.Callable) == 1 && ccall(:jl_set_erases, Cint, (Any,), KpX) == 0
    @test Tuple{typeof(kpvar), KpP{Int}} in Set(mi.specTypes for mi in Base.specializations(only(methods(kpvar))))
    @test only(methods(kpvar)) in ccall(:jl_open_set_methods_of, Any, (Any,), KpP)
end
