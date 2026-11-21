# Errors that no test of the library and no documentation example shows (README.md): each statement is provoked
# and its message computed with `sprint(showerror, e)`, which capture.jl records. The cases lean on the forms a
# signature takes: one trait argument and several, a keyword method, a `where` variable, a closure, a vararg, a
# parametric trait; and on the library's errors at a kept form.
using TraitWorld

function provoke(name, ex)
    e = try
        Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)
        nothing
    catch err
        while err isa LoadError; err = err.error; end
        err
    end
    println("CASE ", name, ": ", e === nothing ? "no error" : string(nameof(typeof(e))))
    e === nothing || println(sprint(showerror, e))
    return e
end

module CLib
using TraitWorld
@trait CTab begin
    cn(t::CTab)::Int
    ccol(t::CTab, i::Int)::Vector{Float64}
end
@trait CVec{T} begin
    T = eltype(Self)
    cget(v::CVec{T}, i::Int)::T
end
@trait CPlaced begin
    x::Float64
    @const tag::String
end
export CTab, cn, ccol, CVec, cget, CPlaced
end
using .CLib
struct CT; cols::Vector{Vector{Float64}}; end
CLib.cn(t::CT) = length(t.cols)
CLib.ccol(t::CT, i::Int) = t.cols[i]
@implement CTab CT
mutable struct CP; x::Float64; const tag::String; end
@implement CPlaced CP

# the bounded check, by the form of the signature
provoke("bounded: one trait argument", :(module B1
    using TraitWorld, ..CLib
    @trait_module
    csum(t::CTab) = sum(t)
    end))
provoke("bounded: two trait arguments", :(module B2
    using TraitWorld, ..CLib
    @trait_module
    cboth(a::CTab, b::CTab, k::Int) = sum(a) + sum(b) + k
    end))
provoke("bounded: a keyword method", :(module B3
    using TraitWorld, ..CLib
    @trait_module
    cscaled(t::CTab; k::Float64 = 1.0) = k * sum(t)
    end))
provoke("bounded: a where variable", :(module B4
    using TraitWorld, ..CLib
    @trait_module
    cfirst(t::C) where {C <: CTab} = first(t)
    end))
provoke("bounded: a parametric trait", :(module B5
    using TraitWorld, ..CLib
    @trait_module
    clast(v::CVec{T}) where {T} = last(v)
    end))
provoke("bounded: a vararg of members", :(module B6
    using TraitWorld, ..CLib
    @trait_module
    call(ts::CTab...) = sum(t -> sum(t), ts)
    end))
provoke("bounded: a closure at a trait", :(module B7
    using TraitWorld, ..CLib
    @trait_module
    cmapper() = (t::CTab) -> sum(t)
    end))
provoke("bounded: an undeclared field", :(module B8
    using TraitWorld, ..CLib
    @trait_module
    cmass(p::CPlaced) = p.mass
    end))
provoke("bounded: a call that only throws", :(module B9
    using TraitWorld, ..CLib
    @trait_module
    cbad(t::CTab) = error("never")
    end))
provoke("bounded: @bounded outside a trait module", :(@bounded cb10(t::CTab) = sum(t)))

# the kept forms
provoke("box: an undeclared field", :(Dynamic{CPlaced}(CP(1.0, "a")).mass))
provoke("box: a @const field written", :((d = Dynamic{CPlaced}(CP(1.0, "a")); d.tag = "b")))
provoke("box: a non-member", :(Dynamic{CTab}(1.0)))
provoke("box: no parameters", :(Dynamic{CVec}([1.0])))
provoke("withfields: an undeclared field at a box", :(withfields(Dynamic{CPlaced}(CP(1.0, "a")); y = 2.0)))
provoke("withfields: no field at a member", :(withfields(CP(1.0, "a"); y = 2.0)))
provoke("like: a value of another family", :(like([1.0], "s")))
provoke("an operation at a box, outside its signature", :(ccol(Dynamic{CTab}(CT([[1.0]])), 1.5)))
provoke("an operation at a wrapper, outside its signature", :(ccol(compiled_for(CT([[1.0]])), 1.5)))
provoke("a method at a trait, a box of another trait", :((f11(t::CTab) = cn(t); f11(Dynamic{CPlaced}(CP(1.0, "a"))))))

