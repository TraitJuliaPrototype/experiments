# W-171: `applicable` folded true through a membership; the membership taken back
using Traits
@trait X
struct S end
h(::X) = :hB
q(x) = applicable(h, x)
hm() = hasmethod(h, Tuple{S})
dump_cis(f) = for mi in Base.specializations(only(methods(f))); c = mi.cache; while true; println("  ", f, " ", Int(c.min_world), ":", c.max_world == typemax(UInt) ? "∞" : Int(c.max_world), " ", c.edges, " ", isdefined(c, :rettype_const) ? c.rettype_const : c.rettype); isdefined(c, :next) || break; c = c.next; end; end
e = @implement X S
println("member: q ", q(S()), " hm ", hm()); dump_cis(q); dump_cis(hm)
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, X, @__MODULE__)
println("taken back: q ", q(S()), " hm ", hm(), " fresh ", applicable(Base.inferencebarrier(h), Base.inferencebarrier(S())), " ", hasmethod(Base.inferencebarrier(h), Base.inferencebarrier(Tuple{S})))
dump_cis(q); dump_cis(hm)
