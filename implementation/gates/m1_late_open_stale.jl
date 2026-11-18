# Gate (compiler §4.1, the audit's A5): a set is open from its declaration. A type
# whose binding is published cannot become a set later, so no type built against it
# can carry a stale has_open_set bit: the bit is final when a type is built.
using Traits
include("util.jl")

abstract type Xs end                 # a plain abstract type, published
const TI = Tuple{Xs, Int}            # its has_open_set bit is computed now: false

let refused = try
        ccall(:jl_set_open_set, Cvoid, (Any,), Xs)
        false
    catch
        true
    end
    @assert refused "opening a published type is refused"
end
@assert !Traits.isopen(Xs)

# a set declared by @trait is open before anything names it
@trait Ys
const TJ = Tuple{Ys, Int}
@assert ccall(:jl_has_open_set, Cint, (Any,), TJ) == 1 "built after the set opened: the bit is set"
struct LateS end
@implement Ys LateS
@assert (LateS(), 1) isa TJ
@assert !((1, 1) isa TJ)

println("m1_late_open_stale: OK")
