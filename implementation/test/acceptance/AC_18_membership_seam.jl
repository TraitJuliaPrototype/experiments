# AC-18 (new; §8 — the membership seam): a marked caller at a member compiled
# AFTER the declare uses the task's query world (compiler §4.11); pin (i) the
# dispatch edge at the concrete member signature, (ii) ci.min_world >=
# entry.min_world, (iii) the entry itself in the record, a positive membership
# (compiler §3.1, §4.8), and (iv) the non-member abstract query as a run-time
# site (no pair, rettype Any, nortsite false — later members answered
# dynamically).
include("ac_util.jl")
using Traits

@trait S18
g18(::S18) = :set
struct M18 end
e18 = @implement S18 M18
mk18(m::M18) = g18(m)
mk18b(v::Vector{Any}) = g18(v[1])           # abstract query over the set function
mark!(mk18)
mark!(mk18b)

@assert mk18(M18()) === :set
@assert mk18b(Any[M18()]) === :set "the abstract query answers dynamically"

ci = only([c for c in all_cis(mk18) if c.min_world > 0 && c.owner === nothing])
# the fact at the concrete member signature: an edge at g18's method instance for M18
callee_mi(e) = e isa Core.CodeInstance ? e.def : e
haspair = any(e -> (mi = callee_mi(e); mi isa Core.MethodInstance && mi.specTypes === Tuple{typeof(g18), M18}), ci.edges)
@assert haspair "dispatch edge at the concrete member sig: $(collect(ci.edges))"
@assert ci.min_world >= e18.min_world "world bound above the declare: $(ci.min_world) >= $(e18.min_world)"
# (re-judged with W-141, compiler §5.6: the record names the membership by its method, an instance of
# `Core.implements` at the pair, not by its entry)
impl_edges(ci) = [mi.specTypes for mi in (callee_mi(e) for e in ci.edges) if mi isa Core.MethodInstance && mi.def isa Method && mi.def.name === :implements]
fes = impl_edges(ci)
@assert length(fes) == 1 "exactly one positive membership: $(collect(ci.edges))"
@assert fes[1] === Tuple{typeof(Core.implements), Type{S18}, Type{M18}} "the record names the membership's method: $(fes[1])"

cib = only([c for c in all_cis(mk18b) if c.min_world > 0 && c.owner === nothing])
@assert cib.rettype === Any "abstract query over the set: rettype Any, got $(cib.rettype)"
@assert !any(1:length(cib.edges)-1) do i
    s = cib.edges[i]
    s isa DataType && s.name === Tuple.name && s.types[1] === typeof(g18)
end "the abstract query records no dispatch pair: $(collect(cib.edges))"
@assert !Compiler.decode_effects(cib.ipo_purity_bits).nortsite "nortsite false at the set-abstract site"

# a member declared LATER is followed at the run-time site without recompilation
struct N18 end
@implement S18 N18
@assert mk18b(Any[N18()]) === :set "the later member answers dynamically"
@assert cib.max_world === typemax(UInt) "bounds untouched at the run-time site: $(cib.max_world)"

ac_finish(@__FILE__)
