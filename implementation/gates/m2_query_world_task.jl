# Gate (W-99, the audit's A4; compiler §4.11): the world membership questions are asked in is
# the task's, set for the length of a query and restored by exception handlers as the world age
# is. A task switch does not hand it to another task; a throw out of a query does not leave it set.
using Traits
include("util.jl")

setq(w) = ccall(:jl_set_membership_query_world, Csize_t, (Csize_t,), w)
getq() = ccall(:jl_membership_query_world, Csize_t, ())

@assert getq() == 0 "no query world at top level"

# a throw out of a region restores the value at the handler's entry
try
    setq(12345)
    error("out of the region")
catch
end
@assert getq() == 0 "the handler restored the query world"

# another task's query world is its own
t = @task begin
    setq(777)
    yield()
    getq()
end
schedule(t)
yield()
@assert getq() == 0 "the main task does not see the other task's query world"
@assert fetch(t) == 777 "the task keeps its own across a switch"

# inference and reflection leave none behind, and answer in the caller's world
@trait QW
struct SQ end
@implement QW SQ
q(x) = x isa QW
@assert q(SQ())
ct = Base.code_typed(q, (SQ,))[1]
@assert getq() == 0 "code_typed leaves no query world"
try
    Base.code_typed(error, (String,))
catch
end
@assert getq() == 0

println("m2_query_world_task: OK")
