# Session 22: held layout against reference layout for a trait object (keys plan, the user's
# question: "f(t::Trait{U,T}) ... could just desugar to f{U,T}(t::Any) t.data::U + t.data2::T").
#
# A worker compiled once per key reads the user's fields either
#   - held:      copied into the view at the entry (a snapshot), or
#   - reference: from the user's object, at byte offsets passed in at run time,
# against plain Julia, which compiles the loop per user type. Worker-shaped kernels:
#   K1 a reduction reading t.data[i] and t.p in the loop,
#   K2 the same writing into another array (stores in the loop),
#   K3 a field write per iteration (t.t += dt), isbits,
#   K4 K2 with the fields read once before the loop (the function-barrier habit),
#   K5 a short call: three field reads and a write, n = 1.
# Run alone: julia +1.13.2 --startup-file=no -O2 lens/layout_bench.jl

mutable struct MU; label::String; data::Vector{Float64}; p::Float64; t::Float64; end   # mutable user type
struct IU; t::Float64; p::Float64; data::Vector{Float64}; end                        # immutable, other order
mutable struct MU2; data::Vector{Float64}; t::Float64; p::Float64; tag::Symbol; end  # a second mutable type

# --- views ---------------------------------------------------------------------------------
struct Held; data::Vector{Float64}; p::Float64; o::Any; offt::Int; end   # t written through the object
struct RefV; o::Any; offdata::Int; offp::Int; offt::Int; end
held(u) = Held(u.data, u.p, u, fieldoffset(typeof(u), Base.fieldindex(typeof(u), :t)))
refv(u) = (T = typeof(u); RefV(u, [fieldoffset(T, Base.fieldindex(T, f)) for f in (:data, :p, :t)]...))

@inline _base(o) = ccall(:jl_value_ptr, Ptr{Cvoid}, (Any,), o)
@inline getdata(v::Held) = v.data
@inline getp(v::Held) = v.p
@inline gett(v::Held) = GC.@preserve v unsafe_load(Ptr{Float64}(_base(v.o) + v.offt))
@inline sett!(v::Held, x::Float64) = GC.@preserve v unsafe_store!(Ptr{Float64}(_base(v.o) + v.offt), x)
@inline getdata(v::RefV) = GC.@preserve v unsafe_pointer_to_objref(unsafe_load(Ptr{Ptr{Cvoid}}(_base(v.o) + v.offdata)))::Vector{Float64}
@inline getp(v::RefV) = GC.@preserve v unsafe_load(Ptr{Float64}(_base(v.o) + v.offp))
@inline gett(v::RefV) = GC.@preserve v unsafe_load(Ptr{Float64}(_base(v.o) + v.offt))
@inline sett!(v::RefV, x::Float64) = GC.@preserve v unsafe_store!(Ptr{Float64}(_base(v.o) + v.offt), x)
# reference layout with Julia's own alias metadata (TBAA "jtbaa_mutab"), as a runtime would emit
# the loads; on stock Julia through llvmcall
struct RefT; o::Any; offdata::Int; offp::Int; offt::Int; end
reft(u) = (T = typeof(u); RefT(u, [fieldoffset(T, Base.fieldindex(T, f)) for f in (:data, :p, :t)]...))
const TBAA = """
!0 = !{!"jtbaa"}
!1 = !{!"jtbaa", !0, i64 0}
!2 = !{!"jtbaa_value", !1, i64 0}
!3 = !{!"jtbaa_mutab", !2, i64 0}
!4 = !{!3, !3, i64 0}
"""
const LDF = ("define double @entry(ptr %p) #0 {\n  %v = load double, ptr %p, align 8, !tbaa !4\n  ret double %v\n}\nattributes #0 = { alwaysinline }\n" * TBAA, "entry")
const LDP = ("define ptr @entry(ptr %p) #0 {\n  %v = load ptr, ptr %p, align 8, !tbaa !4\n  ret ptr %v\n}\nattributes #0 = { alwaysinline }\n" * TBAA, "entry")
const STF = ("define void @entry(ptr %p, double %x) #0 {\n  store double %x, ptr %p, align 8, !tbaa !4\n  ret void\n}\nattributes #0 = { alwaysinline }\n" * TBAA, "entry")
@inline ldf(p::Ptr{Float64}) = Base.llvmcall(LDF, Float64, Tuple{Ptr{Float64}}, p)
@inline ldp(p::Ptr{Ptr{Cvoid}}) = Base.llvmcall(LDP, Ptr{Cvoid}, Tuple{Ptr{Ptr{Cvoid}}}, p)
@inline stf(p::Ptr{Float64}, x::Float64) = Base.llvmcall(STF, Cvoid, Tuple{Ptr{Float64},Float64}, p, x)
@inline getdata(v::RefT) = GC.@preserve v unsafe_pointer_to_objref(ldp(Ptr{Ptr{Cvoid}}(_base(v.o) + v.offdata)))::Vector{Float64}
@inline getp(v::RefT) = GC.@preserve v ldf(Ptr{Float64}(_base(v.o) + v.offp))
@inline gett(v::RefT) = GC.@preserve v ldf(Ptr{Float64}(_base(v.o) + v.offt))
@inline sett!(v::RefT, x::Float64) = GC.@preserve v stf(Ptr{Float64}(_base(v.o) + v.offt), x)
# plain Julia: the user type itself
@inline getdata(u::Union{MU,IU,MU2}) = u.data
@inline getp(u::Union{MU,IU,MU2}) = u.p
@inline gett(u::Union{MU,IU,MU2}) = u.t
@inline sett!(u::Union{MU,MU2}, x::Float64) = (u.t = x; nothing)

