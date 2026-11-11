# A plain package: its image holds h(::S), compiled where PlainG's `f` has one method.
module PlainF
using PlainG
struct S end
h(s) = PlainG.f(s)
precompile(h, (S,))
end
