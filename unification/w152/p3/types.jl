# E-395 (c): what the callees that are not deep G2 lose in types when they are inferred by the facts rule
# all the way down. Run under the test bed, where a neutral method takes the policy of the code that reaches it:
#     JULIA_COMPILE_BY_FACTS=1 julia --project=../../w134/env_forks types.jl <deep.jl's out.jls>
# For each callee outside the own modules that an own facts instance calls directly and that is not deep G2:
# the plain result type (the session's instance) against the result type of an inference by facts.
using Serialization
@eval using CSV, DataFrames
const C = Base.Compiler
data = deserialize(ARGS[1])
plain = IdDict{Any,Any}(); for (sig, rt, b) in data.nd; plain[sig] = rt; end
println("test bed: ", get(ENV, "JULIA_COMPILE_BY_FACTS", "0"), " | callees called directly by own facts instances, not deep G2: ", length(data.direct))
function facts_rt(sig)
    interp = C.NativeInterpreter(Base.get_world_counter(); facts = true)
    r = Base.code_typed_by_type(sig; interp, optimize = false)
    length(r) == 1 ? r[1][2] : Union{}
end
same = 0; wider = Any[]; narrower = 0; failed = 0; t0 = time()
for sig in data.direct
    haskey(plain, sig) || continue
    p = plain[sig]
    f = try facts_rt(sig) catch e; global failed += 1; continue end
    if f == p; global same += 1
    elseif p <: f; push!(wider, (sig, p, f))
    else; global narrower += 1; end
end
println("inferred by facts in ", round(time() - t0; digits = 1), " s: the same result type ", same, "; wider ", length(wider), "; another ", narrower, "; failed ", failed)
toany = count(x -> x[3] === Any, wider)
println("of the wider: to Any ", toany, "; the plain result was concrete in ", count(x -> isconcretetype(x[2]), wider), "; was Union{} (a call that only throws) ", count(x -> x[2] === Union{}, wider))
bym = Dict{String,Int}(); for (sig, p, f) in wider; k = string(Base.unwrap_unionall(sig).parameters[1]); bym[k] = get(bym, k, 0) + 1; end
println("wider, by function (", length(bym), "): ", join(["$k $v" for (k, v) in sort(collect(bym); by = last, rev = true)[1:min(end, 40)]], ", "))
for (sig, p, f) in wider[1:min(end, 40)]; println("   ", first(string(sig), 150), "  plain ", first(string(p), 60), "  facts ", first(string(f), 60)); end
