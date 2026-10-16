include(joinpath(@__DIR__, "h.jl"))

# ---- C39 return_type where native uses concrete evaluation at a singleton argument
module C39; const TUP = (1, 2.0); h(::Nothing) = TUP[Base.inferencebarrier(1)]; end
k39() = Base.promote_op(C39.h, Nothing)
@wrap w39 k39
check("C39 promote_op singleton arg", res(k39), P(k39), res(w39))
k39b() = typeof(C39.h.(Nothing[]))
@wrap w39b k39b
check("C39b broadcast empty singleton", res(k39b), P(k39b), res(w39b))

# ---- C40 recursion with growing types, leaf redefined
module C40; leaf(x) = 1; rec(x, n) = n == 0 ? leaf(x) : rec((x,), n - 1); end
k40(n) = C40.rec(1, n)
@wrap w40 k40
check("C40 recursion widening before", res(()->k40(6)), P(k40, 6), res(()->w40(6)))
@eval C40 leaf(x::Tuple) = 2
check("C40 recursion widening after", res(()->k40(6)), P(k40, 6), res(()->w40(6)))

# ---- C41 undefined global defined later, isdefined folding
module C41; end
k41() = C41.x
k41b() = (isdefined(C41, :y), @isdefined(zzz41))
@wrap w41 k41
@wrap w41b k41b
check("C41 undefined global before", res(k41), P(k41), res(w41))
check("C41b isdefined before", res(k41b), P(k41b), res(w41b))
@eval C41 x = 5
@eval C41 y = 6
@eval zzz41 = 1
check("C41 undefined global after", res(k41), P(k41), res(w41))
check("C41b isdefined after", res(k41b), P(k41b), res(w41b))

# ---- C42 struct redefinition (binding partitions)
module C42; struct S; a::Int; end; get(s) = s.a; end
k42() = C42.get(C42.S(1))
@wrap w42 k42
check("C42 struct before", res(k42), P(k42), res(w42))
@eval C42 struct S; a::Float64; end
check("C42 struct redefined", res(k42), P(k42), res(w42))

# ---- C43 a method added to a Base function at a concrete signature used by policy code (owner adds)
module C43; struct T; end; end
k43() = (string(C43.T()), length(C43.T()), [C43.T()] == [C43.T()])
@wrap w43 k43
check("C43 Base fns at a new type before", res(k43), P(k43), res(w43))
@eval Base.length(::C43.T) = 7
@eval Base.string(::C43.T) = "T!"
@eval Base.:(==)(::C43.T, ::C43.T) = false
check("C43 Base fns at a new type after", res(k43), P(k43), res(w43))

# ---- C44 a method added to a Base function at an abstract signature reached through Base internals
module C44; struct W <: AbstractVector{Int}; end; Base.size(::W) = (3,); Base.getindex(::W, i::Int) = i; end
k44() = (sum(C44.W()), collect(C44.W()), C44.W() .+ 1)
@wrap w44 k44
check("C44 AbstractArray interface before", res(k44), P(k44), res(w44))
@eval Base.getindex(::C44.W, i::Int) = 10i
check("C44 AbstractArray interface after", res(k44), P(k44), res(w44))
@eval Base.sum(::C44.W) = -1
check("C44 AbstractArray sum overridden", res(k44), P(k44), res(w44))

# ---- C45 show/print through IO (abstract sites in printing)
module C45; struct Q; end; end
k45() = sprint(show, [C45.Q(), C45.Q()])
@wrap w45 k45
check("C45 show before", res(k45), P(k45), res(w45))
@eval Base.show(io::IO, ::C45.Q) = print(io, "Q!")
check("C45 show after", res(k45), P(k45), res(w45))

# ---- C46 promote_rule / convert added later (type-level computations)
module C46; struct N <: Real; v::Int; end; Base.promote_rule(::Type{N}, ::Type{Int}) = Float64; Base.convert(::Type{Float64}, n::N) = Float64(n.v); end
k46() = (promote_type(C46.N, Int), typeof([C46.N(1), 2]))
@wrap w46 k46
check("C46 promote_rule before", res(k46), P(k46), res(w46))
@eval Base.promote_rule(::Type{C46.N}, ::Type{Int}) = Int
@eval Base.convert(::Type{Int}, n::C46.N) = n.v
check("C46 promote_rule after", res(k46), P(k46), res(w46))

# ---- C47 hasmethod with world / applicable on a closure in policy code after Base method
k47(x) = (applicable(length, x), hasmethod(length, Tuple{typeof(x)}))
@wrap w47 k47
check("C47 applicable Base before", res(()->k47(C45.Q())), P(k47, C45.Q()), res(()->w47(C45.Q())))
@eval Base.length(::C45.Q) = 1
check("C47 applicable Base after", res(()->k47(C45.Q())), P(k47, C45.Q()), res(()->w47(C45.Q())))

summary()
