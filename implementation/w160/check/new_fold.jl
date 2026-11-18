# E-436's check of the fold at `new` (W-160; compiler §4.8): where a `new`'s field test holds through a
# membership's entry, the code records an edge on the membership's method and emits no test; a non-member is
# still tested and refused; the constructor `Dynamic{X}(x)` at a known member type.
#     julia --project=<TraitWorld> new_fold.jl
using TraitWorld, InteractiveUtils, Test
module T
using TraitWorld
@trait_module
@trait Model begin
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
end
module U
using TraitWorld
import ..T: Model, rate
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
struct NotMember; k::Float64; end
end
const D = Dynamic{T.Model}
@eval box_new(m::U.Decay) = $(Expr(:new, D, :m))
@eval box_bad(m::U.NotMember) = $(Expr(:new, D, :m))
box_ctor(m::U.Decay) = D(m)
ir(f, tt) = sprint(io -> code_llvm(io, f, tt; debuginfo = :none))
edges_of(f, tt) = (mi = Base.method_instance(f, tt); ci = mi.cache; ci.edges)
implements_edge(es) = any(e -> e isa Core.MethodInstance && e.def isa Method && e.def.name === :implements, es)
@testset "the fold at new" begin
    d = U.Decay(0.5)
    @test box_new(d) isa D
    @test !occursin("ijl_isa", ir(box_new, (U.Decay,)))
    ci = code_typed(box_new, (U.Decay,))[1][1]
    k = findfirst(st -> Meta.isexpr(st, :new), ci.code)
    @test k !== nothing && (ci.ssaflags[k] & (UInt32(1) << 5)) != 0         # nothrow: the test proved
    @test implements_edge(edges_of(box_new, (U.Decay,)))                    # with the membership's edge
    # a non-member: the test stays, and refuses it
    @test occursin("ijl_isa", ir(box_bad, (U.NotMember,))) || occursin("type_error", ir(box_bad, (U.NotMember,)))
    @test_throws TypeError box_bad(U.NotMember(1.0))
    # the constructor at a known member: no run-time membership query left?
    @test box_ctor(d) isa D
    println("constructor IR has ijl_isa: ", occursin("ijl_isa", ir(box_ctor, (U.Decay,))))
end
