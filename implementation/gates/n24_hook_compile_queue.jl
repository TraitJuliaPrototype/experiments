# Gate for compiler C-31 (§10.4) and lowering L-52 (§3; E-352): the member hook in the compile queue.
# A call compiled with the member's type known reaches a method at the set only after the member's
# check. Inference runs no check: it notes the member, and the queue asks the hook before the code
# runs. A member that fails is left to dispatch, which raises the hook's error at that use, and only
# there. A member that passes is called directly. A member whose check fails and later passes (a member
# by its definition used before its `@implement`) raises, then runs, its callers compiled again.
# The gate installs its own hook; the library's check is tested in TraitWorld's suite.
using Traits
include("util.jl")

struct CheckFailed24 <: Exception; T; X; end
const CALLS24 = Dict{Any,Int}()
const PASS24 = Base.IdSet{Any}()
const INSIDE24 = Ref{Any}(nothing)
function hook24(@nospecialize(T), @nospecialize(X))
    CALLS24[(T, X)] = get(CALLS24, (T, X), 0) + 1
    INSIDE24[] === nothing || Base.invokelatest(INSIDE24[], T)
    T in PASS24 || throw(CheckFailed24(T, X))
    return nothing
end
ccall(:jl_set_member_hook, Cvoid, (Any,), hook24)

@trait Sized24
struct W24{P}; x::P; end
sz24(w::W24{Int}) = 1
twice24(x::Sized24) = 2 * sz24(x)                      # a method at the set
@implement Sized24 W24{P} where {P}
push!(PASS24, W24{Int})

# (1) a failing member, its type known to the compiled caller
use24(w) = twice24(w)
branch24(w, b::Bool) = b ? twice24(w) : 0
e = try use24(W24(1.0)); nothing catch err; err end
@assert e isa CheckFailed24 && e.T === W24{Float64} "a compiled use of a failing member raises the check's error: $e"
@assert try use24(W24(1.0)); false catch err; err isa CheckFailed24 end "at each use"
n = CALLS24[(W24{Float64}, Sized24)]
@assert branch24(W24(1.0), false) === 0 "a use in a branch not taken raises nothing"
@assert CALLS24[(W24{Float64}, Sized24)] == n "inference reads the kept failure and asks no hook"
@assert try branch24(W24(1.0), true); false catch err; err isa CheckFailed24 end "the branch taken raises"
# another failing member type, first met by a caller two frames up
outer24(x) = use24(W24(x)) + 1
@assert !haskey(CALLS24, (W24{UInt8}, Sized24))
@assert try outer24(0x01); false catch err; err isa CheckFailed24 end "through an inlined caller"
@assert try outer24(0x01); false catch err; err isa CheckFailed24 end
skip24(x, b::Bool) = b ? use24(W24(x)) : 0
@assert skip24(Int8(1), false) === 0 && CALLS24[(W24{Int8}, Sized24)] == 1 "the queue asked before the code ran"

# (2) a passing member: checked before the code runs, then called directly
@assert !haskey(CALLS24, (W24{Int}, Sized24))
@assert skip24(1, false) === 0
@assert CALLS24[(W24{Int}, Sized24)] == 1 "the compile queue asked the hook"
@assert use24(W24(1)) === 2 && skip24(1, true) === 2 && outer24(1) === 3
@assert CALLS24[(W24{Int}, Sized24)] == 1 "once: $(CALLS24[(W24{Int}, Sized24)])"
@assert Base.return_types(use24, (W24{Int},)) == Any[Int] "the passing member's call is resolved: $(Base.return_types(use24, (W24{Int},)))"
@assert Base.return_types(outer24, (Int,)) == Any[Int]

# (3) a check that fails, then passes: the callers compiled while it failed are compiled again
euse24(w) = twice24(w)
sz24(w::W24{Int16}) = 3
@assert try euse24(W24(Int16(1))); false catch err; err isa CheckFailed24 end
@assert try euse24(W24(Int16(1))); false catch err; err isa CheckFailed24 end
push!(PASS24, W24{Int16})
@assert euse24(W24(Int16(1))) === 6 "after the check passes the use runs"
@assert euse24(W24(Int16(1))) === 6
let cis = filter(ci -> ci.max_world == typemax(UInt) && ci.def.specTypes == Tuple{typeof(euse24), W24{Int16}}, all_cis(euse24))
    @assert !isempty(cis) && all(ci -> ci.rettype === Int, cis) "the caller compiled while the check failed is replaced: $([ci.rettype for ci in cis])"
end

# (4) a check that itself compiles and runs code using the member
luse24(w) = twice24(w)
INSIDE24[] = T -> T === W24{Int32} ? luse24(W24(Int32(1))) : nothing
sz24(w::W24{Int32}) = 5
push!(PASS24, W24{Int32})
lcall24(x) = luse24(W24(x))
@assert lcall24(Int32(1)) === 10
INSIDE24[] = nothing
@assert lcall24(Int32(1)) === 10

# (5) no hook: nothing is noted
ccall(:jl_set_member_hook, Cvoid, (Any,), nothing)
nuse24(w) = twice24(w)
@assert try nuse24(W24("a")); false catch err; err isa MethodError end
println("n24_hook_compile_queue: OK")