# Callable
provoke("Callable: no method at A, boxed", :((cm(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x); cm(uppercase, 1.0))))
provoke("Callable: the result outside S", :((cm2(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x); cm2(x -> 1, 1.0))))
provoke("Callable: a wrapper with no method at A", :((cm3(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x); cm3(compiled_for(uppercase), 1.0))))
provoke("Callable: the box written out", :(Dynamic{Callable{Tuple{Float64}, Float64}}(uppercase)))

# fully typed mode at a value known by its trait. An operation at an element of `Vector{Any}` (`cn(xs[1])`) raises
# nothing: a closed build branches over the operation's methods (traits §14; ../README.md, "The library's pieces,
# continued"). A call on an operation's result of an abstract type, at a box, is one a build refuses
provoke("fully typed: a call on an operation's abstract result, at a box", :((@trait CData begin
        cdata(t::CData)::AbstractVector
    end;
    struct CD; v::Vector{Float64}; end;
    cdata(t::CD) = t.v;
    @implement CData CD;
    @enforce_fully_typed cf1(t::CData) = sum(cdata(t));
    cf1(Dynamic{CData}(CD([1.0]))))))

# declarations
provoke("@implement: a missing operation", :((struct CNo; end; @implement CTab CNo)))
provoke("@implement: not a trait", :(@implement Int CT))
provoke("@trait: an operation without its result", :(@trait CBad begin
    cbad(x::CBad)
end))
provoke("@trait_module: an unknown option", :(module B12
    using TraitWorld
    @trait_module dynamic = true
    end))
provoke("delete_membership: not a trait", :(delete_membership(Int, CT)))

# the two kinds of pirate (traits §12.2): a method of another module's owner-only function at one's own type, and the
# classic one; in a trait module (`no_pirates`), reported by default where it ends code compiled by facts, refused in
# strict mode (T-160)
module OOwn
using TraitWorld
@trait_module
export tally, score, OShape
weight(x) = 1                                   # owner-only by the trait module's default
score(x) = 0                                    # exported, and declared owner-only
@owner_only score
tally(xs::Vector{Any}) = (n = 0; for x in xs; n += weight(x) + score(x); end; n)
@trait OShape begin
    oarea(s::OShape)::Float64                   # an operation the module does not export: owner-only
end
end
using .OOwn
tally(Any[1, "a"])
provoke("owner-only: a method in a trait module, at its own type", :(module OO1
    using TraitWorld, ..OOwn
    @trait_module
    struct Mine end
    OOwn.weight(::Mine) = 0
    end))
provoke("owner-only by @owner_only: a method in a trait module", :(module OO2
    using TraitWorld, ..OOwn
    @trait_module
    struct Mine end
    OOwn.score(::Mine) = 0
    end))
provoke("owner-only: a trait's unexported operation, in a block", :(module OO3
    using TraitWorld, ..OOwn
    @trait_module
    struct Sq; s::Float64; end
    @implement OShape Sq begin
        oarea(q) = q.s^2
    end
    end))
provoke("classic: a method in a trait module", :(module OO4
    using TraitWorld
    @trait_module
    Base.length(x::Vector{Int8}) = 0
    end))
struct OHeavy; w::Int; end
provoke("owner-only: a method at the prompt, reported", :(OOwn.weight(h::OHeavy) = h.w))
Base.delete_method(which(OOwn.weight, (OHeavy,))); tally(Any[1, "a"])
TraitWorld.strict!(true)
try
    provoke("owner-only: a method at the prompt, strict mode", :(OOwn.weight(h::OHeavy) = h.w))
    provoke("owner-only by @owner_only: a method at the prompt, strict mode", :(OOwn.score(h::OHeavy) = h.w))
finally
    TraitWorld.strict!(false)
end
