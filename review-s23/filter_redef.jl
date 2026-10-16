# Does the patched filter keep a worker compiled for a user's implementing type stale
# after the user redefines its own implementation method (rule 4: "what is redefined at
# the prompt recompiles as today")?
using TraitWorld
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)

toplevel(quote
    @trait_module module KCols
    using TraitWorld
    export KTable, kncols, kcol, kmean
    @trait KTable begin
        kncols(t::KTable)::Int
        kcol(t::KTable, i::Int)::Vector{Float64}
    end
    kmean(t::KTable, i::Int) = (c = kcol(t, i); sum(c) / length(c))
    end
end)

toplevel(quote
    import .KCols: kncols, kcol
    struct KRamp; base::Vector{Float64}; n::Int; end
    kncols(r::KRamp) = r.n
    kcol(r::KRamp, i::Int) = r.base .* i
    @implement KCols.KTable KRamp
end)

println("filter on: ", TraitWorld._FILTER_ON[], "  skipped so far: ", TraitWorld.filter_skipped())
r = Main.KRamp([1.0, 3.0], 2)
println("before redefinition: kmean(r, 2) = ", Main.KCols.kmean(r, 2), "   (plain: ", sum(r.base .* 2) / 2, ")")

toplevel(quote
    kcol(r::KRamp, i::Int) = r.base .* (10 * i)        # the owner of KRamp redefines its own method
end)
s0 = TraitWorld.filter_skipped()
println("after redefinition:  kmean(r, 2) = ", Main.KCols.kmean(r, 2), "   (plain: ", sum(r.base .* 20) / 2, ")")
println("skipped invalidations: ", s0)

# a second user type, implementing through a new, more specific method added later
toplevel(quote
    struct KRamp2; base::Vector{Float64}; n::Int; end
    kncols(r::KRamp2) = r.n
    kcol(r::Union{KRamp2}, i::Integer) = r.base .* i
    @implement KCols.KTable KRamp2
end)
r2 = Main.KRamp2([1.0, 3.0], 2)
println("KRamp2 before: ", Main.KCols.kmean(r2, 2))
toplevel(quote
    kcol(r::KRamp2, i::Int) = r.base .* (100 * i)      # more specific than the Integer method
end)
println("KRamp2 after a more specific method: ", Main.KCols.kmean(r2, 2), "   (plain: ", sum(Main.kcol(r2, 2)) / 2, ")")
println("skipped invalidations: ", TraitWorld.filter_skipped())
