using TraitWorld, Test
@trait_module module CM
using TraitWorld
@trait Sz begin
    wd(s::Self)::Int
end
struct A; w::Int; end                  # default A(w) converts
A(s::Sz) = A(wd(s))
struct B{T}; w::T; end                 # default B(w::T) where T
B(s::Sz) = B(wd(s) * 10)
struct C
    w::Int
    C(x; k = 1) = new(length(x) * k)   # untyped inner with keywords
end
C(s::Sz) = C(fill(0, wd(s)); k = 2)
struct D
    w::Int
    D(x, y::Int) = new(x + y)          # untyped in one position, typed in the other
end
D(s::Sz, y::Int) = D(wd(s), y)
struct E; w::Int; end
E(s::Sz; add = 0) = E(wd(s) + add)     # bounded with keywords; default E(w) the fallback
end
struct Sf; w::Int; end
@implement CM.Sz Sf begin
    wd(s) = s.w
end
typed_a(s::Sf) = CM.A(s)
s = Sf(3)
@test CM.A(s) == CM.A(3)
@test CM.A(2.0) == CM.A(2)
@test_throws InexactError CM.A(2.5)
@test CM.A(Int8(4)).w === 4
@test Base.inferencebarrier(CM.A)(Base.inferencebarrier(2.0)) == CM.A(2)
@test CM.B(s) isa CM.B{Int} && CM.B(s).w == 30
@test CM.B(1.5) isa CM.B{Float64}
@test CM.B{Float64}(2) isa CM.B{Float64}
@test CM.C(s).w == 6
@test CM.C([1,2]).w == 2
@test CM.C([1,2]; k = 3).w == 6
@test_throws MethodError CM.C(s; k = 3)
@test CM.D(s, 1).w == 4
@test CM.D(1.0, 2).w == 3
@test CM.E(s).w == 3
@test CM.E(s; add = 2).w == 5
@test CM.E(2.0).w == 2
@test_throws MethodError CM.E(2.0; add = 1)
@test typed_a(s) == CM.A(3)
@test Base.return_types(typed_a, (Sf,)) == Any[CM.A]
println(methods(CM.A))
