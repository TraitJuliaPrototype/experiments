# AC-20 (R-14, B-F8; re-judged to compiler §3.1, §4.4, §4.8): the COMPOSED-CHAIN
# membership — S20 ∈ Z20 and Z20 ∈ X20; a marked caller at S20 calling a method
# written at X20 resolves through the chain, and the record names BOTH links'
# entries (a positive membership rests on each link). The composed query holds
# from the later link's world and fails below it, so the code's bound is the
# right bound. `jl_membership_entries_for` answers the same entries in the
# world, none below the chain's top.
include("ac_util.jl")
using Traits

@trait X20
@trait Z20
struct S20 end
probe20(s) = s isa X20                # defined before the memberships, so older worlds can call it
ez20 = @implement Z20 S20             # S -> Z
ex20 = @implement X20 Z20             # Z -> X  (declared later: the chain's top)
hh20(::X20) = :via
mc20(s::S20) = hh20(s)
mark!(mc20)

@assert mc20(S20()) === :via "the chain answers"

ci = only([c for c in all_cis(mc20) if c.min_world > 0 && c.owner === nothing])
# (re-judged with W-141, compiler §5.6: the record names each link by its membership's method)
callee_mi0(e) = e isa Core.CodeInstance ? e.def : e
fes = [mi.specTypes for mi in (callee_mi0(e) for e in ci.edges) if mi isa Core.MethodInstance && mi.def isa Method && mi.def.name === :implements]
@assert length(fes) == 2 && any(t -> t === Tuple{typeof(Core.implements), Type{Z20}, Type{S20}}, fes) "both links' methods in the record: $(collect(ci.edges))"
@assert ex20.set === X20.name && ex20.member === Z20 "the top entry names (Z20, X20)"
@assert ci.min_world >= ex20.min_world "bound: CI $(ci.min_world) >= top entry $(ex20.min_world)"

callee_mi(e) = e isa Core.CodeInstance ? e.def : e
haspair = any(e -> (mi = callee_mi(e); mi isa Core.MethodInstance && mi.specTypes === Tuple{typeof(hh20), S20}), ci.edges)
@assert haspair "dispatch edge at the concrete member sig: $(collect(ci.edges))"

# the composed query world-semantics: holds at the top entry's min_world, fails below
@assert Base.invoke_in_world(ex20.min_world, probe20, S20()) === true "chain holds at its top's min_world"
@assert Base.invoke_in_world(ex20.min_world - 1, probe20, S20()) === false "below it, no chain"

# the entries a positive answer rests on, in a world and below the chain's top
ents = ccall(:jl_membership_entries_for, Any, (Any, Any, Csize_t), S20, X20, curworld())
@assert Set(ents) == Set([ez20, ex20]) "jl_membership_entries_for answers both links: got $ents"
ents_below = ccall(:jl_membership_entries_for, Any, (Any, Any, Csize_t), S20, X20, ex20.min_world - 1)
@assert isempty(ents_below) "below the top entry's world no chain, so no entry: got $ents_below"

ac_finish(@__FILE__)
