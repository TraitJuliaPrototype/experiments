# E-364: the closed build's split seen from a session: the trim option set in the running process, so
# that inference and the inliner take the closed-build rule (compiler §7.6). For looking at typed code.
include(joinpath(@__DIR__, "apps", "geometry_trait.jl"))
let i = findfirst(==(:trim), fieldnames(Base.JLOptions))
    unsafe_store!(Ptr{Int8}(cglobal(:jl_options)) + fieldoffset(Base.JLOptions, i), Int8(1))
end
# the compiler as a package, from julia-unified/Compiler's sources: a change there is seen without a rebuild
push!(LOAD_PATH, joinpath(ENV["TW_ROOT"], "julia-unified", "Compiler"))
using Compiler
const CC = Compiler
println("closed: ", CC.closed_build(), "  split type: ", CC.operation_split_type(Tuple{typeof(area), Shape}))
interp = CC.NativeInterpreter()
mi = CC.specialize_method(only(methods(Geometry.ratio)), Tuple{typeof(Geometry.ratio), Shape}, Core.svec())
frame = CC.InferenceState(CC.InferenceResult(mi), :no, interp)
CC.typeinf(interp, frame)
for (i, info) in enumerate(frame.stmt_info)
    info isa CC.SplitCallInfo || continue
    st = CC.InliningState(frame, interp)
    sig = CC.Signature(Geometry.area, typeof(Geometry.area), Any[CC.Const(Geometry.area), Shape])
    r = CC.compute_inlining_cases(info, UInt32(0), sig, st)
    println(i, " nsplit ", CC.nsplit(info), " inner ", typeof(info.info), " cases: ", r === nothing ? nothing : (length(r[1]), r[2], r[3], [typeof(c.item) for c in r[1]], [c.sig for c in r[1]]))
    inner = info.info
    inner isa CC.AttributedCallInfo && println("   attributed: mask ", inner.mask, " dyn ", inner.dyn, " dispatch ", inner.dispatch, " cast ", inner.cast, " ", typeof(inner.info))
end
for (f, tt) in ((Geometry.ratio, (Shape,)), (Geometry.area, (Dynamic{Shape},)), (Geometry.label, (Dynamic{Shape},)), (Geometry.report, (Dynamic{Shape},)))
    println(Base.code_typed(f, tt; interp = CC.NativeInterpreter())[1])
end
