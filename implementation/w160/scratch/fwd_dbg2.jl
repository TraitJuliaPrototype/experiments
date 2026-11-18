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
g(@nospecialize(m::T.Model), u::Float64) = TraitWorld._box(Dynamic{T.Model}, m)
fw = only(m for m in methods(T.step2) if TraitWorld._is_forwarder(m))
println("forwarder: nargs=", fw.nargs, " sig=", fw.sig, " nospec=", fw.nospecialize, " slot_syms=", fw.slot_syms)
code_warntype(T.step2, (T.Model, Float64))
code_warntype(g, (T.Model, Float64))
src = Base.uncompressed_ast(fw); println(src.slotnames, " ", src.slotflags, " nargs=", src.nargs, " isva=", src.isva)
