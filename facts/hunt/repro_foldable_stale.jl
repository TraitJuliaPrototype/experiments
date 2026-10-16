# FAIL 1: concrete evaluation of an effects-asserted callee folds a constant with no edge to its run-time site
using TraitWorld
module M
g(x) = 1
Base.@assume_effects :foldable h(x::Int) = g(Base.inferencebarrier(x))   # same with Base.@pure
end
k() = M.h(1)
w() = TraitWorld._facts_call(k)
println("before: plain ", k(), "  policy ", w())          # 1 1
@eval M g(x) = 2
println("after:  plain ", k(), "  policy ", w())          # 2 1   <- stale
println("h called directly under the policy: ", TraitWorld._facts_call(M.h, 1))   # 2
