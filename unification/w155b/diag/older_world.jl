# W-155b (D-13's gate): a task in an older world after a membership is taken back: which method a call there
# selects, by dispatch, by `which` and by the method table's matches.
using TraitWorld
module DS
    using TraitWorld
    @trait_module bounded = false
    @trait DShape begin
        darea(s::DShape)::Float64
    end
    struct Circ; r::Float64; end
    darea(c::Circ) = 3.0 * c.r^2
    @implement DShape Circ
    describe(s::DShape) = "a shape"
    describe(x) = "other"
    calldesc(c::Circ) = describe(c)
end
c = DS.Circ(1.0)
@show Base.invokelatest(DS.calldesc, c)
w = Base.get_world_counter()
delete_membership(DS.DShape, DS.Circ)
@show w Base.get_world_counter()
@show Base.invoke_in_world(w, isa, c, DS.DShape)
@show Base.invoke_in_world(w, DS.describe, c)
@show Base.invoke_in_world(w, DS.calldesc, c)
@show Base.invoke_in_world(w, which, DS.describe, (DS.Circ,))
ms = Base._methods_by_ftype(Tuple{typeof(DS.describe), DS.Circ}, -1, w)
@show [m.method.sig for m in ms]
@show Base.invokelatest(DS.describe, c)
@show Base.invokelatest(DS.calldesc, c)
# a fresh call in the older world, never cached before the deletion
Core.eval(DS, :(describe2(s::DShape) = "a shape"; describe2(x) = "other"))
