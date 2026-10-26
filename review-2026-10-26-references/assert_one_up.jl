# G1.10's shape with the method-level assertion one frame above the run-time site.
module Plain
g(x) = 1
h(x::Int) = g(Base.inferencebarrier(x))
Base.@assume_effects :foldable h2(x::Int) = h(x)
kfold() = h2(1)
end
module Facts
Base.Experimental.@compiler_options facts=true
g(x) = 1
h(x::Int) = g(Base.inferencebarrier(x))
Base.@assume_effects :foldable h2(x::Int) = h(x)
kfold() = h2(1)
end
println("before: plain ", Plain.kfold(), ", facts ", Facts.kfold())
Core.eval(Plain, :(g(x) = 2))
Core.eval(Facts, :(g(x) = 2))
println("after redefining g: plain ", Plain.kfold(), ", facts ", Facts.kfold())
# the same with the assertion on the frame that holds the run-time site (G1.10's shape), as a control
module Facts2
Base.Experimental.@compiler_options facts=true
g(x) = 1
Base.@assume_effects :foldable h(x::Int) = g(Base.inferencebarrier(x))
kfold() = h(1)
end
println("control (assertion on the frame with the site): before ", Facts2.kfold())
Core.eval(Facts2, :(g(x) = 2))
println("control after: ", Facts2.kfold())
