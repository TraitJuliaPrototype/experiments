# E-367 (W-141), review of 2026-11-12: a third spelling of a membership's method, at the member as an
# argument type: (::Type{X}, ::S). On plain functions, as probe_scaling.jl. Asks:
# (1) insertion and lookup for 2,000 concrete members, and for 2,000 abstract members, against Type{<:A};
# (2) what Test.detect_ambiguities reports for abstract members of one trait under each spelling.
# Run: julia --startup-file=no probe_valuesig.jl
using Test
function val end      # (::Type{X}, ::S)        concrete members
function vala end     # (::Type{X}, ::A)        abstract members
function suba end     # (::Type{X}, ::Type{<:A}) abstract members
abstract type X0 end
struct Probe end
w() = Base.get_world_counter()
look(sig) = Base._methods_by_ftype(sig, -1, w())
function step(f, lo, hi, abstract, arg, q)
    t = @elapsed for i in lo:hi
        S = Symbol(nameof(f), :_S, i)
        abstract ? (@eval abstract type $S end) : (@eval struct $S end)
        @eval $(nameof(f))(::Type{X0}, $(arg(S))) = nothing
    end
    S17 = Core.eval(Main, Symbol(nameof(f), :_S, 17))
    hit = Tuple{typeof(f), Type{X0}, q(S17)}; miss = Tuple{typeof(f), Type{X0}, q(Probe)}
    look(hit); look(miss)
    th = @elapsed for _ in 1:200; look(hit); end
    tm = @elapsed for _ in 1:200; look(miss); end
    println(rpad(nameof(f), 6), " members ", lpad(hi, 5), ": insert ", round(t / (hi - lo + 1) * 1e6; digits = 0),
            " us each; lookup hit ", round(th / 200 * 1e6; digits = 1), " us (", length(look(hit)), "), miss ",
            round(tm / 200 * 1e6; digits = 1), " us (", length(look(miss)), ")")
    flush(stdout)
end
for (f, abstract, arg, q) in ((val, false, S -> :(::$S), S -> S), (vala, true, S -> :(::$S), S -> S),
                              (suba, true, S -> :(::Type{<:$S}), S -> Type{S}))
    lo = 1
    for hi in (250, 500, 1000, 2000)
        step(f, lo, hi, abstract, arg, q); lo = hi + 1
    end
    t = @elapsed ms = methods(f)
    println(rpad(nameof(f), 6), " methods(): ", length(ms), " in ", round(t * 1e3; digits = 1), " ms"); flush(stdout)
end
# (2) ambiguities among abstract members of one trait, 20 each, in a module of their own
module AmbV; abstract type X end; function f end
for i in 1:20; A = Symbol(:A, i); @eval abstract type $A end; @eval f(::Type{X}, ::$A) = nothing; end; end
module AmbT; abstract type X end; function f end
for i in 1:20; A = Symbol(:A, i); @eval abstract type $A end; @eval f(::Type{X}, ::Type{<:$A}) = nothing; end; end
println("detect_ambiguities, 20 abstract members: (::A) ", length(Test.detect_ambiguities(AmbV)),
        "; (::Type{<:A}) ", length(Test.detect_ambiguities(AmbT)))
