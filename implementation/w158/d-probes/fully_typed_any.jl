# W-158, piece 2: `@enforce_fully_typed` at a call on an element of `Vector{Any}` (traits §14; compiler §2.7, §7.6).
# The messages tool's case `cf1(xs::Vector{Any}) = cn(xs[1])`, an operation of a trait called at a value typed `Any`,
# beside controls: a plain function of two methods, of one method, and the operation at a value known by its trait.
# For each: whether the call raises, `fully_typed`'s report, and whether the compiled code starts with the mode's check.
#     $JN --project=$LIBD $W158/d-probes/fully_typed_any.jl
using TraitWorld
println("pathof ", pathof(TraitWorld), "  commit ", readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) log -1 --format=%h`))

module CLib
using TraitWorld
@trait CTab begin
    cn(t::CTab)::Int
    ccol(t::CTab, i::Int)::Vector{Float64}
end
export CTab, cn, ccol
end
using .CLib
struct CT; cols::Vector{Vector{Float64}}; end
CLib.cn(t::CT) = length(t.cols)
CLib.ccol(t::CT, i::Int) = t.cols[i]
@implement CTab CT

g2(::Int) = 1; g2(::Float64) = 2              # a plain function of two methods
g1(x::Int) = 1                                # of one method

@enforce_fully_typed cf1(xs::Vector{Any}) = cn(xs[1])          # the case: an operation at a value typed Any
@enforce_fully_typed h2(xs::Vector{Any}) = g2(xs[1])           # control: two methods
@enforce_fully_typed h1(xs::Vector{Any}) = g1(xs[1])           # control: one method (settled when closed only)
@enforce_fully_typed ct(xs::Vector{CTab}) = cn(xs[1])          # control: the operation at a value known by its trait

println("methods of cn:")
foreach(m -> println("   ", m.sig), methods(cn))
for (f, arg, label) in ((cf1, Any[CT([[1.0]])], "cf1: cn(xs[1]), xs::Vector{Any}"),
                        (h2, Any[1], "h2: g2(xs[1]), two methods"),
                        (h1, Any[1], "h1: g1(xs[1]), one method"),
                        (ct, CTab[CT([[1.0]])], "ct: cn(xs[1]), xs::Vector{CTab}"))
    println("== ", label)
    r = try f(arg) catch e; e end
    println("   the call: ", r isa Exception ? sprint(showerror, r) : string("returns ", r))
    rep = fully_typed(f, (typeof(arg),))
    println("   fully_typed: isfullytyped = ", isfullytyped(rep), "; sites: ", length(rep.sites))
    foreach(s -> println("      ", s), rep.sites)
    src = only(code_typed(f, (typeof(arg),); optimize = true))[1]
    println("   the compiled code (session): ", any(st -> occursin("not_fully_typed", string(st)), src.code) ? "starts with the mode's check" : "no check", "; ",
            join((string(st) for st in src.code if st isa Expr && st.head in (:call, :invoke)), " | "))
end

# The case that replaces `cf1` in the messages tool: a call on an operation's result of an abstract type, at a box
# (traits §14: "a call on such a result is a call the caller cannot resolve, and the report of the caller names the
# result as its root cause").
@trait CData begin
    cdata(t::CData)::AbstractVector
end
struct CD; v::Vector{Float64}; end
cdata(t::CD) = t.v
@implement CData CD
@enforce_fully_typed cf2(t::CData) = sum(cdata(t))
for (arg, label) in ((CD([1.0]), "cf2 at a member"), (Dynamic{CData}(CD([1.0])), "cf2 at a box"))
    println("== ", label)
    r = try cf2(arg) catch e; e end
    println("   the call: ", r isa Exception ? sprint(showerror, r) : string("returns ", r))
end
