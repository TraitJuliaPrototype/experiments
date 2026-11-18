# W-78: a bounded function defined again after its trait module is complete (traits §2, T-81):
# an edit of the body, an edit that breaks a rule, an edit of a bound, by plain `Core.eval`
using TraitWorld
@trait_module module EditT
using TraitWorld
export Values, Sized, vals, sq
@trait Values begin
    vals(v::Values)::Vector{Float64}
end
@trait Sized begin
    n(v::Sized)::Int
end
@implement Values Vector{Float64} begin
    vals(v) = v
end
@implement Sized Vector{Float64} begin
    n(v) = length(v)
end
sq(v::Values) = (s = 0.0; for x in vals(v); s += abs2(x); end; s)
user(v) = sq(v) + 1.0           # a plain caller compiled against the entry
end
using .EditT
println("E first: ", sq([1.0, 2.0]), " caller: ", EditT.user([1.0, 2.0]))
nm = length(methods(sq))
Core.eval(EditT, :(sq(v::Values) = 2 * sum(vals(v))))
println("E body edit: ", Base.invokelatest(sq, [1.0, 2.0]), " caller: ", Base.invokelatest(EditT.user, [1.0, 2.0]),
        " methods: ", nm, " -> ", length(methods(sq)))
println("E bad edit:")
Core.eval(EditT, :(sq(v::Values) = Float64(length(identity(v)))))
println("E bad edit call: ", try Base.invokelatest(sq, [1.0, 2.0]) catch e; first(sprint(showerror, e), 160) end)
Core.eval(EditT, :(sq(v::Values) = 3 * sum(vals(v))))
println("E fixed again: ", Base.invokelatest(sq, [1.0, 2.0]))
# a bound edited: a new shape at another trait
Core.eval(EditT, :(sz(v::Sized) = n(v)))
println("E new function after end: ", Base.invokelatest(EditT.sz, [1.0, 2.0, 3.0]))
Core.eval(EditT, :(sz(v::(Sized, Values)) = n(v) + length(vals(v))))
println("E bound edited: ", Base.invokelatest(EditT.sz, [1.0, 2.0, 3.0]))
# an ordinary definition evaluated into the module stays ordinary
Core.eval(EditT, :(plain(x::Int) = x + 1))
println("E plain: ", Base.invokelatest(EditT.plain, 1))
println("E lowering hook installed: ", Core._lower === TraitWorld._tw_lower)
