# W-158, the library's pieces continued: which argument positions the forwarder boxes and which the bounded
# check reads at the box (traits §7.3, §7.8; compiler §6.3, §6.7). For each position, at a trait that does not
# erase (`PTab`) and at one that erases by default (`ETab`): the methods a definition makes (forwarder or not),
# the signature the check reads (`box_signature`, or nothing), and what the body sees when it is called with a
# plain member (`typeof` of the argument: the member's type, or the box's).
#     $JN --project=$LIBD $W158/d-probes/positions.jl
using TraitWorld
println("pathof ", pathof(TraitWorld))
const TW = TraitWorld

module PL
using TraitWorld
@trait PTab begin
    pn(t::PTab)::Int
end
@trait ETab begin
    @default_dynamic
    en(t::ETab)::Int
end
export PTab, pn, ETab, en
end
using .PL
struct M1; end
struct M2; end
PL.pn(::M1) = 1; PL.pn(::M2) = 2; PL.en(::M1) = 1; PL.en(::M2) = 2
@implement PTab M1
@implement PTab M2
@implement ETab M1
@implement ETab M2

short(@nospecialize(T)) = replace(string(T), "Main." => "", "Main.PL." => "", "Core." => "")
function report(f, label, call)
    println("== ", label)
    for m in methods(f)
        kind = TW._is_forwarder(m) ? "forwarder" : "method"
        bs = TW.box_signature(m)
        println("   ", kind, "  ", short(m.sig), "\n      checked: ", TW._at_box_checked(m),
                "  reads: ", bs === nothing ? "nothing" : short(bs))
    end
    r = try short(call()) catch e; "ERROR " * sprint(showerror, e)[1:min(end, 200)] end
    println("   call with plain members: ", r)
end

for X in (:PTab, :ETab)
    @eval begin
        $(Symbol(:fixed_, X))(t::$X) = typeof(t)
        $(Symbol(:va_, X))(ts::$X...) = map(typeof, ts)
        $(Symbol(:fixva_, X))(a::$X, ts::$X...) = (typeof(a), map(typeof, ts))
        $(Symbol(:van_, X))(ts::Vararg{$X, 2}) = map(typeof, ts)
        $(Symbol(:vawhere_, X))(ts::T...) where {T <: $X} = map(typeof, ts)
        $(Symbol(:kw_, X))(; k::$X) = typeof(k)
        $(Symbol(:kwfix_, X))(t::$X; k::$X) = (typeof(t), typeof(k))
        $(Symbol(:union_, X))(t::Union{$X, Nothing}) = typeof(t)
        $(Symbol(:tuple_, X))(t::Tuple{$X, $X}) = map(typeof, t)
        $(Symbol(:opt_, X))(t::$X, k::Int = 1) = (typeof(t), k)
        $(Symbol(:optt_, X))(k::Int, t::$X = M1()) = (typeof(t), k)
        $(Symbol(:vec_, X))(v::Vector{<:$X}) = map(typeof, v)
    end
    println("\n######## ", X, X === :ETab ? " (erases by default)" : " (does not erase)")
    report(getglobal(Main, Symbol(:fixed_, X)), "fixed t::$X", () -> getglobal(Main, Symbol(:fixed_, X))(M1()))
    report(getglobal(Main, Symbol(:va_, X)), "vararg ts::$X...", () -> getglobal(Main, Symbol(:va_, X))(M1(), M2()))
    report(getglobal(Main, Symbol(:fixva_, X)), "fixed and vararg a::$X, ts::$X...", () -> getglobal(Main, Symbol(:fixva_, X))(M1(), M1(), M2()))
    report(getglobal(Main, Symbol(:van_, X)), "Vararg{$X, 2}", () -> getglobal(Main, Symbol(:van_, X))(M1(), M2()))
    report(getglobal(Main, Symbol(:vawhere_, X)), "ts::T... where T <: $X", () -> getglobal(Main, Symbol(:vawhere_, X))(M1(), M1()))
    f = getglobal(Main, Symbol(:kw_, X))
    report(f, "keyword k::$X (the sorter and the body are below)", () -> f(; k = M1()))
    body = Base.bodyfunction(first(methods(f)))
    body === nothing || report(body, "  its body", () -> nothing)
    for m in methods(Core.kwcall, Tuple{Any, typeof(f), Vararg{Any}})
        println("   sorter  ", short(m.sig), "  checked: ", TW._at_box_checked(m), "  forwarder: ", TW._is_forwarder(m))
    end
    f = getglobal(Main, Symbol(:kwfix_, X))
    report(f, "fixed and keyword t::$X; k::$X", () -> f(M1(); k = M2()))
    for m in methods(f)
        b = Base.bodyfunction(m)
        b === nothing || (report(b, "  its body", () -> nothing); break)
    end
    report(getglobal(Main, Symbol(:union_, X)), "Union{$X, Nothing}", () -> getglobal(Main, Symbol(:union_, X))(M1()))
    report(getglobal(Main, Symbol(:tuple_, X)), "Tuple{$X, $X}", () -> getglobal(Main, Symbol(:tuple_, X))((M1(), M2())))
    report(getglobal(Main, Symbol(:opt_, X)), "optional after: t::$X, k::Int = 1", () -> getglobal(Main, Symbol(:opt_, X))(M1()))
    report(getglobal(Main, Symbol(:optt_, X)), "optional at the trait: k::Int, t::$X = M1()", () -> getglobal(Main, Symbol(:optt_, X))(1))
    report(getglobal(Main, Symbol(:vec_, X)), "Vector{<:$X}", () -> getglobal(Main, Symbol(:vec_, X))([M1()]))
end
