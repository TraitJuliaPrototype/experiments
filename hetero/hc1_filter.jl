# E1: filter! on a Vector{Any} (BaseBenchmarks' case: 1000 Ints and Strings, pred x -> isa(x, Int)),
# plain against the facts image. Per-element time, allocations, and what the compiled code does.
using BenchmarkTools, Random
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
Random.seed!(1)
const N = 1000
const ints = rand(1:N, N)
const strings = [randstring(rand(1:30)) for _ in 1:N]
const anys = shuffle!([ints; strings])[1:N]::Vector{Any}
pred = x -> isa(x, Int)
# the BaseBenchmarks body, copied, so that code_typed shows it
function filt!(f, a::AbstractVector)
    j = firstindex(a)
    for ai in a
        @inbounds a[j] = ai
        j = ifelse(f(ai)::Bool, nextind(a, j), j)
    end
    j > lastindex(a) && return a
    if a isa Vector
        resize!(a, j-1)
        sizehint!(a, j-1)
    else
        deleteat!(a, j:lastindex(a))
    end
    return a
end
# variants that isolate the two calls
function only_pred(f, a::Vector{Any})           # f(ai) alone
    n = 0
    for ai in a
        n += f(ai)::Bool
    end
    n
end
function only_store(a::Vector{Any})             # a[j] = ai alone
    j = 1
    for ai in a
        @inbounds a[j] = ai
        j += 1
    end
    a
end
function store_invoke(a::Vector{Any})           # the store through an explicit invoke at Base's declared signature
    j = 1
    for ai in a
        @inbounds invoke(setindex!, Tuple{Array{Any}, Any, Int}, a, ai, j)
        j += 1
    end
    a
end
function pred_typed(a::Vector{Any})             # the predicate's body inlined by hand (no call on `Any`)
    n = 0
    for ai in a
        n += isa(ai, Int)
    end
    n
end
d = copy(anys)
println(mode, "  filter!        ", lpad(round(1e9 * (@belapsed filter!($pred, d) setup=(d=copy($anys)) evals=1) / N; digits=1), 6), " ns/elt")
println(mode, "  filt! (copy)   ", lpad(round(1e9 * (@belapsed filt!($pred, d) setup=(d=copy($anys)) evals=1) / N; digits=1), 6), " ns/elt")
println(mode, "  only_pred      ", lpad(round(1e9 * (@belapsed only_pred($pred, $anys)) / N; digits=1), 6), " ns/elt")
println(mode, "  pred_typed     ", lpad(round(1e9 * (@belapsed pred_typed($anys)) / N; digits=1), 6), " ns/elt")
println(mode, "  only_store     ", lpad(round(1e9 * (@belapsed only_store($anys)) / N; digits=1), 6), " ns/elt")
println(mode, "  store_invoke   ", lpad(round(1e9 * (@belapsed store_invoke($anys)) / N; digits=1), 6), " ns/elt")
println("---- code_typed of filt!(pred, ::Vector{Any}), ", mode)
ct = code_typed(filt!, Tuple{typeof(pred), Vector{Any}})[1][1]
for (i, s) in enumerate(ct.code)
    str = sprint(show, s)
    occursin("invoke", str) || occursin("setindex!", str) || occursin("pred", str) || occursin("(f)", str) || occursin("isa", str) || occursin("Any", sprint(show, ct.ssavaluetypes[i])) && i < 25 ? println("  ", i, ": ", first(str, 110), "  :: ", ct.ssavaluetypes[i]) : nothing
end
