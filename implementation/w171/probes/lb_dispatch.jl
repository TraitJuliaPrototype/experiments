# W-171: dispatch at a method whose signature names the set only in a variable's lower bound; the path S in Yc in X,
# the first link taken back
using Traits
@trait X
@trait Yc
struct S end
struct Ph{T} end
const B = Ph{T} where T>:S
h(::B) = :hB
v = Ph{X}()
look(x) = Base._which(Tuple{typeof(h), typeof(x)}; world = Base.tls_world_age(), raise = false) !== nothing
hm(x) = hasmethod(Base.inferencebarrier(h), Base.inferencebarrier(Tuple{typeof(x)}))
sub(x) = Base.inferencebarrier(typeof(x)) <: Base.inferencebarrier(B)
show3(tag) = println(rpad(tag, 24), "which ", look(v), "  hasmethod ", hm(v), "  subtype ", sub(v))
show3("start")
@implement Yc S;  show3("S in Yc")
@implement X Yc;  show3("Yc in X (path)")
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, Yc, @__MODULE__); show3("S in Yc taken back")
tt = Tuple{typeof(h), Ph{X}}
println("after: _methods_by_ftype ", Base._methods_by_ftype(tt, -1, Base.get_world_counter()), "  jl_subtype ", ccall(:jl_subtype, Cint, (Any, Any), tt, Tuple{typeof(h), B}))
