# Gate (W-140; compiler §5.5): a membership adds no method. A call that matched the trait's method before
# the membership (a call at `Any`, at an abstract argument) has the same matches after it, so the code
# that inferred it stays valid, and so does the wide instance of another method. A call at the member's
# own type did not match it before: its caller is invalidated. Answers are Julia's throughout.
using Traits
include("util.jl")
valid(f) = [c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt)]

@trait X
struct S end
f(@nospecialize(x)) = x === nothing ? :nothing : :any      # compiled once, at (f, Any)
f(x::X) = :set
callf(@nospecialize(x)) = f(x)                             # a caller at Any
struct W; x::Any; end
callw(w::W) = f(w.x)                                       # a caller with an abstract argument
calls(s::S) = f(s)                                         # a caller at the type that joins
@assert f(1) === :any && callf(1) === :any && callw(W(1)) === :any && calls(S()) === :any
atS(c) = c.def.specTypes === Tuple{typeof(f), S}             # f(::Any)'s instance at the type that joins
wide = vcat(filter(!atS, valid(f)), valid(callf), valid(callw)); narrow = vcat(filter(atS, valid(f)), valid(calls))
@assert length(wide) >= 3 && length(narrow) == 2
@implement X S
@assert all(c -> c.max_world == typemax(UInt), wide) "the wide instance and the callers at Any stay valid: $([(c.def.specTypes, c.max_world == typemax(UInt)) for c in wide])"
@assert all(c -> c.max_world != typemax(UInt), narrow) "the caller and the instance at the member's type are invalidated"
@assert f(S()) === :set && callf(S()) === :set && callw(W(S())) === :set && calls(S()) === :set
@assert callf(1) === :any && callw(W(1)) === :any

# a union of non-members did not match the trait's method either
struct U1 end
struct U2 end
struct WU; x::Union{U1, U2}; end
g(x::X) = :set
g(@nospecialize(x)) = :any
callu(w::WU) = g(w.x)
@assert callu(WU(U1())) === :any
@implement X U1
@assert callu(WU(U1())) === :set && callu(WU(U2())) === :any
println("n28_wide_caller: OK")
