# E4: the cascade of `Any`: Dict{Any,Any} iteration (BaseBenchmarks: 7 ns plain, 120 ns under all),
# and which calls in `iterate` are dynamic under each mode.
using BenchmarkTools
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
d = Dict{Any,Any}(i => string(i) for i in 1:1000)
st = iterate(d)[2]
println(mode, "  iterate(Dict{Any,Any})        ", round(1e9 * @belapsed(iterate($d)); digits = 1), " ns  ", @allocated(iterate(d)), " B")
println(mode, "  iterate(Dict{Any,Any}, st)    ", round(1e9 * @belapsed(iterate($d, $st)); digits = 1), " ns  ", @allocated(iterate(d, st)), " B")
function sumkeys(d)                       # a loop a user writes: Int keys summed, the rest skipped
    s = 0
    for (k, v) in d
        k isa Int && (s += k)
    end
    s
end
println(mode, "  for (k, v) in Dict{Any,Any}   ", round(1e9 * @belapsed(sumkeys($d)) / 1000; digits = 1), " ns/elt  ", @allocated(sumkeys(d)) / 1000, " B/elt")
di = Dict{Int,String}(i => string(i) for i in 1:1000)
println(mode, "  for (k, v) in Dict{Int,String} ", round(1e9 * @belapsed(sumkeys($di)) / 1000; digits = 1), " ns/elt  ", @allocated(sumkeys(di)) / 1000, " B/elt")
println("---- generic (non-invoke) calls in iterate(::Dict{Any,Any}, ::Int), ", mode)
ct = code_typed(iterate, Tuple{Dict{Any,Any}, Int})[1][1]
for (i, s) in enumerate(ct.code)
    str = sprint(show, s)
    if (occursin("call", str) || occursin("invoke", str)) && !occursin("Core.", str) && !occursin("Base.getfield", str) && !occursin("Base.arrayref", str)
        println("  ", i, ": ", first(str, 120), "  :: ", first(sprint(show, ct.ssavaluetypes[i]), 40))
    end
end
println("---- generic (non-invoke) calls in sumkeys(::Dict{Any,Any}), ", mode)
ct = code_typed(sumkeys, Tuple{Dict{Any,Any}})[1][1]
for (i, s) in enumerate(ct.code)
    str = sprint(show, s)
    if s isa Expr && s.head === :call
        println("  ", i, ": ", first(str, 120), "  :: ", first(sprint(show, ct.ssavaluetypes[i]), 40))
    end
end

# a control: where plain Julia cannot speculate either (`+` has hundreds of methods), the facts mode costs the same
const anyints = Any[i for i in 1:1000]
sumany(v) = (s = 0; for x in v; s += x; end; s)
println(mode, "  sum over Vector{Any} of Int    ", round(1e9 * @belapsed(sumany($anyints)) / 1000; digits = 1), " ns/elt  ", @allocated(sumany(anyints)) / 1000, " B/elt")
const anyflt = Any[Float64(i) for i in 1:1000]
println(mode, "  sum over Vector{Any} of Float64 ", round(1e9 * @belapsed(sumany($anyflt)) / 1000; digits = 1), " ns/elt  ", @allocated(sumany(anyflt)) / 1000, " B/elt")
# Vector{Real}: plain speculates on nothing either (Real has many subtypes), typed result
sumreal(v::Vector{Real}) = (s = 0.0; for x in v; s += Float64(x); end; s)
const reals = Real[isodd(i) ? i : Float64(i) for i in 1:1000]
println(mode, "  Float64(x) over Vector{Real}   ", round(1e9 * @belapsed(sumreal($reals)) / 1000; digits = 1), " ns/elt  ", @allocated(sumreal(reals)) / 1000, " B/elt")
