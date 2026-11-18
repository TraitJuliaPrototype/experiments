# E-269 (X3; W-99's gate): what do methods at an open set on Base's getindex, iterate and length cost
# plain code? Run per build and member count:
#     X3_MEMBERS=<k> <tree>/julia --startup-file=no x3.jl <label>
# Per query or call, ns, the median of 7 rounds:
# - method matching (the lookup inference and a dispatch miss do): Base._methods_by_ftype for
#   getindex, iterate, length at 50 concrete container types;
# - dynamic dispatch, steady state: length and getindex(c, 1) on 50 containers held as Any;
# - a member's dynamic call (k > 0).
include(joinpath(@__DIR__, "install.jl"))
using Printf
label = ARGS[1]
out = joinpath(@__DIR__, "out"); mkpath(out)
io = open(joinpath(out, "$label.txt"), "w")
say(s) = (println(s); println(io, s); flush(io))
say("E-269 $label on $(Base.GIT_VERSION_INFO.commit_short), members $K, machine load $(read("/proc/loadavg", String)[1:14])")

eltypes = Any[Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float16, Float32, Float64,
              ComplexF64, Bool, Char, String, Symbol, Any, Nothing, Rational{Int}, BigInt, Int128,
              UInt128, Missing, Some{Int}, Pair{Int,Int}]
mk(T) = T === Any ? Any[1] : T === Nothing ? Nothing[nothing] : T === Missing ? Missing[missing] :
        T === String ? ["a"] : T === Symbol ? [:a] : T === Char ? ['a'] : T === Some{Int} ? [Some(1)] :
        T === Pair{Int,Int} ? [1 => 2] : T === BigInt ? [big(1)] : T[one(T)]
containers = Any[]
for T in eltypes
    push!(containers, mk(T))             # Vector{T}
    push!(containers, T === Any ? (1, "a") : (mk(T)[1], mk(T)[1]))   # Tuple{T,T}; Tuple{Int,String} for Any
end
@assert length(unique(typeof.(containers))) == 50
ctypes = unique(typeof.(containers))

function per_query(f, ts, n)
    w = Base.get_world_counter()
    t0 = time_ns()
    for _ in 1:n, T in ts
        Base._methods_by_ftype(Tuple{typeof(f), T, Vararg{Any}}, -1, w)
    end
    return (time_ns() - t0) / (n * length(ts))
end
med(g) = (v = sort([g() for _ in 1:7]); v[4])
for f in (getindex, iterate, length)
    say(@sprintf("  match %-9s at 50 container types        %9.1f ns", f, med(() -> per_query(f, ctypes, 200))))
end

@noinline function dyn_length(cs::Vector{Any}, n)
    s = 0
    for _ in 1:n, c in cs
        s += length(c)::Int
    end
    return s
end
@noinline function dyn_getindex(cs::Vector{Any}, n)
    s = 0
    for _ in 1:n, c in cs
        s += (getindex(c, 1) === nothing)
    end
    return s
end
dyn_length(containers, 1); dyn_getindex(containers, 1)
per_call(g, cs, n) = (t0 = time_ns(); g(cs, n); (time_ns() - t0) / (n * length(cs)))
say(@sprintf("  dynamic length(c) over 50 containers               %9.1f ns", med(() -> per_call(dyn_length, containers, 20_000))))
say(@sprintf("  dynamic getindex(c, 1) over 50 containers          %9.1f ns", med(() -> per_call(dyn_getindex, containers, 20_000))))
if K > 0
    ms = Any[getglobal(Main, Symbol(:Member, i))() for i in 1:min(K, 50)]
    dyn_length(ms, 1)
    say(@sprintf("  dynamic length(m) over %3d members                  %9.1f ns", length(ms), med(() -> per_call(dyn_length, ms, 20_000))))
end
close(io)