# --- kernels -------------------------------------------------------------------------------
function k1(v, n)
    s = 0.0
    for i in 1:n
        s += @inbounds getdata(v)[i] * getp(v)
    end
    s
end
function k2(v, du, n)
    for i in 1:n
        @inbounds du[i] = getdata(v)[i] * getp(v)
    end
end
function k3(v, n)
    for i in 1:n
        sett!(v, gett(v) + 1e-3)
    end
end
function k4(v, du, n)
    d = getdata(v); p = getp(v)
    for i in 1:n
        @inbounds du[i] = d[i] * p
    end
end
k5(v) = (x = getdata(v)[1] * getp(v) + gett(v); sett!(v, x); x)

const SINK = Ref(0.0)
function best(f, reps)
    f()
    b = Inf
    for _ in 1:7
        t = @elapsed for _ in 1:reps; f(); end
        b = min(b, t)
    end
    b / reps
end

function run(n)
    data = rand(n); du = similar(data)
    mu = MU("x", copy(data), 2.0, 0.0); mu2 = MU2(copy(data), 0.0, 2.0, :a); iu = IU(0.0, 2.0, copy(data))
    reps = max(1, 2^24 ÷ n)
    rows = Tuple{String,Any}[("plain MU", mu), ("plain MU2", mu2), ("held(MU)", held(mu)), ("held(MU2)", held(mu2)),
                             ("ref(MU)", refv(mu)), ("ref(MU2)", refv(mu2)), ("ref(IU)", refv(iu)),
                             ("reft(MU)", reft(mu)), ("reft(MU2)", reft(mu2)), ("reft(IU)", reft(iu))]
    println("n = $n (ns per element; K5 ns per call)")
    println(rpad("layout", 12), rpad("K1 reduce", 12), rpad("K2 store", 12), rpad("K3 t+=", 12), rpad("K4 hoisted", 12), "K5 call")
    for (name, v) in rows
        r1 = best(() -> (SINK[] += k1(v, n)), reps) / n * 1e9
        r2 = best(() -> k2(v, du, n), reps) / n * 1e9
        isimm = v isa IU || (v isa Union{RefV,RefT} && v.o isa IU)
        r3 = isimm ? NaN : best(() -> k3(v, n), reps) / n * 1e9
        r4 = best(() -> k4(v, du, n), reps) / n * 1e9
        r5 = isimm ? NaN : best(() -> k5(v), 2^22) * 1e9
        println(rpad(name, 12), rpad(round(r1, digits = 3), 12), rpad(round(r2, digits = 3), 12), rpad(round(r3, digits = 3), 12),
                rpad(round(r4, digits = 3), 12), round(r5, digits = 2))
    end
    # one compiled kernel serves every user type in the reference layout
    println("specializations of k2: ", length(collect(Base.specializations(only(methods(k2))))))
end

println(VERSION)
run(16)
run(4096)
