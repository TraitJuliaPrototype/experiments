module P2
using TraitWorld
import L2
@trait_module module Impl
using TraitWorld
import L2
go() = sizeof(L2.S)
end
go() = Impl.go()
end
