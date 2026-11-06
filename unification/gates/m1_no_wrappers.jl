# Gate (compiler C-20 retired): Core has no attribute wrappers and no Keyed type; a
# membership is declared only through jl_declare_membership, and Core.MembershipEntry
# carries the receiver (compiler §4.2).
using Traits
include("util.jl")

for n in (:Keyed, :Dynamic, :Compiled, :Kept)
    @assert !isdefined(Core, n) "Core.$n is gone"
end
@assert fieldnames(Core.MembershipEntry) ==
        (:set, :member, :instance, :receiver, :min_world, :max_world, :declarer, :by)
@assert :contract in fieldnames(Core.TypeName) "a set's TypeName has a slot for its contract"

@trait X7
struct W7 end
e = @implement X7 W7
@assert e isa Core.MembershipEntry && e.receiver === :self && e.by === nothing
@assert W7() isa X7

println("m1_no_wrappers: OK")
