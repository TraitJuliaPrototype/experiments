include(joinpath(@__DIR__, "p.jl"))
# a fresh type: the conformance method and the first call (trampoline + worker already compiled for the key)
t0 = time_ns()
@eval struct NewT; tag::Symbol; data::Vector{Vector{Float64}}; end
@eval @inline view(::Type{ColTable}, u::NewT) = TO{ColTable,Vector{Vector{Float64}}}(u.data, nothing, $(Int(fieldoffset(NewT, 2))))
t1 = time_ns()
x = NewT(:a, [rand(16) for _ in 1:4])
total(x, 16)
t2 = time_ns()
println("define + conformance method: ", round((t1 - t0) / 1e6, digits = 2), " ms; first call (trampoline compile): ", round((t2 - t1) / 1e6, digits = 2), " ms")
# ten more library functions' trampolines for the same type
for k in 1:10
    @eval $(Symbol(:fn, k))(t, len::Int) = total_w(view(ColTable, t), len) + $k
end
t3 = time_ns()
for k in 1:10
    getfield(Main, Symbol(:fn, k))(x, 16)
end
println("10 further trampolines: ", round((time_ns() - t3) / 1e6, digits = 2), " ms")
