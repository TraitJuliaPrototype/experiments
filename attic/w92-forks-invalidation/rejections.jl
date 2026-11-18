# E-238: the image code rejected at the forks' load, in detail: for each edge that failed validation, the edge,
# the CodeInstance (owner, method), and the methods that now match there (Compiler's own validation log).
#     julia --project=forks/env_forks rejections.jl [Pkg,Pkg,…]
R = Base.Compiler.ReinferUtils
R.debug_method_invalidation(true)
for p in Symbol.(split(get(ARGS, 1, "CSV,DataFrames,Statistics,Dates"), ",")); Base.require(Main, p); end
log = R._jl_debug_method_invalidation[]
R.debug_method_invalidation(false)
_mi(ci) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
println("log entries ", length(log))
bysig = Dict{String,Vector{Any}}()
i = 1; nfail = 0; nvia = 0
while i <= length(log)
    x = log[i]
    if x == "insert_backedges_callee"
        global nfail += 1
        edge = log[i-1]; ci = log[i+1]; ms = log[i+2]
        msig = ms isa Vector ? join((sprint(show, m) for m in ms if m isa Method), " ; ") : "?"
        k = first(sprint(show, edge), 200) * "  NOW MATCHES  " * first(msig, 400)
        push!(get!(bysig, k, Any[]), ci)
        global i += 3; continue
    elseif x == "verify_methods"
        global nvia += 1
    end
    global i += 1
end
println("failed edges ", nfail, "; code rejected through a callee ", nvia)
for (k, cis) in sort!(collect(bysig); by = x -> -length(x[2]))
    owners = unique(repr(ci.owner) for ci in cis)
    mods = unique(string(Base.moduleroot(_mi(ci).def.module)) for ci in cis if _mi(ci).def isa Method)
    println(lpad(length(cis), 4), "  ", k)
    println("       owners ", join(owners, ","), "; packages ", join(mods, ","), "; e.g. ", first(sprint(show, _mi(cis[1])), 200))
end
