# X1 (found while writing P1b, not one of the plan's probes): a bounded function whose name is one
# Base exports but the module has not used (`peek`). In plain Julia, `peek(x) = …` in a module that
# has not imported or used Base's `peek` defines a new function of that module.
# Reference: traits §5.5 (a package may add a bounded method to a function it owns), §2 (a trait
# module is a module; its functions are its own).
include("common.jl")
header("X1_base_name", "a bounded function named like an unused Base export: `peek(i::X) = …` in a trait module")

toplevel(quote
    module PlainM
    peek(x::Int) = :mine                      # plain Julia: a new function PlainM.peek
    end
end)
println("plain module: PlainM.peek === Base.peek? ", PlainM.peek === Base.peek, "; PlainM.peek(1) = ", PlainM.peek(1))
e = caught(() -> toplevel(quote
    @trait_module module TM
    using TraitWorld
    @trait X begin
        xv(x::X)::Int
    end
    peek(x::X) = xv(x)
    end
end))
println("trait module with `peek(x::X) = xv(x)`: ", errtext(e; lines = 3))
println()
check("plain Julia defines a new function (the baseline)", PlainM.peek !== Base.peek)
check("the trait module defines its own `peek` with a bounded method, as plain Julia would", e === nothing, errtext(e; lines = 3))
finish("X1_base_name";
    predicted = "(not in the plan)",
    reference = "traits §2: a trait module is a module; §5.5: a package adds bounded methods to functions it owns",
    prediction = "n/a")
