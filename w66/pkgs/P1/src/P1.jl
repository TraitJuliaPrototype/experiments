module P1
using TraitWorld
import M1
@trait_module module Impl
using TraitWorld
import M1
go() = M1.@val() + 0
end
go() = Impl.go()
end
