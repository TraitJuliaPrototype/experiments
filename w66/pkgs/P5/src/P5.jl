module P5
using TraitWorld
import X5
@trait_module module Impl
using TraitWorld
import X5
go() = X5.g5(X5.T5())
end
go() = Impl.go()
end
