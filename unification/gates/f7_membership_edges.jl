# Gate (W-100; compiler §3.1, §4.8): a positive answer through a membership entry folds where the
# frame being inferred records it: the entries it rests on join the CodeInstance's edges and its
# worlds start at theirs, so a task in an older world never runs code that assumed the membership.
# At `isa`, `<:` and a dispatch match; a member by `struct S <: X` needs no entry and records none.
using Traits
include("util.jl")

entries(ci) = [e for e in ci.edges if e isa Core.MembershipEntry]
latest(f) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)])
# the code folds the answer to `true` (its result type stays `Bool`, a conditional, as in plain Julia)
folded(f, T) = (src = only(code_typed(f, (T,))).first; src.code[end] == Core.ReturnNode(true))

@trait X7
@trait Z7
struct S7 end            # a direct member
struct C7 end            # a member of Z7, which joins X7: a chain of two entries
struct D7 <: X7 end      # a member by its declared supertype: no entry

# defined before the memberships, so that an older world can call them
isa7(y) = y isa X7
sub7(::Type{T}) where {T} = T <: X7
tup7(t) = t isa Tuple{X7, Int}
g7(::X7) = :set
call7(s) = g7(s)

w_before = curworld()
e_s = @implement X7 S7
e_cz = @implement Z7 C7
e_zx = @implement X7 Z7
@assert e_s.min_world > w_before

# (1) `isa` at a direct member folds to a constant, with the entry in the record
@assert isa7(S7())
ci = latest(isa7)
@assert folded(isa7, S7) "folded: $(code_typed(isa7, (S7,)))"
@assert entries(ci) == [e_s] "the entry in the record: $(entries(ci))"
@assert ci.min_world >= e_s.min_world "worlds start at the entry's: $(ci.min_world) < $(e_s.min_world)"

# (2) an older world compiles its own answer and never runs the folded code
@assert Base.invoke_in_world(w_before, isa7, S7()) === false
@assert isa7(S7()) === true

# (3) a chain: both links in the record, the worlds from the later one
@assert isa7(C7())
cic = only([c for c in all_cis(isa7) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                         c.def.specTypes === Tuple{typeof(isa7), C7}])
@assert Set(entries(cic)) == Set([e_cz, e_zx]) "both links: $(entries(cic))"
@assert cic.min_world >= e_zx.min_world
@assert Base.invoke_in_world(e_zx.min_world - 1, isa7, C7()) === false "below the chain's top, no chain"

# (4) `<:` at a type
@assert sub7(S7)
cis = only([c for c in all_cis(sub7) if c.owner === nothing && c.max_world == typemax(UInt)])
@assert folded(sub7, Type{S7}) && entries(cis) == [e_s]

# (5) a member inside a tuple
@assert tup7((S7(), 1))
cit = only([c for c in all_cis(tup7) if c.owner === nothing && c.max_world == typemax(UInt)])
@assert folded(tup7, Tuple{S7, Int}) && entries(cit) == [e_s] "the entry at a parameter: $(entries(cit))"

# (6) a dispatch match through the entry: the dispatch edge and the entry
@assert call7(S7()) === :set
cid = only([c for c in all_cis(call7) if c.owner === nothing && c.max_world == typemax(UInt)])
@assert entries(cid) == [e_s] "the match's entry: $(entries(cid))"
@assert cid.min_world >= e_s.min_world

# (7) a member by its declared supertype folds with no entry
@assert isa7(D7())
cin = only([c for c in all_cis(isa7) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                         c.def.specTypes === Tuple{typeof(isa7), D7}])
@assert folded(isa7, D7) && isempty(entries(cin))

# (8) the backedges and G2 ignore the entry: a later method of g7 invalidates call7 as usual
g7(::S7) = :member
@assert call7(S7()) === :member

println("f7_membership_edges: OK")
