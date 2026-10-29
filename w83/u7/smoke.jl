# smoke test: one fold of each kind
using TraitWorld
f(x) = x isa AbstractDict ? 1 : 2
g(x) = x isa TraitWorld.BaseTraits.Iterable ? 1 : 2
function h(v)
    s = 0
    for x in v
        s += x isa TraitWorld.BaseTraits.HasLength ? 1 : 0
    end
    s
end
@show f(1) g(1.0) h([1, 2])
