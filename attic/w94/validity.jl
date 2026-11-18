# W-94: is image code that the compiler's validation log names with "insert_backedges_callee" invalid?
# For each logged entry, by the kind of its edge: the CodeInstance's world range after the loads
# (valid = max_world typemax), and whether the fold's value at load equals the stored one.
#     julia --project=<env> validity.jl [Pkg,Pkg,…]
include(joinpath(@__DIR__, "patch_verify.jl"))   # W94_PATCH set: the branch w94's validation
R = Base.Compiler.ReinferUtils
const CC = Base.Compiler
R.debug_method_invalidation(true)
for p in Symbol.(split(get(ARGS, 1, "Tables,CSV"), ",")); Base.require(Main, p); end
log = R._jl_debug_method_invalidation[]
R.debug_method_invalidation(false)
kind(e) = e isa CC.FoldRecord ? "FoldRecord" : e isa Core.Binding ? "Binding" : e isa Core.MethodInstance ? "MethodInstance" : e isa Type ? "signature" : string(typeof(e))
stats = Dict{String,Vector{Int}}()     # kind => [entries, CI valid after load, CI invalid]
examples = Dict{String,Any}()
for i in eachindex(log)
    log[i] == "insert_backedges_callee" || continue
    e = log[i-1]; ci = log[i+1]
    k = kind(e)
    s = get!(stats, k, [0, 0, 0]); s[1] += 1
    valid = ci isa Core.CodeInstance && ci.max_world == typemax(UInt)
    valid ? (s[2] += 1) : (s[3] += 1)
    if k == "FoldRecord" && !haskey(examples, k)
        examples[k] = (e, ci)
    end
end
println("entries 'insert_backedges_callee' by edge kind: [logged, CodeInstance valid after the loads, invalid]")
for (k, s) in sort!(collect(stats)); println("  ", rpad(k, 16), s); end
if haskey(examples, "FoldRecord")
    e, ci = examples["FoldRecord"]
    println("a fold: ", e.g, " ", e.args[2:end], "; CodeInstance worlds ", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
            "; holds now ", CC.fold_holds(e, Base.get_world_counter()))
end
