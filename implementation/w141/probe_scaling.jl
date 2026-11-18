# E-367, stage 0 (W-141), R1: how insertion and lookup scale with the members of ONE trait,
# for the two spellings of a concrete member: Type{<:S} and Type{S}.
# Run: julia --startup-file=no probe_scaling.jl
function sub end      # (::Type{X}, ::Type{<:S})
function exact end    # (::Type{X}, ::Type{S})
abstract type X0 end
abstract type X1 end
struct Probe end
w() = Base.get_world_counter()
look(sig) = Base._methods_by_ftype(sig, -1, w())
function step(f, lo, hi, sig)
    t = @elapsed for i in lo:hi
        S = Symbol(nameof(f), :_S, i)
        @eval struct $S end
        @eval $(nameof(f))(::Type{X0}, ::Type{$(sig(S))}) = nothing
    end
    S17 = Core.eval(Main, Symbol(nameof(f), :_S, 17))
    hit = Tuple{typeof(f), Type{X0}, Type{S17}}; miss = Tuple{typeof(f), Type{X0}, Type{Probe}}
    other = Tuple{typeof(f), Type{X1}, Type{Probe}}
    look(hit); look(miss)
    th = @elapsed for _ in 1:200; look(hit); end
    tm = @elapsed for _ in 1:200; look(miss); end
    to = @elapsed for _ in 1:200; look(other); end
    println(rpad(nameof(f), 6), " members ", lpad(hi, 5), ": insert ", round(t / (hi - lo + 1) * 1e6; digits = 0),
            " us each; lookup hit ", round(th / 200 * 1e6; digits = 1), " us, miss ", round(tm / 200 * 1e6; digits = 1),
            " us, another trait ", round(to / 200 * 1e6; digits = 1), " us")
    flush(stdout)
end
for f in (exact, sub)
    sig = f === exact ? (S -> S) : (S -> :(<:$S))
    lo = 1
    for hi in (250, 500, 1000, 2000)
        step(f, lo, hi, sig); lo = hi + 1
    end
    t = @elapsed ms = methods(f)
    println(rpad(nameof(f), 6), " methods(): ", length(ms), " in ", round(t * 1e3; digits = 1), " ms"); flush(stdout)
end
