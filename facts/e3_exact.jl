# E3: is stock Julia's invalidation exact for edges at concrete signatures?
# A caller g holds a concrete fact "f at Tuple{Float64} selects f(::Real)". Each case defines one
# new method in a fresh module and reports whether g's compiled code survived, and whether the
# new method wins at Float64 (when it does, plain Julia's answer changes: invalidation is required).
cases = [
    ("loses: f(::Number), less specific",                  :(f(x::Number) = 0)),
    ("does not apply: f(::Int8)",                          :(f(x::Int8) = 0)),
    ("does not apply: f(::String)",                        :(f(x::String) = 0)),
    ("wins: f(::Float64)",                                 :(f(x::Float64) = 0)),
    ("wins: f(::AbstractFloat)",                           :(f(x::AbstractFloat) = 0)),
    ("wins: f(::Union{Float64,Int8})",                     :(f(x::Union{Float64,Int8}) = 0)),
    ("loses, 2 args: f(::Real, ::Any) vs f(::Real, ::Real)", nothing),
]
function run_case(label, def)
    m = Module(gensym(:E3))
    Core.eval(m, :(f(x::Real) = 1))
    Core.eval(m, :(@noinline g(x::Float64) = f(x) + 1))
    Core.eval(m, :(g(1.0)))
    mi = only(Base.specializations(only(methods(m.g))))
    ci = mi.cache
    before = Core.eval(m, :(g(1.0)))
    Core.eval(m, def)
    valid = ci.max_world == typemax(UInt)
    after = Core.eval(m, :(g(1.0)))
    wins = after != before
    println(rpad(label, 52), " wins: ", rpad(wins, 6), " invalidated: ", rpad(!valid, 6), wins == !valid ? "  exact" : (wins ? "  STALE (wrong)" : "  over-invalidated"))
end
for (l, d) in cases
    d === nothing && continue
    run_case(l, d)
end
# two arguments: the fact is at Tuple{Float64,Float64}
for (label, def) in (("2 args, loses: h(::Real, ::Any)", :(h(x::Real, y) = 0)),
                     ("2 args, ambiguous with h(::Real,::Real): h(::Float64, ::Any) and h(::Any, ::Float64)", :(begin h(x::Float64, y) = 0; h(x, y::Float64) = 0; end)),
                     ("2 args, wins: h(::Float64, ::Real)", :(h(x::Float64, y::Real) = 0)))
    m = Module(gensym(:E3h))
    Core.eval(m, :(h(x::Real, y::Real) = 1))
    Core.eval(m, :(@noinline g(x::Float64) = h(x, x) + 1))
    Core.eval(m, :(g(1.0)))
    ci = only(Base.specializations(only(methods(m.g)))).cache
    before = Core.eval(m, :(g(1.0)))
    Core.eval(m, def)
    valid = ci.max_world == typemax(UInt)
    after = try Core.eval(m, :(g(1.0))) catch e; typeof(e) end
    wins = after != before
    println(rpad(label, 52), " changes: ", rpad(wins, 6), " invalidated: ", rpad(!valid, 6), wins == !valid ? "  exact" : (wins ? "  STALE (wrong)" : "  over-invalidated"))
end
