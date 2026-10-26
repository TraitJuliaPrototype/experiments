# Probes for the fresh-eye review of reference/traits.md (2026-10-26). Read-only: nothing is written.
using TraitWorld

tl(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)
function try_tl(name, ex)
    try
        r = tl(ex)
        println("P ", name, " => ", repr(r)[1:min(end, 160)])
    catch e
        while e isa LoadError; e = e.error; end
        println("P ", name, " => ", typeof(e), ": ", sprint(showerror, e)[1:min(end, 220)])
    end
end

# --- P1: dispatch among bounds of one trait at different fixed parameters, and a value at a third
try_tl("P1 define", quote
    @trait_module module M1
    using TraitWorld
    @trait SV{T} begin
        T = eltype(Self)
        sv_len(v::SV)::Int
    end
    @implement SV A where {A <: Vector} begin
        sv_len(v) = length(v)
    end
    f(v::SV{Float64}) = :f64
    f(v::SV{Float32}) = :f32
    f(x) = :fallback
    end
    g64() = M1.f([1.0]); g32() = M1.f([1f0]); gint() = M1.f([1]); gstr() = M1.f("s")
    nothing
end)
try_tl("P1 typed Float64", :(g64()))
try_tl("P1 typed Float32", :(g32()))
try_tl("P1 typed Int (conforms at another parameter)", :(gint()))
try_tl("P1 typed String (conforms to nothing)", :(gstr()))
try_tl("P1 prompt Int", :(M1.f([1])))
try_tl("P1 prompt Float32", :(M1.f([1f0])))

# --- P2: an operation whose second argument is typed by the trait's name
try_tl("P2 define", quote
    @trait_module module M2
    using TraitWorld
    @trait Sh begin
        area(s::Sh)::Float64
        overlap(a::Sh, b::Sh)::Float64
    end
    tot(a::Sh, b::Sh) = overlap(a, b)
    end
    struct C2; r::Float64; end
    M2.area(c::C2) = c.r
    M2.overlap(a::C2, b) = a.r + 1.0
    @implement M2.Sh C2
    nothing
end)
try_tl("P2 call tot", :(M2.tot(C2(1.0), C2(2.0))))
try_tl("P2 op_args of overlap", :(TraitWorld.op_args(M2.Sh, Val(:overlap), C2, Val(2))))

# --- P3: Kept{X}(x) of a trait without a default: at the prompt and in typed code
try_tl("P3 prompt Kept", :(Kept{M2.Sh}(C2(1.0))))
try_tl("P3 typed Kept", :((() -> Kept{M2.Sh}(C2(1.0)))()))
try_tl("P3 prompt bound", :(M2.area_tobj = nothing))
try_tl("P3 define probe fn", quote
    @trait_module module M3
    using TraitWorld
    seen(s::Main.M2.Sh) = string(typeof(s))
    end
    nothing
end)
try_tl("P3 prompt bound attribute", :(M3.seen(C2(1.0))))
try_tl("P3 typed bound attribute", :((() -> M3.seen(C2(1.0)))()))

# --- P4: @implement of a bundle: does it implement the members, or require them?
try_tl("P4 define", quote
    @trait_module module M4
    using TraitWorld
    @trait A4 begin; fa(x::A4)::Int; end
    @trait B4 begin; fb(x::B4)::Int; end
    @trait AB4 <: (A4, B4)
    both(x::AB4) = fa(x) + fb(x)
    end
    struct G4; n::Int; end
    M4.fa(g::G4) = g.n; M4.fb(g::G4) = 2g.n
    nothing
end)
try_tl("P4 @implement AB4 G4 (bundle, members not declared)", :(@implement M4.AB4 G4))
try_tl("P4 both(G4) after it", :(M4.both(G4(1))))
try_tl("P4 conforms(G4, A4)", :(conforms(G4, M4.A4)))
try_tl("P4 @implement (A4, B4) G4 (tuple)", :(@implement (M4.A4, M4.B4) G4))
try_tl("P4 both(G4) after tuple", :(M4.both(G4(1))))

# --- P5: a family with a block in the parametric-type form, inside the owner's module (T-57 cites retired T-5)
try_tl("P5 define", quote
    @trait_module module M5
    using TraitWorld
    @trait KV{T} begin
        T = eltype(Self)
        kl(v::KV)::Int
    end
    struct S5{T}; v::Vector{T}; end
    Base.eltype(::Type{S5{T}}) where {T} = T
    @implement KV S5{T} where {T} begin
        kl(v) = length(v.v)
    end
    use(v::KV) = kl(v)
    end
    nothing
end)
try_tl("P5 use(S5)", :(M5.use(M5.S5([1.0]))))

# --- P8: a kept value of a subtrait at a bound of its supertrait, from plain code
try_tl("P8 define", quote
    @trait_module module M8
    using TraitWorld
    @trait A8 begin; ga(x::A8)::Int; end
    @trait B8 <: A8 begin; gb(x::B8)::Int; end
    usea(x::A8) = ga(x)
    end
    struct H8; n::Int; end
    M8.ga(h::H8) = h.n; M8.gb(h::H8) = 2h.n
    @implement M8.A8 H8
    @implement M8.B8 H8
    nothing
end)
try_tl("P8 usea(Kept{B8})", :(M8.usea(Kept{M8.B8}(H8(1)))))
try_tl("P8 ga(Kept{B8}) (T-72)", :(M8.ga(Kept{M8.B8}(H8(1)))))
println("done")
