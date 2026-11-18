# Probe: specificity and intersection of instances of one set (compiler §4.9, §5.2)
using Traits
const C = Core.Callable
ms(a, b) = Base.morespecific(Tuple{a}, Tuple{b})
for (a, b) in ((C{Tuple{Int},Int}, C{Tuple{String},String}),
               (C{Tuple{Int},Int}, C{Tuple{Integer},Integer}),
               (C{Tuple{Int},Int}, C{Tuple{Int},Integer}),
               (C{Tuple{Int},Int}, C{Tuple{T},T} where T),
               (C{Tuple{Int},Int}, C),
               (Core.All{Tuple{C{Tuple{Int},Int}, C{Tuple{String},String}}}, C{Tuple{Int},Int}))
    println(a, " vs ", b, ": ms=", ms(a, b), "/", ms(b, a), " ti=", typeintersect(a, b))
end
