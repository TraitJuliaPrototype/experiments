# W-158 (traits T-161, §7.3 "When"): the bounded check at a call of a name its module never defines, case by case.
# Run with the project of the library: julia --project=. undefined.jl
using TraitWorld
println("TraitWorld ", pathof(TraitWorld))
function thrown(ex)
    try
        Core.eval(Main, ex); return "accepted"
    catch e
        while e isa LoadError; e = e.error; end
        return e isa TraitWorld.TraitUseError ? "refused: " * replace(sprint(showerror, e), "\n" => " ") : "error: " * sprint(showerror, e)
    end
end
module UL
using TraitWorld
@trait_module bounded
@trait UShape begin
    uarea(s::UShape)::Float64
end
end
mod(code; opts = "") = Meta.parse("module U$(rand(UInt32))\nusing TraitWorld\nusing ..UL: UShape\n@trait_module $opts\n$code\nend")
cases = [
    "never defined: the trait's operation not imported" => "f(a::UShape, ts::UShape...) = uarea(a) + sum(uarea, ts)",
    "never defined: a name no module defines" => "f(a::UShape) = nothere(a)",
    "never defined, in a branch" => "using ..UL: uarea\nf(a::UShape) = uarea(a) > 0 ? nothere(a) : 0.0",
    "never defined, through a local" => "f(a::UShape) = (g = nothere; g(a))",
    "declared global, never assigned" => "global nothere\nf(a::UShape) = nothere(a)",
    "defined later in the module, with no method at the box" => "f(a::UShape) = later(a)\nlater(x::Int) = 1.0",
    "defined later in the module, with a method at the box" => "f(a::UShape) = later(a)\nlater(x) = 1.0",
    "defined at the module's end by @eval" => "f(a::UShape) = later(a)\n@eval later(x) = 1.0",
    "defined at the module's end by a macro" => "macro deflater(); esc(:(later(x) = 1.0)); end\nf(a::UShape) = later(a)\n@deflater",
    "defined in __init__ by eval (after the module's end)" => "f(a::UShape) = later(a)\n__init__() = @eval later(x) = 1.0",
    "imported: the operation at the box" => "using ..UL: uarea\nf(a::UShape, ts::UShape...) = uarea(a) + sum(uarea, ts)",
    "imported: an operation's call with no method at the box" => "using ..UL: uarea\nf(a::UShape) = uarea(a, 1)",
    "a const global that is not a function" => "const K = 3\nf(a::UShape) = K(a)",
    "a typed global that is not a function" => "K::Int = 3\nf(a::UShape) = K(a)",
    "an untyped global (its value unknown)" => "K = 3\nf(a::UShape) = K(a)",
    "a name never defined, called with no value at the box" => "using ..UL: uarea\nf(a::UShape) = nothere(1) + uarea(a)",
    "another module's name, written UL.nothere" => "using ..UL\nf(a::UShape) = UL.nothere(a)",
    "through a helper of the module that calls a name never defined" => "h(x) = nothere(x)\nf(a::UShape) = h(a)",
    "through a helper, the name defined later with a method at the box" => "h(x) = later(x)\nf(a::UShape) = h(a)\nlater(x) = 1.0",
    "through a helper not inlined" => "@noinline h(x) = nothere(x)\nf(a::UShape) = h(a)",
]
for (what, code) in cases
    println(rpad(what, 66), " | ", thrown(mod(code)))
end
# a scope that does not declare `bounded`: accepted; `check_definitions` lists the fault
M = Core.eval(Main, mod("f(a::UShape) = nothere(a)"; opts = "bounded = false"))
println(rpad("bounded = false: check_definitions", 66), " | ", TraitWorld.check_definitions(M))
