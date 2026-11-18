# E-283 (2): what a call through the code slot costs against a bound call (compiler §3.3). Two loops
# of 10^8 calls of a `@noinline` callee, the best of three runs each:
# - latency: `s = f(s)`, each call waiting for the last;
# - throughput: `s += g(i)`, the calls independent of each other, so the call's own cost shows.
# Run once with JULIA_CODE_SLOT=1 (the calls load their target through a slot) and once with 0 (the
# calls bind the callee's address).
# Usage: JULIA_CODE_SLOT=1 julia slot_cost.jl
@noinline f(x::Float64) = x * 1.0000001 + 1.0e-9
@noinline g(i::Int) = i ⊻ (i >> 3)
function latency(n)
    s = 0.0
    for _ in 1:n
        s = f(s)
    end
    return s
end
function throughput(n)
    s = 0
    for i in 1:n
        s += g(i)
    end
    return s
end
slot = get(ENV, "JULIA_CODE_SLOT", "1") != "0"
misses() = ccall(:jl_code_slot_stat, Csize_t, (Cint,), 3)
precompile(latency, (Int,)); precompile(throughput, (Int,))  # compiling runs the system image's code, which has slots of its own
m0 = misses()
latency(10); throughput(10)
@assert (misses() - m0 == 2) == slot "each loop's call goes through a slot exactly when the slot is on"
n = 10^8
for loop in (latency, throughput)
    t = minimum(@elapsed(loop(n)) for _ in 1:3)
    println("JULIA_CODE_SLOT=", slot ? 1 : 0, " ", rpad(loop, 10), ": ", round(t / n * 1e9; digits = 3), " ns per call")
end
