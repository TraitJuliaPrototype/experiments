# W-158 (traits T-161): the box instance's optimized code at a call of a name its module never defines, and what
# check_at_box reads there. Run from the library's worktree: julia --project=. undef_ir.jl
using TraitWorld
module UI
using TraitWorld
@trait_module
@trait UShape begin
    uarea(s::UShape)::Float64
end
g1(a::UShape) = nothere(a)
g2(a::UShape) = nothere(a) + 1.0
g3(a::UShape) = (x = nothere; x(a))
g4(a::UShape) = uarea(a) > 0 ? nothere(a) : 0.0
end
for f in (UI.g1, UI.g2, UI.g3, UI.g4)
    m = first(methods(f))
    sig = TraitWorld.box_signature(m)
    println("== ", m, "  at ", sig)
    r = Base.code_typed_by_type(sig; interp = Core.Compiler.NativeInterpreter(; facts = true), optimize = true)
    display(r[1][1]); println()
    println("faults: ", TraitWorld.check_at_box(m))
end
