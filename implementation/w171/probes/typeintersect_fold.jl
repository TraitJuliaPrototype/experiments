# W-171 (E-542): `typeintersect` and `==` of types assert their consistency (`@_total_meta`): with constant types in
# which a set occurs they were evaluated at compile time, and the answer kept after a membership.
#     julia --project=experiments/implementation typeintersect_fold.jl
using Traits
@trait QX
struct QS end
const RS = Ref{QS}
const RX = Ref{T} where T<:QX
ti() = typeintersect(QS, QX) === Union{}
ti2() = typeintersect(RS, RX) === Union{}
eq() = (Ref{T} where T>:QX) == (Ref{T} where T>:Union{QX,QS})
sb() = QS <: QX
println("before: ti ", ti(), " ti2 ", ti2(), " eq ", eq(), " sb ", sb())
e = @implement QX QS
println("after: ti ", ti(), " ti2 ", ti2(), " eq ", eq(), " sb ", sb())
println("fresh: ", typeintersect(Base.inferencebarrier(QS), QX), " ", typeintersect(Base.inferencebarrier(RS), RX))
