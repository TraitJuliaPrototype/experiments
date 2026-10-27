module P4
using TraitWorld
import Q4
@trait_module module Impl
using TraitWorld
import Q4
go() = Q4.h()
end
go() = Impl.go()
end
