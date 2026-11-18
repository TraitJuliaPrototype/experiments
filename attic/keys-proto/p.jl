# Prototype: conformances as methods, entries as trampolines, workers per key, reference layout.
const MD = """
!0 = !{!"jtbaa"}
!1 = !{!"jtbaa", !0, i64 0}
!2 = !{!"jtbaa_value", !1, i64 0}
!3 = !{!"jtbaa_mutab", !2, i64 0}
!4 = !{!3, !3, i64 0}
"""
const LDP = ("define ptr @entry(ptr %p) #0 {\n  %v = load ptr, ptr %p, align 8, !tbaa !4\n  ret ptr %v\n}\nattributes #0 = { alwaysinline }\n" * MD, "entry")
@inline ldp(p::Ptr{Ptr{Cvoid}}) = Base.llvmcall(LDP, Ptr{Cvoid}, Tuple{Ptr{Ptr{Cvoid}}}, p)
@inline objptr(o) = ccall(:jl_value_ptr, Ptr{Cvoid}, (Any,), o)

abstract type ColTable end
"A trait object: the user's object and the offset of the implementing value (-1: the object itself); the key K in the type."
# held implementing value r; the user's object o when it is mutable (its fields can be rebound), else nothing
struct TO{X,K}; r::K; o::Any; off::Int; end
@inline rep(t::TO{X,K}) where {X,K} = (o = t.o; o === nothing || t.off < 0) ? t.r : unsafe_pointer_to_objref(ldp(Ptr{Ptr{Cvoid}}(objptr(o) + t.off)))::K
# the implementation for the library's own type
ncols(r::Vector{Vector{Float64}}) = length(r)
value(r::Vector{Vector{Float64}}, i::Int, j::Int) = @inbounds r[i][j]
@inline ncols(t::TO{ColTable}) = ncols(rep(t))::Int
@inline value(t::TO{ColTable}, i::Int, j::Int) = value(rep(t), i, j)::Float64
# the worker: compiled per key
@noinline function total_w(t::TO{ColTable}, len::Int)
    s = 0.0
    for i in 1:ncols(t), j in 1:len
        s += value(t, i, j)
    end
    s
end
# conformances as methods (what @implement would emit)
struct Meas; label::String; data::Vector{Vector{Float64}}; end
mutable struct MMeas; data::Vector{Vector{Float64}}; n::Int; end
@inline view(::Type{ColTable}, u::Vector{Vector{Float64}}) = TO{ColTable,Vector{Vector{Float64}}}(u, nothing, -1)
@eval @inline view(::Type{ColTable}, u::Meas) = TO{ColTable,Vector{Vector{Float64}}}(u.data, nothing, $(Int(fieldoffset(Meas, 2))))
@eval @inline view(::Type{ColTable}, u::MMeas) = TO{ColTable,Vector{Vector{Float64}}}(u.data, u, $(Int(fieldoffset(MMeas, 1))))
# the entry: a trampoline, specialized per argument type
total(t, len::Int) = total_w(view(ColTable, t), len)
plain(v::Vector{Vector{Float64}}, len) = (s = 0.0; for i in 1:length(v), j in 1:len; s += @inbounds v[i][j]; end; s)

loopT(x, n, len) = (s = 0.0; for _ in 1:n; s += total(x, len); end; s)
loopP(x, n, len) = (s = 0.0; for _ in 1:n; s += plain(x, len); end; s)
loopA(xs::Vector{Any}, n, len) = (s = 0.0; for _ in 1:n; s += total(xs[1], len)::Float64; end; s)   # an untyped caller
tm(f, args...) = (f(args...); minimum(@elapsed(f(args...)) for _ in 1:5))
v = [rand(16) for _ in 1:4]
for len in (16, 4096)
    n = 2^22 ÷ (4len)
    println("len $len (ns per call):")
    println("  plain           ", round(tm(loopP, v, n, len) / n * 1e9, digits = 1))
    for (name, x) in (("own", v), ("forward Meas", Meas("a", [rand(len) for _ in 1:4])), ("forward MMeas", MMeas([rand(len) for _ in 1:4], 1)))
        x isa Vector || (len == 16 || true)
        y = x isa Vector ? [rand(len) for _ in 1:4] : x
        println("  ", rpad(name, 16), round(tm(loopT, y, n, len) / n * 1e9, digits = 1), "   untyped caller ", round(tm(loopA, Any[y], n, len) / n * 1e9, digits = 1),
                "   alloc/call ", @allocated(loopT(y, 100, len)) / 100)
    end
end
println("worker specializations: ", length(collect(Base.specializations(only(methods(total_w))))))
