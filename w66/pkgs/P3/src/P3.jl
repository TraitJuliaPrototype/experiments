module P3
using TraitWorld
import A3
import B3
@trait_module module Impl
using TraitWorld
import A3
import B3
go() = A3.f3(B3.C())
end
go() = Impl.go()
end
