# Gate (W-107; compiler §5.2): two methods at sets that a later membership orders. Inserted
# while the sets were unrelated, they intersect (as All{SI, SG}) and are recorded as ambiguous;
# the set-in-set membership makes the method at the smaller set the more specific, in its world.
using Traits
include("util.jl")

@trait SI
@trait SG
gn(::SG) = :g
gn(::SI) = :i
struct M end
@implement SI M
@implement SG M
w_both = curworld()
@assert length(methods(gn, (M,))) == 0                 # ambiguous: two unrelated sets
@implement SG SI                                        # SI ⊆ SG: gn(::SI) is more specific
@assert gn(M()) === :i
@assert length(methods(gn, (M,))) == 1
let raised = try
        Base.invoke_in_world(w_both, gn, M())
        false
    catch e
        e isa MethodError
    end
    @assert raised "in the world before, the two methods stay ambiguous"
end

println("n2_set_order_late: OK")
