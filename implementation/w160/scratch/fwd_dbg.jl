using TraitWorld, InteractiveUtils
module T
using TraitWorld
@trait_module first_seen = false
@trait Model begin
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
@noinline step2(m::Model, u::Float64) = u + 1e-9 * rate(m, u)
end
module U
using TraitWorld
import ..T: Model, rate
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
end
fw = only(m for m in methods(T.step2) if TraitWorld._is_forwarder(m))
println(Base.uncompressed_ast(fw))
mi = Base.specialize_method(fw, Tuple{typeof(T.step2), T.Model, Float64}, Core.svec())

for r in Base.code_typed_by_type(Tuple{typeof(T.step2), T.Model, Float64}); println(r); end
println("--- the forwarder's MI by invoke:")
println(Base.code_typed_by_type(Tuple{typeof(T.step2), T.Model, Float64}; optimize=false))
ci = Base.Compiler.typeinf_ext_toplevel(Base.Compiler.NativeInterpreter(), mi, Base.Compiler.SOURCE_MODE_ABI)
println("rettype ", ci.rettype)
src = Base._uncompressed_ir(ci)
println(src)
