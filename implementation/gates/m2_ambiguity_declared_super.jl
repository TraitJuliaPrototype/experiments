# Gate (compiler §5.4, C-78; W-132; E-347): the ambiguity report asks each method the membership
# makes applicable against the method table at the member. The cases of the C-78 plan's review:
#   A  a method at a closed declared supertype alone: no tie (a closed type beats a set), silent
#   B  a tie across positions with a method at a closed declared supertype: one warning
#   C  a tie across positions with a method at `Any`: one warning
#   E  a superset's method at a member of a set in it: one warning
#   F  a set the member is in through an entry on its declared supertype: one warning
#   G  a joint method at All{X, Y} tied with a third set's: one warning
#   H  a method at a union with a closed arm: more specific, silent
#   K  `struct S <: X` then `@implement Y S`: one warning, whatever the order
#   L  three sets: the joint of every tied method
#   H1 a set joining a set, a method at an unrelated set with a pattern member in each: silent
# and strict mode refuses B's shape and accepts H1's.
include("util.jl")

const JULIA = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`

body = """
    using Traits
    const All = Core.All
    amb(f, args...) = try
        string(f(args...))
    catch e
        e isa MethodError && occursin("ambiguous", sprint(showerror, e)) ? "ambiguous" : "wrong"
    end
    # A
    abstract type AA end
    @trait XA
    fA(::AA) = :a
    fA(::XA) = :x
    struct SA <: AA end
    @implement XA SA
    println("CHILD_A ", amb(fA, SA()))
    # B
    abstract type AB end
    @trait XB
    gB(::XB, ::Int) = :x
    gB(::AB, ::Integer) = :a
    struct SB <: AB end
    @implement XB SB
    println("CHILD_B ", amb(gB, SB(), 1))
    # C
    @trait XC
    hC(::XC, ::Integer) = :x
    hC(::Any, ::Int) = :any
    struct SC end
    @implement XC SC
    println("CHILD_C ", amb(hC, SC(), 1))
    # E
    @trait WE
    @trait XE
    @trait YE
    @implement WE XE
    pE(::WE) = :w
    pE(::YE) = :y
    struct UE end
    @implement YE UE
    @implement XE UE
    println("CHILD_E ", amb(pE, UE()))
    # F
    abstract type AF end
    @trait XF
    @trait YF
    @implement YF AF
    qF(::XF) = :x
    qF(::YF) = :y
    struct SF <: AF end
    @implement XF SF
    println("CHILD_F ", amb(qF, SF()))
    # G
    @trait XG
    @trait YG
    @trait ZG
    sG(::All{XG, YG}) = :xy
    sG(::ZG) = :z
    struct QG end
    @implement YG QG
    @implement ZG QG
    @implement XG QG
    println("CHILD_G ", amb(sG, QG()))
    # H
    @trait XH
    @trait YH
    tH(::Union{Int, XH}) = :u
    tH(::YH) = :y
    struct SH end
    @implement YH SH
    @implement XH SH
    println("CHILD_H ", amb(tH, SH()))
    # K
    @trait XK
    @trait YK
    kK(::XK) = :x
    kK(::YK) = :y
    struct SK <: XK end
    @implement YK SK
    println("CHILD_K ", amb(kK, SK()))
    # L
    @trait XL
    @trait YL
    @trait ZL
    wL(::XL) = :x
    wL(::YL) = :y
    wL(::ZL) = :z
    struct SL end
    @implement YL SL
    @implement ZL SL
    @implement XL SL
    println("CHILD_L ", amb(wL, SL()))
    # H1
    struct D1{Z} end
    @trait X1
    @trait Y1
    @trait Z1
    declare_membership(D1{Z} where Z<:X1, X1, @__MODULE__)
    declare_membership(D1{Z} where Z<:Y1, Y1, @__MODULE__)
    declare_membership(D1{Z} where Z<:Z1, Z1, @__MODULE__)
    r1(::X1) = :x
    r1(::Y1) = :y
    @implement X1 Z1
    # strict mode
    ccall(:jl_set_strict_memberships, Cint, (Cint,), 1)
    struct SB2 <: AB end
    r = try
        @implement XB SB2
        "accepted"
    catch e
        "refused: " * sprint(showerror, e)
    end
    println("CHILD_STRICT_B ", replace(r, '\\n' => ' '))
    @trait W1
    r = try
        @implement Y1 W1
        "accepted"
    catch e
        "refused: " * sprint(showerror, e)
    end
    println("CHILD_STRICT_H1 ", replace(r, '\\n' => ' '))
    println("CHILD_DONE")
"""

function child(body)
    sp, op, ep = tempname(), tempname(), tempname()
    write(sp, body)
    open(op, "w") do of
        open(ep, "w") do ef
            run(pipeline(ignorestatus(`$JULIA $sp`), stdout=of, stderr=ef))
        end
    end
    out, err = read(op, String), read(ep, String)
    rm.([sp, op, ep], force=true)
    return out, err
end

out, err = child(body)
println(out); println(err)
@assert occursin("CHILD_DONE", out) "child completed: $out $err"
warns = [m.match for m in eachmatch(r"WARNING: method [^\n]*", err)]
nw(f) = count(w -> occursin("method $f ", w), warns)
@assert occursin("CHILD_A a", out) && nw("fA") == 0 "A: a closed supertype's method wins, no warning"
@assert occursin("CHILD_B ambiguous", out) && nw("gB") == 1 "B: a tie across positions with a closed supertype's method"
@assert any(w -> occursin("method gB ", w) && occursin(r"All\{Main\.(AB|XB), Main\.(AB|XB)\}, Int64", w), warns) "B names the joint signature: $warns"
@assert occursin("CHILD_C ambiguous", out) && nw("hC") == 1 "C: a tie with a method at Any"
@assert occursin("CHILD_E ambiguous", out) && nw("pE") == 1 "E: a superset's method"
@assert occursin("CHILD_F ambiguous", out) && nw("qF") == 1 "F: a set by an entry on the declared supertype"
@assert occursin("CHILD_G ambiguous", out) && nw("sG") == 1 "G: the joint method tied with a third set's"
@assert occursin("CHILD_H u", out) && nw("tH") == 0 "H: a union with a closed arm wins, no warning"
@assert occursin("CHILD_K ambiguous", out) && nw("kK") == 1 "K: a member by its definition, then a second trait"
@assert occursin("CHILD_L ambiguous", out) && nw("wL") == 2 "L: one warning at the second set, one at the third: $warns"
@assert any(w -> occursin("method wL ", w) && occursin(r"All\{Main\.[XYZ]L, Main\.[XYZ]L, Main\.[XYZ]L\}", w), warns) "L names the joint of all three: $warns"
@assert nw("r1") == 0 "H1: a tie through a set the member is not in is no finding: $warns"
@assert occursin("CHILD_STRICT_B refused", out) && occursin("gB", out) "strict mode refuses B's shape"
@assert occursin("CHILD_STRICT_H1 accepted", out) "strict mode accepts a set joining a set beside an unrelated set's method"
println("m2_ambiguity_declared_super: OK")
