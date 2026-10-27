module P6
using TraitWorld
@trait_module module Impl
using TraitWorld
go() = vcat(1, [2, 3])
end
go() = Impl.go()
end
