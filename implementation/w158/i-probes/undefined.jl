# W-158, fifth part: what the bounded check (traits §7.3, "When") does with a name a method's body names that its
# module has not defined: at the method's definition, at a later definition of the name, and at the module's end.
# Run with the project of the library (wt/w158b-tw): julia --project=. undefined.jl
using TraitWorld
function thrown(ex)
    try
        Core.eval(Main, ex); return "accepted"
    catch e
        while e isa LoadError; e = e.error; end
        return e isa TraitWorld.TraitUseError ? "refused: " * first(sprint(showerror, e), 160) : "error: " * string(typeof(e))
    end
end
module UL
using TraitWorld
@trait_module bounded
@trait UShape begin
    uarea(s::UShape)::Float64
end
end
mod(code) = Meta.parse("module U$(rand(UInt32))\nusing TraitWorld\nusing ..UL: UShape\n@trait_module\n$code\nend")
cases = [
    "never defined: the trait's operation not imported" => "f(a::UShape, ts::UShape...) = uarea(a) + sum(uarea, ts)",
    "never defined: a name no module defines" => "f(a::UShape) = nothere(a)",
    "defined later in the module, with no method at the box" => "f(a::UShape) = later(a)\nlater(x::Int) = 1.0",
    "defined later in the module, with a method at the box" => "f(a::UShape) = later(a)\nlater(x) = 1.0",
    "imported: the operation at the box" => "using ..UL: uarea\nf(a::UShape, ts::UShape...) = uarea(a) + sum(uarea, ts)",
    "imported: an operation's call with no method at the box" => "using ..UL: uarea\nf(a::UShape) = uarea(a, 1)",
]
for (what, code) in cases
    println(rpad(what, 58), " | ", thrown(mod(code)))
end
