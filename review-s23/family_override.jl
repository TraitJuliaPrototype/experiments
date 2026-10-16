# A family conformance over Base's AbstractVector with a default operation: a user's
# subtype joins the family; a later method by the subtype's owner for the defaulted
# operation. Refused (note: an override belongs to the conformance), or silently ignored?
using TraitWorld
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)

toplevel(quote
    @trait_module module KF
    using TraitWorld
    export KSz, ksz, kdesc, report
    @trait KSz begin
        ksz(v::KSz)::Int
        kdesc(v::KSz)::String = string("size ", ksz(v))      # a default
    end
    @implement KSz A where {A <: AbstractVector} begin       # a family over Base's abstract type
        ksz(v) = length(v)
    end
    report(v::KSz) = kdesc(v)
    end
end)

toplevel(quote
    struct MyV <: AbstractVector{Int}; n::Int; end
    Base.size(v::MyV) = (v.n,)
    Base.getindex(v::MyV, i::Int) = i
end)
v = Main.MyV(3)
println("before: report(v) = ", repr(Main.KF.report(v)))
r = try
    toplevel(quote
        KF.kdesc(v::MyV) = "mine"                               # the owner of MyV, after the family
    end)
    "accepted"
catch e
    "refused: " * sprint(showerror, e)[1:min(end, 200)]
end
println("late method for MyV: ", r)
println("plain Julia: kdesc(v) = ", repr(Main.KF.kdesc(v)))
out = try repr(Main.KF.report(v)) catch e; "error: " * sprint(showerror, e)[1:min(end, 300)] end
println("after: report(v) = ", out)
println("check_overrides(): ", TraitWorld.check_overrides())
