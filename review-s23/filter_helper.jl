# An implementation in ordinary code that calls the user's own helper: accepted? And with
# the patched filter, does redefining the helper reach the worker?
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

ok = try
    toplevel(quote
        import .KCols: kncols, kcol
        struct KRamp; base::Vector{Float64}; n::Int; end
        scale(r::KRamp, i::Int) = r.base .* i                 # the user's own helper, ordinary code
        kncols(r::KRamp) = r.n
        kcol(r::KRamp, i::Int) = scale(r, i)
        @implement KCols.KTable KRamp
    end)
    true
catch e
    println("@implement refused: ", sprint(showerror, e)[1:min(end, 400)])
    false
end
if ok
    r = Main.KRamp([1.0, 3.0], 2)
    v1 = try Main.KCols.kmean(r, 2) catch e; "error: " * sprint(showerror, e)[1:min(end, 300)] end
    println("first call: ", v1, "   (plain: ", sum(r.base .* 2) / 2, ")")
    toplevel(quote
        scale(r::KRamp, i::Int) = r.base .* (10 * i)       # the owner redefines its helper
    end)
    v2 = try Main.KCols.kmean(r, 2) catch e; "error: " * sprint(showerror, e)[1:min(end, 300)] end
    println("after redefining the helper: ", v2, "   (plain: ", sum(r.base .* 20) / 2, ")")
    println("filter on: ", TraitWorld._FILTER_ON[], ", skipped: ", TraitWorld.filter_skipped())
end
