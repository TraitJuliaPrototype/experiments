# Gate M2 (review A round 2, F2/F3; re-judged to compiler §5.6 with W-112): a cached caller must
# switch exactly at a world-pinned flip — at UNION sig positions (F2) and for COMPOSED multi-chain
# memberships (F3: the earliest-completing chain). Oracles: the flip world is read from the entries'
# own min_world fields; the caller was compiled pre-declare and must switch :any -> :set exactly at
# the flip. Its guard does the switching: a membership invalidates nothing.
using Traits
include("util.jl")

# ---- (A) union sig position (F2) ----
@trait UF
struct UM end
struct UK end
du(::Union{UK, UF}) = :set
du(::Any)           = :any
calu(x::UM) = du(x)                    # compiled pre-declare
@assert calu(UM()) === :any "A: pre-declare value"
wu = curworld()
eu = @implement UF UM                  # the union's UF arm gains the member
@assert Base.invoke_in_world(eu.min_world - 1, calu, UM()) === :any "A: below the flip, :any is truth"
@assert Base.invoke_in_world(eu.min_world, calu, UM()) === :set "A: cached caller flips AT the entry (F2: union position must be bounded)"
@assert all(c -> c.max_world == typemax(UInt), all_cis(calu)) "A: the guarded caller is not invalidated"
@assert du(UK()) === :set "A: closed union arm unaffected"

# ---- (B) two competing chains — earliest completion wins (F3) ----
@trait TA
@trait TB
@trait TC
struct MM end
da(::TA) = :set
da(::Any) = :any
calm(x::MM) = da(x)                    # compiled pre-declare
@assert calm(MM()) === :any "B: pre-declare value"
w2 = curworld()
e1 = @implement TB MM                  # chain-1 leg 1 (first scanned later on)
e2 = @implement TC MM                  # chain-2 leg 1
e3 = @implement TA TC                  # chain-2 completes HERE -> the flip
e4 = @implement TA TB                  # chain-1 completes later (min4 > min3)
flip = max(e2.min_world, e3.min_world) # chain-2's completion world
@assert flip < e4.min_world "B: construction — the first-scanned chain completes strictly later"
@assert Base.invoke_in_world(flip - 1, calm, MM()) === :any "B: below the earliest flip, :any is truth"
@assert Base.invoke_in_world(flip, calm, MM()) === :set "B: cached caller must flip at the EARLIEST completing chain (F3)"
@assert all(c -> c.max_world == typemax(UInt), all_cis(calm)) "B: the guarded caller is not invalidated"
@assert Base.invoke_in_world(curworld(), calm, MM()) === :set "B: current world answers"

println("m2_future_min_worlds: OK")
