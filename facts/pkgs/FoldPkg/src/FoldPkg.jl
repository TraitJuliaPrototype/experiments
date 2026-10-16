# A precompiled trait package whose image holds code compiled under the policy that folds a
# `return_type` (an empty map's element type) and calls Base at a concrete signature: a winning
# method defined before the image loads must make the image's code fail verification (final review, 5).
module FoldPkg
using TraitWorld
@trait_module module FoldCore
using TraitWorld
export Cnt2, cv, emptymap, clampsum
@trait Cnt2 begin
    cv(c::Cnt2)::Int
end
@implement Cnt2 Int begin
    cv(c) = c
end
emptymap(c::Cnt2) = map(x -> clamp(x, 0, cv(c)), Int[])
clampsum(c::Cnt2) = clamp(cv(c), 0, 10) + 0
end
using .FoldCore
export emptymap, clampsum
emptymap(3); clampsum(3)                 # the workload: compiled into the image
end
