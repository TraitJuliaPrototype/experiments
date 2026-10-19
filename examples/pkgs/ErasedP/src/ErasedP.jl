"A package that keeps a `DynamicFn` as a constant: its pointer is saved in the image (correctness item 2)."
module ErasedP
using TraitWorld
twice(x::Float64) = 2x
const D = TraitWorld.dynamic_fn(Tuple{Float64}, Float64, twice)
call(x) = D(x)
call(1.0)              # called while the image is built: compiled code that holds the constant
end
