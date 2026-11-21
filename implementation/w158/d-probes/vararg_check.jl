# W-158, piece 1 (traits T-158): a vararg of members read at the box. What runs when boxes are passed at a vararg
# (the instances Julia compiles), and what the bounded check says of a vararg method, with the message's head.
#     $JN --project=$LIBD $W158/d-probes/vararg_check.jl
using TraitWorld
println("pathof ", pathof(TraitWorld), "  commit ", readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) log -1 --format=%h`))
const TW = TraitWorld

module VL
using TraitWorld
@trait VTab begin
    vn(t::VTab)::Int
end
@trait VETab begin
    @default_dynamic
    ven(t::VETab)::Int
end
export VTab, vn, VETab, ven
end
using .VL
struct VT; n::Int; end
VL.vn(t::VT) = t.n
VL.ven(t::VT) = t.n
@implement VTab VT
@implement VETab VT

short(@nospecialize(T)) = replace(string(T), "Main." => "", "VL." => "", "Core." => "")

println("== what runs: a vararg method outside a bounded scope, called with boxes")
u(ts::VTab...) = sum(t -> sum(t), ts)
d = Dynamic{VTab}(VT(1))
for k in (1, 2, 5)
    r = try u(ntuple(_ -> d, k)...) catch e; "raises " * sprint(showerror, e)[1:min(end, 90)] end
    println("   u with $k boxes: ", r)
end
println("   instances of u: ", join(sort([short(mi.specTypes) for mi in Base.specializations(only(methods(u)))]), "; "))
println("   box_signature(u): ", short(TW.box_signature(only(methods(u)))))

function verdict(label, code)
    mod = Symbol("VB", rand(UInt32))
    e = try
        Core.eval(Main, Meta.parse("module $mod\nusing TraitWorld\nusing ..VL\n@trait_module\n$code\nend"))
        nothing
    catch err
        while err isa LoadError; err = err.error; end
        err
    end
    println("== ", label, ": `", code, "`")
    println("   ", e === nothing ? "accepted" : sprint(showerror, e))
    return e === nothing ? getglobal(Main, mod) : nothing
end

verdict("a vararg of members, not bounded", "call(ts::VTab...) = sum(t -> sum(t), ts)")
M = verdict("a vararg of members, bounded", "callok(ts::VTab...) = sum(t -> vn(t), ts)")
M === nothing || println("   callok(VT(1), VT(2)) = ", Base.invokelatest(M.callok, VT(1), VT(2)),
                         "; with boxes = ", Base.invokelatest(M.callok, Dynamic{VTab}(VT(1)), Dynamic{VTab}(VT(2))))
verdict("a fixed trait argument and a vararg, the vararg not bounded", "cfv(a::VTab, ts::VTab...) = vn(a) + sum(t -> sum(t), ts)")
M = verdict("a fixed trait argument and a vararg, bounded", "cfvok(a::VTab, ts::VTab...) = vn(a) + sum(vn, ts)")
M === nothing || println("   cfvok(VT(1), VT(2), VT(3)) = ", Base.invokelatest(M.cfvok, VT(1), VT(2), VT(3)))
verdict("a vararg with a fixed count", "c2(ts::Vararg{VTab, 2}) = sum(t -> sum(t), ts)")
verdict("a vararg typed by a where variable", "cw(ts::T...) where {T <: VTab} = sum(t -> sum(t), ts)")
verdict("a vararg at a trait that erases by default, not bounded", "eva(ts::VETab...) = sum(t -> sum(t), ts)")
M = verdict("a vararg at a trait that erases by default, bounded", "evaok(ts::VETab...) = sum(ven, ts)")
M === nothing || println("   evaok(VT(1), VT(2)) = ", Base.invokelatest(M.evaok, VT(1), VT(2)))
verdict("a vararg indexed", "cfirst(ts::VTab...) = first(ts[1])")
verdict("a vararg with no trait", "cplain(xs::Int...) = sum(xs)")
