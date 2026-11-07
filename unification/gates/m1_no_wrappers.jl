# Gate (compiler C-20 retired): Core has no attribute wrappers and no Keyed type; a
# membership is declared only through jl_declare_membership, and Core.MembershipEntry
# carries the receiver (compiler §4.2). `Core.Dynamic` is an ordinary struct with no rule
# of subtyping (compiler §6.9): a member of a set only by a membership the library declares.
using Traits
include("util.jl")

for n in (:Keyed, :Compiled, :Kept)
    @assert !isdefined(Core, n) "Core.$n is gone"
end
@assert isstructtype(Core.Dynamic) && !ismutabletype(Core.Dynamic) && fieldnames(Core.Dynamic) == (:object,)
@assert fieldnames(Core.MembershipEntry) ==
        (:set, :member, :instance, :receiver, :min_world, :max_world, :declarer, :by)
@assert :contract in fieldnames(Core.TypeName) "a set's TypeName has a slot for its contract"

@trait X7
struct W7 end
e = @implement X7 W7
@assert e isa Core.MembershipEntry && e.receiver === :self && e.by === nothing
@assert W7() isa X7
@assert !(Core.Dynamic{X7} <: X7) "no rule of subtyping: no membership declared"

println("m1_no_wrappers: OK")
