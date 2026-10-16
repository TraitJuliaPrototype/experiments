include(joinpath(@__DIR__, "h.jl"))

# ---- C13 concrete evaluation of a pure function, then redefined
module C13; pure(x) = x + 1; end
k13() = C13.pure(1)
@wrap w13 k13
check("C13 concrete eval before", res(k13), P(k13), res(w13))
@eval C13 pure(x) = x + 100
check("C13 concrete eval after redefinition", res(k13), P(k13), res(w13))

# ---- C14 @assume_effects :foldable over an abstract site
module C14
g(x) = 1
Base.@assume_effects :foldable h(x::Int) = g(Base.inferencebarrier(x))
end
k14() = C14.h(1)
@wrap w14 k14
check("C14 assume_effects foldable before", res(k14), P(k14), res(w14))
@eval C14 g(x) = 2
check("C14 assume_effects foldable after callee redefinition", res(k14), P(k14), res(w14))
@eval C14 g(x::Int) = 3
check("C14 assume_effects foldable after callee specific method", res(k14), P(k14), res(w14))

# ---- C15 return_type at an abstract signature inside a foldable helper (UNKNOWN effects claim)
module C15; g(x) = 1; end
rt15() = Base.promote_op(C15.g, Integer)
k15() = rt15()
@wrap w15 k15
check("C15 promote_op(abstract) via helper before", res(k15), P(k15), res(w15))
@eval C15 g(x) = 1.5
check("C15 promote_op(abstract) via helper after", res(k15), P(k15), res(w15))
@eval C15 g(x::Int) = "s"
check("C15 promote_op(abstract) via helper after specific", res(k15), P(k15), res(w15))

# ---- C15b same with return_type 2-arg and direct worker
module C15b; g(x) = 1; end
k15b() = Core.Compiler.return_type(Tuple{typeof(C15b.g), Integer})
@wrap w15b k15b
check("C15b return_type 2-arg abstract direct before", res(k15b), P(k15b), res(w15b))
@eval C15b g(x) = 1.5
check("C15b return_type 2-arg abstract direct after", res(k15b), P(k15b), res(w15b))

# ---- C16 return_type fold at Type{Int} (compilation-signature widening)
module C16; pass(t) = t; passf(f) = f; ns(@nospecialize x) = x; vaa(xs...) = xs; usetype(t) = (t, 1); end
k16() = Base.promote_op(C16.pass, Type{Int})
@wrap w16 k16
check("C16 promote_op at Type{Int}", res(k16), P(k16), res(w16))
k17() = Base.promote_op(C16.passf, typeof(sin))
@wrap w17 k17
check("C17 promote_op at a Function type", res(k17), P(k17), res(w17))
k18() = Base.promote_op(C16.ns, Int)
@wrap w18 k18
check("C18 promote_op at @nospecialize", res(k18), P(k18), res(w18))
k19() = Base.promote_op(C16.vaa, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)
@wrap w19 k19
check("C19 promote_op vararg long", res(k19), P(k19), res(w19))
k19b() = Base.promote_op(C16.usetype, Type{Int})
@wrap w19b k19b
check("C19b promote_op Type passed into tuple", res(k19b), P(k19b), res(w19b))
# map over empty arrays of such element types
k19c() = map(C16.pass, Type{Int}[])
@wrap w19c k19c
check("C19c map over empty Type{Int}[]", res(()->typeof(k19c())), res(()->typeof(TraitWorld._facts_call(k19c))), res(()->typeof(w19c())))
k19d() = map(C16.passf, typeof(sin)[])
@wrap w19d k19d
check("C19d map over empty typeof(sin)[]", res(()->typeof(k19d())), res(()->typeof(TraitWorld._facts_call(k19d))), res(()->typeof(w19d())))

# ---- C20 broadcast / map / comprehension element types, empty and non-empty, before/after
module C20; g(x) = 1; end
k20(v) = (eltype(C20.g.(v)), eltype(map(C20.g, v)), eltype([C20.g(x) for x in v]), eltype(collect(Iterators.map(C20.g, v))))
@wrap w20 k20
for (lbl, v) in (("Int[]", Int[]), ("Integer[]", Integer[]), ("Any[]", Any[]), ("Union[]", Union{Int,Nothing}[]), ("Integer[1]", Integer[1]), ("Any[1,2.0]", Any[1, 2.0]))
    check("C20 eltypes $lbl before", res(()->k20(v)), P(k20, v), res(()->w20(v)))
end
@eval C20 g(x) = 1.5
for (lbl, v) in (("Int[]", Int[]), ("Integer[]", Integer[]), ("Any[]", Any[]), ("Union[]", Union{Int,Nothing}[]), ("Integer[1]", Integer[1]), ("Any[1,2.0]", Any[1, 2.0]))
    check("C20 eltypes $lbl after", res(()->k20(v)), P(k20, v), res(()->w20(v)))
end
@eval C20 g(x::Int) = nothing
for (lbl, v) in (("Int[]", Int[]), ("Integer[]", Integer[]), ("Union[]", Union{Int,Nothing}[]), ("Integer[1]", Integer[1]))
    check("C20 eltypes $lbl after specific", res(()->k20(v)), P(k20, v), res(()->w20(v)))
end

# ---- C21 return_type 3-arg with a constant closure
k21() = (a = 1; Base.promote_op(x -> a == 1 ? 1 : 1.0, Int))
@wrap w21 k21
check("C21 promote_op const closure", res(k21), P(k21), res(w21))

# ---- C22 infer_return_type at run time
module C22; g(x) = 1; end
k22() = Base.infer_return_type(C22.g, (Integer,))
@wrap w22 k22
check("C22 infer_return_type before", res(k22), P(k22), res(w22))
@eval C22 g(x) = 1.5
check("C22 infer_return_type after", res(k22), P(k22), res(w22))

summary()
