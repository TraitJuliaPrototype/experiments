# W-93 (open issue 124): the image code rejected while the forks load, by package of the code and by the
# methods that broke its edge (Compiler's validation log, as E-238's census.jl reads it, without the entries
# for folds and bindings that hold, E-243).  julia --project=<forks env> rejections_df.jl [Pkg,…]
R = Base.Compiler.ReinferUtils
R.debug_method_invalidation(true)
for p in Symbol.(split(get(ARGS, 1, "CSV,DataFrames,Statistics,Dates"), ",")); Base.require(Main, p); end
log = R._jl_debug_method_invalidation[]
R.debug_method_invalidation(false)
_mi(ci) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
direct = Base.IdDict{Any,Any}(); via = Base.IdDict{Any,Any}()
i = 1
while i <= length(log)
    x = log[i]
    if x isa String
        if x == "insert_backedges_callee"
            edge = log[i-1]; ci = log[i+1]; ms = log[i+2]
            # a fold record or a binding without partitions: logged, but the code stays valid (E-243)
            (edge isa Core.Binding || nameof(typeof(edge)) === :FoldRecord) || (direct[ci] = (edge, ms isa Vector ? ms : Any[]))
            global i += 3; continue
        elseif x == "verify_methods"
            via[log[i-1]] = log[i+1]; global i += 2; continue
        elseif x == "method_globalref"
            direct[log[i+1]] = (log[i-1], Any[]); global i += 3; continue
        end
    end
    global i += 1
end
root(ci, n = 0) = haskey(direct, ci) ? direct[ci] : (haskey(via, ci) && n < 1000 ? root(via[ci], n + 1) : nothing)
cause(c) = c === nothing ? "?" : join(unique(string(parentmodule(m), ".", m.name, m.file === Symbol(joinpath(dirname(pathof(Base.loaded_modules[Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")])), "trait.jl")) ? " (TraitWorld trait.jl)" : "")
                                         for m in c[2] if m isa Method), ",")
pkg(ci) = (m = _mi(ci).def; m isa Method ? string(Base.moduleroot(m.module)) : "?")
cis = unique(Any[collect(keys(direct)); collect(keys(via))])
println("rejected CodeInstances ", length(cis))
bypkg = Dict{String,Int}(); bycause = Dict{String,Int}()
for ci in cis
    p = pkg(ci); bypkg[p] = get(bypkg, p, 0) + 1
    k = p * " <- " * cause(root(ci)); bycause[k] = get(bycause, k, 0) + 1
end
for (k, v) in sort!(collect(bypkg); by = last, rev = true); println("PKG ", lpad(v, 5), "  ", k); end
for (k, v) in sort!(collect(bycause); by = last, rev = true)[1:min(end, 25)]; println("REJ ", lpad(v, 5), "  ", first(k, 220)); end
n124 = count(ci -> pkg(ci) == "DataFrames" && occursin("TraitWorld trait.jl", cause(root(ci))), cis)
println("DataFrames rejected by methods TraitWorld's @trait defines: ", n124)
