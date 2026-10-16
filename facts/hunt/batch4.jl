include(joinpath(@__DIR__, "h.jl"))
const CC = Base.Compiler

# ---- diagnosis C14: is the facts CI of the worker a folded constant, and what edges does h's facts CI hold?
module D14
g(x) = 1
Base.@assume_effects :foldable h(x::Int) = g(Base.inferencebarrier(x))
end
k14() = D14.h(1)
println("k14 policy: ", TraitWorld._facts_call(k14))
ci = TraitWorld.facts_codeinstance(Tuple{typeof(k14)})
println("k14 facts CI: rettype=", ci.rettype, " const=", isdefined(ci, :rettype_const) ? ci.rettype_const : "-", " edges=", ci.edges)
cih = TraitWorld.facts_codeinstance(Tuple{typeof(D14.h), Int})
println("h facts CI edges: ", cih.edges, "  effects foldable: ", CC.is_foldable(CC.decode_effects(cih.ipo_purity_bits)))
nh = Base.invokelatest(CC.typeinf_ext_toplevel, CC.NativeInterpreter(Base.get_world_counter()), cih.def, CC.SOURCE_MODE_NOT_REQUIRED)
println("h native CI edges: ", nh.edges)
@eval D14 g(x) = 2
println("after: plain ", k14(), " policy ", TraitWorld._facts_call(k14), "; h itself under policy: ", TraitWorld._facts_call(D14.h, 1))

# ---- diagnosis C16: the method instance the fold reads
module D16; passf(f) = f; ns(@nospecialize x) = x; pass(t) = t; vaa(xs...) = xs; end
for sig in (Tuple{typeof(D16.passf), typeof(sin)}, Tuple{typeof(D16.ns), Int}, Tuple{typeof(D16.pass), Type{Int}},
            Tuple{typeof(D16.vaa), Int, Int, Int, Int, Int, Int, Int, Int, Int, Int})
    mi = ccall(:jl_method_lookup_by_tt, Any, (Any, Csize_t, Any), sig, Base.get_world_counter(), nothing)
    println(sig, "\n   lookup MI specTypes: ", mi.specTypes, "\n   native return_type: ", Core.Compiler.return_type(sig))
end

# ---- C33 Type{Vector} (UnionAll inside Type) signatures
module C33; f(::Type{<:AbstractVector}) = 1; end
k33() = C33.f(Vector)
@wrap w33 k33
check("C33 Type{Vector} before", res(k33), P(k33), res(w33))
@eval C33 f(::Type{Vector}) = 2
check("C33 Type{Vector} after", res(k33), P(k33), res(w33))
k33b() = C33.f(Vector{Int})
@wrap w33b k33b
check("C33b Type{Vector{Int}} before", res(k33b), P(k33b), res(w33b))
@eval C33 f(::Type{Vector{T}}) where {T} = 3
check("C33b Type{Vector{Int}} after", res(k33b), P(k33b), res(w33b))

# ---- C34 generated function whose generator calls return_type
module C34; g(x) = 1; @generated gen(x) = (T = Core.Compiler.return_type(g, Tuple{x}); :($T)); end
k34(x) = C34.gen(x)
@wrap w34 k34
check("C34 generator return_type before", res(()->k34(1)), P(k34, 1), res(()->w34(1)))
@eval C34 g(x::Int) = 1.5
check("C34 generator return_type after", res(()->k34(1)), P(k34, 1), res(()->w34(1)))

# ---- C35 Base.@pure (now :foldable) over an abstract call
module C35; g(x) = 1; Base.@pure p(x::Int) = g(Ref{Any}(x)[]); end
k35() = C35.p(1)
@wrap w35 k35
check("C35 @pure before", res(k35), P(k35), res(w35))
@eval C35 g(x) = 2
check("C35 @pure after", res(k35), P(k35), res(w35))

# ---- C36 :foldable callee with a concrete inner call (control: edges should exist)
module C36; g(x) = 1; Base.@assume_effects :foldable h(x::Int) = g(x); end
k36() = C36.h(1)
@wrap w36 k36
check("C36 foldable concrete inner before", res(k36), P(k36), res(w36))
@eval C36 g(x) = 2
check("C36 foldable concrete inner after", res(k36), P(k36), res(w36))

# ---- C37 semi-concrete: foldable callee with one non-constant arg
module C37; g(x) = 1; Base.@assume_effects :foldable h(x::Int, y::Int) = g(Base.inferencebarrier(x)) + 0 * y; end
k37(y) = C37.h(1, y)
@wrap w37 k37
check("C37 semi-concrete before", res(()->k37(5)), P(k37, 5), res(()->w37(5)))
@eval C37 g(x) = 2
check("C37 semi-concrete after", res(()->k37(5)), P(k37, 5), res(()->w37(5)))

# ---- C38 in a trait module: the two failure classes reached from trait code
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)
module X38; g(x) = 1; Base.@assume_effects :foldable h(x::Int) = g(Base.inferencebarrier(x)); ns(@nospecialize x) = x; end
toplevel(quote
    @trait_module module TM38
    using TraitWorld
    export Cnt38, cv38, fold38, elt38
    @trait Cnt38 begin
        cv38(c::Cnt38)::Int
    end
    @implement Cnt38 Int begin
        cv38(c) = c
    end
    fold38(c::Cnt38) = cv38(c) + Main.X38.h(1)
    elt38(c::Cnt38) = (cv38(c); string(eltype(Main.X38.ns.(Int[]))))
    end
end)
using .TM38
check("C38 trait module: elt38", res(()->string(eltype(X38.ns.(Int[])))), res(()->TM38.elt38(1)))
check("C38 trait module: fold38 before", res(()->1 + X38.h(1)), res(()->TM38.fold38(1)))
@eval X38 g(x) = 100
check("C38 trait module: fold38 after", res(()->1 + X38.h(1)), res(()->TM38.fold38(1)))

summary()
